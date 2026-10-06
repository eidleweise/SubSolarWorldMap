pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "../../lib/SubSolar/CityCatalog"

import "../../js/cityCatalog.js" as CityCatalog
import "../../js/pinAppearance.js" as PinAppearance

KCM.SimpleKCM {
    id: page

    // Plasma supplies every KConfig value and default to each category page.
    property var cfg_selectedCities: Plasmoid.configuration.selectedCities || []
    property alias cfg_useManualHome: useManualHome.checked
    property alias cfg_showHomePin: showHomePin.checked
    property alias cfg_manualHomeLatitude: homeLatitude.value
    property alias cfg_manualHomeLongitude: homeLongitude.value
    property alias cfg_homePinColor: homePinColor.currentIndex
    property alias cfg_homePinOpacity: homePinOpacity.value
    property alias cfg_cityPinStyle: cityPinStyle.currentIndex
    property string cfg_cityPinAppearance: Plasmoid.configuration.cityPinAppearance || "{}"
    property var cfg_showDeploymentTimestamp
    property var cfg_showDateTime
    property var cfg_dateFormat
    property var cfg_timeFormat
    property var cfg_timezoneFormat
    property var cfg_fontFamily
    property var cfg_fontSize
    property var cfg_detectedHomeName
    property var cfg_detectedHomeDistanceKm
    property var cfg_detectedHomeAvailable
    property var cfg_detectedHomeLatitude
    property var cfg_detectedHomeLongitude
    property var cfg_detectedHomeCoordinatesKnown
    property var cfg_showDeploymentTimestampDefault
    property var cfg_showDateTimeDefault
    property var cfg_dateFormatDefault
    property var cfg_timeFormatDefault
    property var cfg_timezoneFormatDefault
    property var cfg_fontFamilyDefault
    property var cfg_fontSizeDefault
    property var cfg_selectedCitiesDefault
    property var cfg_useManualHomeDefault
    property var cfg_showHomePinDefault
    property var cfg_homePinColorDefault
    property var cfg_homePinOpacityDefault
    property var cfg_cityPinAppearanceDefault
    property var cfg_cityPinStyleDefault
    property var cfg_manualHomeLatitudeDefault
    property var cfg_manualHomeLongitudeDefault
    property var cfg_detectedHomeNameDefault
    property var cfg_detectedHomeDistanceKmDefault
    property var cfg_detectedHomeAvailableDefault
    property var cfg_detectedHomeLatitudeDefault
    property var cfg_detectedHomeLongitudeDefault
    property var cfg_detectedHomeCoordinatesKnownDefault
    readonly property var pinColorOptions: [
        { name: i18n("Orange"), value: "#ff7043" },
        { name: i18n("Blue"), value: "#4fc3f7" },
        { name: i18n("Red"), value: "#e53935" },
        { name: i18n("Green"), value: "#43a047" },
        { name: i18n("Purple"), value: "#8e24aa" },
        { name: i18n("White"), value: "#ffffff" }
    ]
    property int cityAppearanceRevision: 0
    property string searchText: ""
    property string appliedSearchText: ""
    property bool homeExpanded: true
    property bool selectedExpanded: true
    property bool addExpanded: false
    property var cities: cityCatalog.cities
    property string catalogStatus: cityCatalog.status
    onSearchTextChanged: searchDebounce.restart()

    function cityIsSelected(id) {
        return cfg_selectedCities.indexOf(id) >= 0
    }

    function setCitySelected(id, selected) {
        const selectedCities = cfg_selectedCities.slice()
        const index = selectedCities.indexOf(id)
        if (selected && index < 0) {
            selectedCities.push(id)
        } else if (!selected && index >= 0) {
            selectedCities.splice(index, 1)
        }
        cfg_selectedCities = selectedCities
    }

    function removeCity(id) {
        setCitySelected(id, false)
    }

    function selectedCityEntries() {
        return cities.filter(city => cityIsSelected(city.cityId))
                .sort((left, right) => left.name.localeCompare(right.name))
    }

    function cityAppearance(id) {
        try {
            const appearance = JSON.parse(cfg_cityPinAppearance)
            const cityAppearance = appearance[id] || {}
            return {
                color: Number.isInteger(cityAppearance.color) ? cityAppearance.color : 1,
                opacity: Number.isInteger(cityAppearance.opacity) ? cityAppearance.opacity : 100
            }
        } catch (error) {
            cityCatalog.logEvent("settings/error", "Invalid per-city pin settings: " + error.message)
            return { color: 1, opacity: 100 }
        }
    }

    function setCityAppearance(id, key, value) {
        let appearances
        try {
            appearances = JSON.parse(cfg_cityPinAppearance)
        } catch (error) {
            cityCatalog.logEvent("settings/error", "Resetting invalid per-city pin settings: " + error.message)
            appearances = {}
        }
        const appearance = appearances[id] || { color: 1, opacity: 100 }
        appearance[key] = value
        appearances[id] = appearance
        cfg_cityPinAppearance = JSON.stringify(appearances)
        cityAppearanceRevision++
        cityCatalog.logEvent("pin opacity",
                             "Saved city " + id + " " + key + "=" + value
                             + "; config length=" + cfg_cityPinAppearance.length)
    }

    function setAllSelectedCityOpacities(opacity) {
        cityCatalog.logEvent("pin opacity",
                             "Bulk update requested: opacity=" + opacity
                             + ", selected count=" + cfg_selectedCities.length
                             + ", selected ids=" + cfg_selectedCities.join(","))
        try {
            cfg_cityPinAppearance = PinAppearance.withOpacityForCities(
                        cfg_cityPinAppearance,
                        cfg_selectedCities,
                        opacity)
            cityAppearanceRevision++
            const resultingValues = []
            for (let index = 0; index < cfg_selectedCities.length; index++) {
                const id = cfg_selectedCities[index]
                resultingValues.push(id + "=" + cityAppearance(id).opacity)
            }
            cityCatalog.logEvent("settings",
                                 "Bulk update stored; revision=" + cityAppearanceRevision
                                 + ", config length=" + cfg_cityPinAppearance.length
                                 + ", resulting values=" + resultingValues.join(","))
        } catch (error) {
            cityCatalog.logEvent("pin opacity/error",
                                 "Bulk opacity update failed: " + error.message)
            throw error
        }
    }

    function filteredCities() {
        const query = appliedSearchText.trim().toLocaleLowerCase()
        return cities.filter(city =>
            !query || (city.name + " " + city.country).toLocaleLowerCase().includes(query))
    }

    function homeCoordinates() {
        if (Plasmoid.configuration.detectedHomeAvailable
            && Plasmoid.configuration.detectedHomeCoordinatesKnown) {
            return {
                latitude: Plasmoid.configuration.detectedHomeLatitude,
                longitude: Plasmoid.configuration.detectedHomeLongitude
            }
        }
        if (useManualHome.checked) {
            return {
                latitude: homeLatitude.value,
                longitude: homeLongitude.value
            }
        }
        return null
    }

    function formatHomeCoordinates() {
        const coordinates = homeCoordinates()
        if (!coordinates) {
            return i18n("Waiting for a location from GeoClue…")
        }
        return "%1, %2".arg(coordinates.latitude.toFixed(4))
                .arg(coordinates.longitude.toFixed(4))
    }

    function currentNearestCity() {
        const coordinates = homeCoordinates()
        if (!coordinates) {
            return i18n("Unavailable")
        }
        if (cities.length === 0) {
            return catalogStatus || i18n("Waiting for city catalog…")
        }
        try {
            const nearest = CityCatalog.nearestCity(
                cities,
                coordinates.latitude,
                coordinates.longitude)
            cityCatalog.logEvent("location",
                                 "Nearest city calculated from current coordinates: "
                                 + nearest.name + ", " + nearest.country
                                 + " | distance (km): " + Math.round(nearest.distanceKm))
            return nearest.name
        } catch (error) {
            cityCatalog.logEvent("location/error",
                                 "Nearest-city calculation failed: " + error.message
                                 + " | coordinate values finite: "
                                 + Number.isFinite(coordinates.latitude) + ", "
                                 + Number.isFinite(coordinates.longitude)
                                 + " | catalog records: " + cities.length)
            return i18n("Unable to determine nearest city; see diagnostic log.")
        }
    }

    CityCatalogManager {
        id: cityCatalog

        Component.onCompleted: start()
    }

    ColumnLayout {
        id: sections
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing * 1.5

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            ToolButton {
                Layout.fillWidth: true
                display: AbstractButton.TextOnly
                ToolTip.text: i18n("Show or hide Home location and pin settings.")
                ToolTip.visible: hovered
                contentItem: Label {
                    text: (page.homeExpanded ? "▾  " : "▸  ") + i18n("Home")
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                }
                Accessible.name: i18n("Home location settings")
                onClicked: page.homeExpanded = !page.homeExpanded
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: page.homeExpanded
                spacing: Kirigami.Units.smallSpacing

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: i18n("The Home pin uses your system location through GeoClue. The nearest listed city is an approximation; your coordinates are not sent to a geocoding service.")
                }

                Label {
                    Layout.fillWidth: true
                    text: i18n("Current coordinates: %1").arg(page.formatHomeCoordinates())
                }

                Label {
                    Layout.fillWidth: true
                    text: i18n("Current nearest city: %1").arg(page.currentNearestCity())
                }

                CheckBox {
                    id: useManualHome
                    visible: !Plasmoid.configuration.detectedHomeAvailable
                    text: i18n("Use manual fallback coordinates")
                    ToolTip.text: i18n("Use the coordinates below when a system location is unavailable.")
                    ToolTip.visible: hovered
                }

                GridLayout {
                    columns: 3
                    columnSpacing: Kirigami.Units.smallSpacing
                    rowSpacing: Kirigami.Units.smallSpacing

                    Label {
                        Layout.preferredWidth: 205
                        text: i18n("Home pin")
                    }

                    Label {
                        Layout.preferredWidth: 32
                        text: i18n("Color")
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Label {
                        Layout.preferredWidth: 120
                        text: i18n("Opacity")
                        horizontalAlignment: Text.AlignHCenter
                    }

                    CheckBox {
                        id: showHomePin
                        Layout.preferredWidth: 205
                        text: i18n("Show Home pin on the map")
                        Layout.columnSpan: 1
                        ToolTip.text: i18n("Show or hide your Home location marker on the map.")
                        ToolTip.visible: hovered
                    }

                    ColorSwatchSelector {
                        id: homePinColor
                        Layout.preferredWidth: 32
                        Layout.minimumWidth: 32
                        Layout.maximumWidth: 32
                        enabled: showHomePin.checked
                        options: page.pinColorOptions
                        currentIndex: Plasmoid.configuration.homePinColor
                        toolTipText: i18n("Choose the Home pin color.")
                        onActivated: index => page.cfg_homePinColor = index
                    }

                    Slider {
                        id: homePinOpacity
                        Layout.preferredWidth: 120
                        enabled: showHomePin.checked
                        from: 10
                        to: 100
                        stepSize: 5
                        value: Plasmoid.configuration.homePinOpacity
                        Accessible.name: i18n("Home pin opacity")
                        ToolTip.text: i18n("Set how transparent the Home pin appears.")
                        ToolTip.visible: hovered
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: useManualHome.checked

                    ColumnLayout {
                        Layout.fillWidth: true

                        Label {
                            text: i18n("Fallback latitude")
                        }

                        DoubleSpinBox {
                            id: homeLatitude
                            Layout.fillWidth: true
                            from: -90
                            to: 90
                            decimals: 4
                            stepSize: 0.1
                            ToolTip.text: i18n("Set the fallback Home latitude, from 90° south to 90° north.")
                            ToolTip.visible: hovered
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true

                        Label {
                            text: i18n("Fallback longitude")
                        }

                        DoubleSpinBox {
                            id: homeLongitude
                            Layout.fillWidth: true
                            from: -180
                            to: 180
                            decimals: 4
                            stepSize: 0.1
                            ToolTip.text: i18n("Set the fallback Home longitude, from 180° west to 180° east.")
                            ToolTip.visible: hovered
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            ToolButton {
                Layout.fillWidth: true
                display: AbstractButton.TextOnly
                ToolTip.text: i18n("Show or hide the selected cities and their pin settings.")
                ToolTip.visible: hovered
                contentItem: Label {
                    text: (page.selectedExpanded ? "▾  " : "▸  ")
                          + i18n("Selected Cities (%1)").arg(page.cfg_selectedCities.length)
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                }
                Accessible.name: i18n("Selected Cities (%1)").arg(page.cfg_selectedCities.length)
                onClicked: page.selectedExpanded = !page.selectedExpanded
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: page.selectedExpanded
                spacing: Kirigami.Units.smallSpacing

                Label {
                    Layout.fillWidth: true
                    text: i18n("Shift-click any city opacity slider to set every selected city to that position.")
                    wrapMode: Text.WordWrap
                    opacity: 0.75
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Label {
                        Layout.preferredWidth: 205
                        text: i18n("City")
                    }

                    Label {
                        Layout.preferredWidth: 32
                        text: i18n("Color")
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Label {
                        Layout.preferredWidth: 120
                        text: i18n("Opacity")
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Item {
                        Layout.preferredWidth: 32
                    }
                }

                Repeater {
                    model: page.selectedCityEntries()

                    delegate: RowLayout {
                        required property string cityId
                        required property string name
                        required property string country
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Label {
                            Layout.preferredWidth: 205
                            text: name + " — " + country
                            elide: Text.ElideRight
                        }

                        ColorSwatchSelector {
                            id: selectedCityColor
                            Layout.preferredWidth: 32
                            Layout.minimumWidth: 32
                            Layout.maximumWidth: 32
                            options: page.pinColorOptions
                            currentIndex: page.cityAppearance(cityId).color
                            toolTipText: i18n("Choose the pin color for %1.").arg(name)
                            onActivated: index => page.setCityAppearance(cityId, "color", index)
                            Accessible.name: i18n("Pin color for %1").arg(name)
                        }

                        Item {
                            Layout.preferredWidth: 120
                            implicitHeight: selectedCityOpacity.implicitHeight

                            Slider {
                                id: selectedCityOpacity
                                anchors.fill: parent
                                from: 10
                                to: 100
                                stepSize: 5
                                value: {
                                    page.cityAppearanceRevision
                                    return page.cityAppearance(cityId).opacity
                                }
                                onMoved: {
                                    const shiftHeld = shiftOpacityHandler.pressed
                                    cityCatalog.logEvent("pin opacity",
                                                         "Slider moved: city=" + cityId
                                                         + ", value=" + Math.round(value)
                                                         + ", shift handler pressed=" + shiftHeld)
                                    if (shiftHeld) {
                                        page.setAllSelectedCityOpacities(Math.round(value))
                                    } else {
                                        page.setCityAppearance(
                                                    cityId, "opacity", Math.round(value))
                                    }
                                }
                                ToolTip.text: i18n("Shift-click to apply this opacity to all selected cities")
                                ToolTip.visible: hovered
                                Accessible.name: i18n("Pin opacity for %1").arg(name)

                                TapHandler {
                                    id: shiftOpacityHandler
                                    acceptedButtons: Qt.LeftButton
                                    acceptedModifiers: Qt.ShiftModifier
                                    onPressedChanged: {
                                        if (pressed) {
                                            cityCatalog.logEvent("pin opacity",
                                                                 "Shift pointer handler pressed for "
                                                                 + cityId)
                                        }
                                    }
                                    onTapped: (eventPoint, button) => {
                                        cityCatalog.logEvent("pin opacity",
                                                             "Shift-click detected for " + cityId
                                                             + "; slider value="
                                                             + Math.round(selectedCityOpacity.value))
                                        page.setAllSelectedCityOpacities(
                                                    Math.round(selectedCityOpacity.value))
                                    }
                                }
                            }
                        }

                        ToolButton {
                            Layout.preferredWidth: 32
                            Layout.minimumWidth: 32
                            Layout.maximumWidth: 32
                            text: "×"
                            Accessible.role: Accessible.Button
                            Accessible.name: i18n("Remove %1").arg(name)
                            ToolTip.text: i18n("Remove %1 from the selected cities.").arg(name)
                            ToolTip.visible: hovered
                            onClicked: page.removeCity(cityId)
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: page.cfg_selectedCities.length === 0
                    text: i18n("No cities selected.")
                }

                RowLayout {
                    Layout.alignment: Qt.AlignLeft
                    spacing: Kirigami.Units.smallSpacing

                    Label {
                        text: i18n("City pin shape:")
                    }

                    ComboBox {
                        id: cityPinStyle
                        Layout.preferredWidth: 180
                        Layout.maximumWidth: 180
                        model: [
                            i18n("Circle"),
                            i18n("Diamond"),
                            i18n("Square")
                        ]
                        Accessible.name: i18n("City pin shape")
                        ToolTip.text: i18n("Choose the marker shape used for all selected city pins.")
                        ToolTip.visible: hovered
                    }
                }

            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            ToolButton {
                Layout.fillWidth: true
                display: AbstractButton.TextOnly
                ToolTip.text: i18n("Show or hide the searchable city catalog.")
                ToolTip.visible: hovered
                contentItem: Label {
                    text: (page.addExpanded ? "▾  " : "▸  ") + i18n("Add Cities")
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                }
                Accessible.name: i18n("Add Cities")
                onClicked: page.addExpanded = !page.addExpanded
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: page.addExpanded
                spacing: Kirigami.Units.smallSpacing

                TextField {
                    Layout.fillWidth: true
                    placeholderText: i18n("Search by city or country")
                    text: page.searchText
                    ToolTip.text: i18n("Find cities by entering a city or country name.")
                    ToolTip.visible: hovered
                    onTextChanged: page.searchText = text
                }

                Label {
                    Layout.fillWidth: true
                    text: page.catalogStatus
                    wrapMode: Text.WordWrap
                }

                Label {
                    Layout.fillWidth: true
                    text: i18n("Diagnostic log: %1").arg(cityCatalog.logFilePath)
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                }

                ListView {
                    id: cityList
                    Layout.fillWidth: true
                    implicitHeight: 320
                    clip: true
                    model: page.filteredCities()

                    delegate: CheckDelegate {
                        required property string cityId
                        required property string name
                        required property string country
                        width: cityList.width
                        text: name + " — " + country
                        checked: page.cityIsSelected(cityId)
                        ToolTip.text: checked
                                        ? i18n("Remove %1 from the selected cities.").arg(name)
                                        : i18n("Add %1 to the selected cities.").arg(name)
                        ToolTip.visible: hovered
                        onToggled: page.setCitySelected(cityId, checked)
                    }
                }
            }
        }

        Timer {
            id: searchDebounce
            interval: 150
            repeat: false
            onTriggered: page.appliedSearchText = page.searchText
        }
    }

    Component.onCompleted: searchDebounce.restart()
}
