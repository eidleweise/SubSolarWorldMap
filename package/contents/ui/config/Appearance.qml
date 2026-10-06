pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: page

    // Plasma supplies every KConfig value and default to each category page.
    property alias cfg_showDateTime: showDateTime.checked
    property alias cfg_dateFormat: dateFormat.currentIndex
    property alias cfg_timeFormat: timeFormat.currentIndex
    property alias cfg_timezoneFormat: timezoneFormat.currentIndex
    property string cfg_fontFamily: Plasmoid.configuration.fontFamily
    property alias cfg_fontSize: fontSize.currentValue
    property var cfg_showDeploymentTimestamp
    property var cfg_selectedCities
    property var cfg_useManualHome
    property var cfg_showHomePin
    property var cfg_homePinColor
    property var cfg_homePinOpacity
    property var cfg_cityPinAppearance
    property var cfg_cityPinStyle
    property var cfg_manualHomeLatitude
    property var cfg_manualHomeLongitude
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
    readonly property string defaultFontLabel: i18n("System default")
    readonly property var fontOptions: {
        const options = [{ label: defaultFontLabel, family: "" }]
        const families = Qt.fontFamilies()
        for (let index = 0; index < families.length; index++) {
            options.push({ label: families[index], family: families[index] })
        }
        return options
    }

    function filteredFonts(queryText) {
        const query = queryText.trim().toLocaleLowerCase()
        if (!query) {
            return fontOptions
        }
        return fontOptions.filter(option =>
            option.label.toLocaleLowerCase().includes(query))
    }

    Kirigami.FormLayout {
        CheckBox {
            id: showDateTime
            Kirigami.FormData.label: i18n("Map clock:")
            text: i18n("Show date and time on the map")
            ToolTip.text: i18n("Display or hide the date and time overlay on the map.")
            ToolTip.visible: hovered
        }

        ComboBox {
            id: dateFormat
            Kirigami.FormData.label: i18n("Date format:")
            ToolTip.text: i18n("Choose how the date is shown in the map clock.")
            ToolTip.visible: hovered
            model: [
                i18n("Short date"),
                i18n("Long date"),
                i18n("ISO date (YYYY-MM-DD)")
            ]
        }

        ComboBox {
            id: timeFormat
            Kirigami.FormData.label: i18n("Time format:")
            ToolTip.text: i18n("Choose a 12-hour or 24-hour clock, with or without seconds.")
            ToolTip.visible: hovered
            model: [
                i18n("24-hour (14:05)"),
                i18n("12-hour (2:05 PM)"),
                i18n("24-hour with seconds (14:05:09)"),
                i18n("12-hour with seconds (2:05:09 PM)")
            ]
        }

        ComboBox {
            id: timezoneFormat
            Kirigami.FormData.label: i18n("Timezone:")
            ToolTip.text: i18n("Choose whether the map clock shows the timezone.")
            ToolTip.visible: hovered
            model: [
                i18n("Hidden"),
                i18n("Abbreviation (BST)"),
                i18n("Full name (British Summer Time)")
            ]
        }

        ComboBox {
            id: fontFamily
            Kirigami.FormData.label: i18n("Font family:")
            ToolTip.text: i18n("Choose the font used by the map clock.")
            ToolTip.visible: hovered
            textRole: "label"
            model: page.fontOptions
            currentIndex: {
                for (let index = 0; index < model.length; index++) {
                    if (model[index].family === page.cfg_fontFamily) {
                        return index
                    }
                }
                return -1
            }
            displayText: page.cfg_fontFamily || page.defaultFontLabel
            onActivated: index => {
                page.cfg_fontFamily = model[index].family
            }

            popup: Popup {
                y: fontFamily.height
                width: fontFamily.width
                height: Math.min(360, fontOptionsView.contentHeight + fontSearch.height + 16)
                padding: 6

                onOpened: {
                    fontSearch.clear()
                    fontSearch.forceActiveFocus()
                }

                contentItem: ColumnLayout {
                    spacing: 6

                    TextField {
                        id: fontSearch
                        Layout.fillWidth: true
                        placeholderText: i18n("Type to filter fonts")
                        ToolTip.text: i18n("Filter the available font families.")
                        ToolTip.visible: hovered
                    }

                    ListView {
                        id: fontOptionsView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: page.filteredFonts(fontSearch.text)
                        currentIndex: -1

                        delegate: ItemDelegate {
                            required property string label
                            required property string family
                            width: fontOptionsView.width
                            text: label
                            highlighted: family === page.cfg_fontFamily
                            ToolTip.text: family || page.defaultFontLabel
                            ToolTip.visible: hovered

                            onClicked: {
                                page.cfg_fontFamily = family
                                fontFamily.popup.close()
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Preview:")
            Layout.fillWidth: true

            Label {
                Layout.fillWidth: true
                text: "Aa Bb Cc 0123"
                font.family: page.cfg_fontFamily
                font.pixelSize: fontSize.currentValue
                elide: Text.ElideRight
            }
        }

        ComboBox {
            id: fontSize
            Kirigami.FormData.label: i18n("Font size:")
            ToolTip.text: i18n("Set the map clock text size.")
            ToolTip.visible: hovered
            model: [10, 11, 12, 13, 14, 16, 18, 20, 24]
        }
    }
}
