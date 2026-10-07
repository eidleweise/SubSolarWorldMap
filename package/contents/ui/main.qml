pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import "../js/solarMath.js" as SolarMath
import "../js/buildInfo.js" as BuildInfo
import "../js/cityCatalog.js" as CityCatalog
import "../js/homeLocation.js" as HomeLocation
import "../js/pinAppearance.js" as PinAppearance
import QtPositioning
import "../lib/SubSolar/CityCatalog"

PlasmoidItem {
    id: root

    property bool homeLocationAvailable: false
    property real detectedHomeLatitude: Plasmoid.configuration.detectedHomeLatitude
    property real detectedHomeLongitude: Plasmoid.configuration.detectedHomeLongitude
    property var cityEntries: cityCatalog.cities
    property var uniqueCityEntries: cityCatalog.uniqueCities

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    CityCatalogManager {
        id: cityCatalog

        onCitiesChanged: root.updateDetectedHomeName()
        Component.onCompleted: start()
    }

    function updateDetectedHomeName() {
        if (!homeLocationAvailable || cityEntries.length === 0) {
            cityCatalog.logEvent("location",
                                 "Nearest-city update deferred; location available: "
                                 + homeLocationAvailable + ", catalog records: "
                                 + cityEntries.length)
            return
        }
        const nearestCity = CityCatalog.nearestCity(
            cityEntries,
            detectedHomeLatitude,
            detectedHomeLongitude)
        Plasmoid.configuration.detectedHomeName =
            qsTr("%1, %2").arg(nearestCity.name).arg(nearestCity.country)
        Plasmoid.configuration.detectedHomeDistanceKm = nearestCity.distanceKm
        cityCatalog.logEvent("location",
                             "Nearest catalog city updated: "
                             + nearestCity.name + ", " + nearestCity.country
                             + " | distance (km): " + Math.round(nearestCity.distanceKm))
    }

    PositionSource {
        id: homePositionSource
        active: true
        updateInterval: 60000

        Component.onCompleted: {
            cityCatalog.logEvent("location", "Requesting a fresh GeoClue position at startup")
            Plasmoid.configuration.detectedHomeAvailable = false
            update()
        }

        onPositionChanged: {
            if (!position.coordinate.isValid) {
                cityCatalog.logEvent("location/error",
                                     "GeoClue delivered an invalid coordinate; waiting for a valid position.")
                return
            }
            root.detectedHomeLatitude = position.coordinate.latitude
            root.detectedHomeLongitude = position.coordinate.longitude
            root.homeLocationAvailable = true
            Plasmoid.configuration.detectedHomeAvailable = true
            Plasmoid.configuration.detectedHomeLatitude = position.coordinate.latitude
            Plasmoid.configuration.detectedHomeLongitude = position.coordinate.longitude
            Plasmoid.configuration.detectedHomeCoordinatesKnown = true
            cityCatalog.logEvent("location",
                                 "GeoClue position update received; accuracy (m): "
                                 + position.horizontalAccuracy)
            root.updateDetectedHomeName()
        }

        onSourceErrorChanged: {
            if (sourceError !== PositionSource.NoError) {
                root.homeLocationAvailable = false
                Plasmoid.configuration.detectedHomeAvailable = false
                cityCatalog.logEvent("location/error",
                                     "GeoClue error during location check: " + sourceError)
            }
        }
    }

    fullRepresentation: Item {
        id: fullView

        implicitWidth: 520
        implicitHeight: 260
        Layout.minimumWidth: 320
        Layout.minimumHeight: 160
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        property var currentDateTime: new Date()
        property var displayDateTime: currentDateTime
        property var solarPosition: SolarMath.subsolarPoint(currentDateTime)
        readonly property var homeLocation: {
            if (Plasmoid.configuration.showHomePin === false) {
                return null
            }
            const coordinates = HomeLocation.coordinatesForHomePin(
                root.homeLocationAvailable,
                {
                    latitude: root.detectedHomeLatitude,
                    longitude: root.detectedHomeLongitude
                },
                Plasmoid.configuration.useManualHome,
                {
                    latitude: Plasmoid.configuration.manualHomeLatitude,
                    longitude: Plasmoid.configuration.manualHomeLongitude
                })
            if (!coordinates) {
                return null
            }
            const nearestCity = root.cityEntries.length > 0
                                ? CityCatalog.nearestCity(
                                      root.cityEntries,
                                      coordinates.latitude,
                                      coordinates.longitude)
                                : null
            return {
                latitude: coordinates.latitude,
                longitude: coordinates.longitude,
                name: nearestCity
                      ? nearestCity.name + ", " + nearestCity.country
                      : qsTr("Home"),
                colorIndex: Plasmoid.configuration.homePinColor,
                opacity: Plasmoid.configuration.homePinOpacity
            }
        }
        readonly property var selectedCityLocations: root.uniqueCityEntries.filter(city =>
            (Plasmoid.configuration.selectedCities || []).includes(city.cityId))
            .map(city => {
                const appearance = PinAppearance.forCity(
                    Plasmoid.configuration.cityPinAppearance,
                    city.cityId)
                return Object.assign({}, city, {
                    pinColorIndex: appearance.color,
                    pinOpacity: appearance.opacity
                })
            })
        readonly property int selectedCityPinStyle: Plasmoid.configuration.cityPinStyle

        // Single source of truth for the clock string, shared by the date/time
        // badge and the pin tooltips. Uses Qt formatting (the QML JS engine has
        // no ECMAScript `Intl`), so it always renders SYSTEM-LOCAL time. Passed
        // into MapView as `systemLocalClock` and consumed by clockFormat.js.
        function formatSystemLocalClock(dateTime, dateFormat, timeFormat, timezoneFormat) {
            let dateText
            switch (dateFormat) {
            case 0:
                dateText = dateTime.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
                break
            case 2:
                dateText = Qt.formatDate(dateTime, "yyyy-MM-dd")
                break
            default:
                dateText = dateTime.toLocaleDateString(Qt.locale(), Locale.LongFormat)
            }

            const timeFormats = ["HH:mm", "h:mm AP", "HH:mm:ss", "h:mm:ss AP"]
            const timePattern = timeFormats[timeFormat] || timeFormats[0]
            let clockText = dateText + "  ·  " + Qt.formatTime(dateTime, timePattern)
            switch (timezoneFormat) {
            case 1:
                clockText += " " + Qt.formatDateTime(dateTime, "t")
                break
            case 2:
                clockText += " " + Qt.formatDateTime(dateTime, "tttt")
                break
            }
            return clockText
        }

        // City-pin clock formatter. Delegates the IANA timezone conversion to
        // C++ (CityCatalogManager::formatZonedClock) because the Plasma/Qt 6 QML
        // JS engine has no ECMAScript `Intl`. Returns the city's OWN local
        // wall-clock string, or an empty string for an empty/invalid zone so the
        // caller falls back to the system-local path. `dateTime` is accepted for
        // signature symmetry with the fallback path; the C++ side reads the
        // current instant itself so the tooltip stays live.
        function formatCityClock(dateTime, ianaTimeZone, dateFormat, timeFormat, timezoneFormat) {
            return cityCatalog.formatZonedClock(ianaTimeZone, dateFormat, timeFormat,
                                                timezoneFormat, Qt.locale().name)
        }

        function updateSolarPosition() {
            const now = new Date()
            solarPosition = SolarMath.subsolarPoint(now)
            currentDateTime = now
            displayDateTime = now
        }

        function updateClock() {
            displayDateTime = new Date()
        }

        MapView {
            id: mapViewContent

            anchors.centerIn: parent
            width: Math.min(fullView.width, fullView.height * 2)
            height: width / 2
            solarPosition: fullView.solarPosition
            homeLocation: fullView.homeLocation
            selectedCities: fullView.selectedCityLocations
            cityPinStyle: fullView.selectedCityPinStyle
            dateFormat: Plasmoid.configuration.dateFormat
            timeFormat: Plasmoid.configuration.timeFormat
            timezoneFormat: Plasmoid.configuration.timezoneFormat
            localeName: Qt.locale().name
            // Qt-based system-local clock formatter shared with the badge; the
            // QML JS engine has no `Intl`, so clockFormat.js uses this for
            // system-local time.
            systemLocalClock: fullView.formatSystemLocalClock
            // Per-city zoned clock formatter (C++ QTimeZone path). City pins use
            // this for their OWN local time; empty result falls back to
            // system-local inside MapView.
            cityClock: fullView.formatCityClock
        }

        Rectangle {
            id: dateTimeBadge
            anchors.top: mapViewContent.top
            anchors.horizontalCenter: mapViewContent.horizontalCenter
            anchors.topMargin: 8
            width: dateTimeLabel.implicitWidth + 20
            height: 30
            radius: height / 2
            visible: Plasmoid.configuration.showDateTime !== false
            color: "#cc20252a"
            border.color: "#55ffffff"
            z: 3

            Text {
                id: dateTimeLabel
                anchors.centerIn: parent
                color: "white"
                font.family: Plasmoid.configuration.fontFamily || Qt.application.font.family
                font.pixelSize: Plasmoid.configuration.fontSize
                text: fullView.formatSystemLocalClock(
                          fullView.displayDateTime,
                          Plasmoid.configuration.dateFormat,
                          Plasmoid.configuration.timeFormat,
                          Plasmoid.configuration.timezoneFormat)
            }
        }

        Text {
            anchors.right: mapViewContent.right
            anchors.bottom: mapViewContent.bottom
            anchors.rightMargin: 8
            anchors.bottomMargin: 8
            visible: Plasmoid.configuration.showDeploymentTimestamp !== false
            color: "#ff3030"
            style: Text.Outline
            styleColor: "#cc000000"
            font.pixelSize: 12
            text: qsTr("Deployed: %1").arg(BuildInfo.deployTimestamp)
            z: 3
        }

        Timer {
            interval: 30000
            repeat: true
            running: true
            onTriggered: fullView.updateSolarPosition()
        }

        Timer {
            interval: 1000
            repeat: true
            running: Plasmoid.configuration.showDateTime !== false
                     && (Plasmoid.configuration.timeFormat === 2
                         || Plasmoid.configuration.timeFormat === 3)
            onTriggered: fullView.updateClock()
        }

    }
}
