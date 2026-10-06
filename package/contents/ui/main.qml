pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import "../js/solarMath.js" as SolarMath
import "../js/buildInfo.js" as BuildInfo
import "../js/cityCatalog.js" as CityCatalog
import "../js/pinAppearance.js" as PinAppearance
import QtPositioning
import "../lib/SubSolar/CityCatalog"

PlasmoidItem {
    id: root

    property bool homeLocationAvailable: false
    property real detectedHomeLatitude: Plasmoid.configuration.detectedHomeLatitude
    property real detectedHomeLongitude: Plasmoid.configuration.detectedHomeLongitude
    property var cityEntries: cityCatalog.cities

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
            if (root.homeLocationAvailable) {
                const nearestCity = root.cityEntries.length > 0
                                    ? CityCatalog.nearestCity(
                                          root.cityEntries,
                                          root.detectedHomeLatitude,
                                          root.detectedHomeLongitude)
                                    : null
                return {
                    latitude: root.detectedHomeLatitude,
                    longitude: root.detectedHomeLongitude,
                    name: nearestCity
                          ? nearestCity.name + ", " + nearestCity.country
                          : qsTr("Home"),
                    colorIndex: Plasmoid.configuration.homePinColor,
                    opacity: Plasmoid.configuration.homePinOpacity
                }
            }
            if (Plasmoid.configuration.useManualHome) {
                const latitude = Plasmoid.configuration.manualHomeLatitude
                const longitude = Plasmoid.configuration.manualHomeLongitude
                const nearestCity = root.cityEntries.length > 0
                                    ? CityCatalog.nearestCity(root.cityEntries, latitude, longitude)
                                    : null
                return {
                    latitude: latitude,
                    longitude: longitude,
                    name: nearestCity
                          ? nearestCity.name + ", " + nearestCity.country
                          : qsTr("Home"),
                    colorIndex: Plasmoid.configuration.homePinColor,
                    opacity: Plasmoid.configuration.homePinOpacity
                }
            }
            return null
        }
        readonly property var selectedCityLocations: root.cityEntries.filter(city =>
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

            HoverHandler {
                id: dateTimeHoverHandler
            }

            Controls.ToolTip.text: qsTr("Current local date and time. Change its display in Date & Time settings.")
            Controls.ToolTip.visible: dateTimeHoverHandler.hovered

            Text {
                id: dateTimeLabel
                anchors.centerIn: parent
                color: "white"
                font.family: Plasmoid.configuration.fontFamily || Qt.application.font.family
                font.pixelSize: Plasmoid.configuration.fontSize
                text: {
                    let dateText
                    switch (Plasmoid.configuration.dateFormat) {
                    case 0:
                        dateText = fullView.displayDateTime.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
                        break
                    case 2:
                        dateText = Qt.formatDate(fullView.displayDateTime, "yyyy-MM-dd")
                        break
                    default:
                        dateText = fullView.displayDateTime.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                    }

                    const timeFormats = ["HH:mm", "h:mm AP", "HH:mm:ss", "h:mm:ss AP"]
                    const timeFormat = timeFormats[Plasmoid.configuration.timeFormat] || timeFormats[0]
                    let clockText = dateText + "  ·  "
                            + Qt.formatTime(fullView.displayDateTime, timeFormat)
                    switch (Plasmoid.configuration.timezoneFormat) {
                    case 1:
                        clockText += " " + Qt.formatDateTime(fullView.displayDateTime, "t")
                        break
                    case 2:
                        clockText += " " + Qt.formatDateTime(fullView.displayDateTime, "tttt")
                        break
                    }
                    return clockText
                }
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
