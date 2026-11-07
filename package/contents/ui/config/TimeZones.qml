pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: page

    property alias cfg_showTimeZoneBoundaries: showTimeZoneBoundaries.checked
    property alias cfg_timeZoneLineOpacity: lineOpacity.value
    property alias cfg_timeZoneDayLineColor: dayLineColor.currentIndex
    property alias cfg_timeZoneNightLineColor: nightLineColor.currentIndex
    property alias cfg_showTimeZoneLabels: showLabels.checked
    property alias cfg_timeZoneLabelTop: topLabels.checked
    property alias cfg_timeZoneLabelMiddle: middleLabels.checked
    property alias cfg_timeZoneLabelBottom: bottomLabels.checked
    property alias cfg_timeZoneLabelFormat: labelFormat.currentIndex
    property string cfg_timeZoneFontFamily: Plasmoid.configuration.timeZoneFontFamily
    property alias cfg_timeZoneFontSize: fontSize.currentValue
    property alias cfg_showInternationalDateLine: showDateLine.checked
    property var cfg_showDateTime
    property var cfg_dateFormat
    property var cfg_timeFormat
    property var cfg_timezoneFormat
    property var cfg_roundedMapCornerRadius
    property var cfg_mapOpacity
    property var cfg_showMapShadow
    property var cfg_mapShadowOpacity
    property var cfg_mapShadowDirection
    property var cfg_fontFamily
    property var cfg_fontSize
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
    property var cfg_showDateTimeDefault
    property var cfg_dateFormatDefault
    property var cfg_timeFormatDefault
    property var cfg_timezoneFormatDefault
    property var cfg_roundedMapCornerRadiusDefault
    property var cfg_mapOpacityDefault
    property var cfg_showMapShadowDefault
    property var cfg_mapShadowOpacityDefault
    property var cfg_mapShadowDirectionDefault
    property var cfg_fontFamilyDefault
    property var cfg_fontSizeDefault
    property var cfg_showDeploymentTimestampDefault
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
    readonly property var lineColors: [
        { name: i18n("White"), value: "#ffffff" },
        { name: i18n("Charcoal"), value: "#263238" },
        { name: i18n("Cyan"), value: "#80deea" },
        { name: i18n("Gold"), value: "#ffd54f" },
        { name: i18n("Light gray"), value: "#cfd8dc" },
        { name: i18n("Coral"), value: "#ff8a65" }
    ]

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
            id: showTimeZoneBoundaries
            Kirigami.FormData.label: i18n("Overlay:")
            text: i18n("Show time zone boundaries")
        }

        Slider {
            id: lineOpacity
            Kirigami.FormData.label: i18n("Boundary opacity:")
            from: 0
            to: 100
            stepSize: 5
            snapMode: Slider.SnapAlways
            enabled: showTimeZoneBoundaries.checked
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Day-side color:")
            enabled: showTimeZoneBoundaries.checked

            ColorSwatchSelector {
                id: dayLineColor
                options: page.lineColors
                currentIndex: 1
                toolTipText: i18n("Choose the boundary color on the day side.")
                onActivated: index => page.cfg_timeZoneDayLineColor = index
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Night-side color:")
            enabled: showTimeZoneBoundaries.checked

            ColorSwatchSelector {
                id: nightLineColor
                options: page.lineColors
                currentIndex: 4
                toolTipText: i18n("Choose the boundary color on the night side.")
                onActivated: index => page.cfg_timeZoneNightLineColor = index
            }
        }

        CheckBox {
            id: showLabels
            Kirigami.FormData.label: i18n("Labels:")
            text: i18n("Show UTC offset labels")
            enabled: showTimeZoneBoundaries.checked
        }

        CheckBox {
            id: topLabels
            text: i18n("Top row")
            enabled: showLabels.checked
        }

        CheckBox {
            id: middleLabels
            text: i18n("Middle row")
            enabled: showLabels.checked
        }

        CheckBox {
            id: bottomLabels
            text: i18n("Bottom row")
            enabled: showLabels.checked
        }

        ComboBox {
            id: labelFormat
            Kirigami.FormData.label: i18n("Offset format:")
            model: [
                i18n("Compact (+1)"),
                i18n("Offset with UTC (+1:00 UTC)"),
                i18n("Zero-padded (+01:00)")
            ]
            enabled: showLabels.checked
        }

        ComboBox {
            id: fontFamily
            Kirigami.FormData.label: i18n("Label font:")
            textRole: "label"
            model: page.fontOptions
            currentIndex: {
                for (let index = 0; index < model.length; index++) {
                    if (model[index].family === page.cfg_timeZoneFontFamily) {
                        return index
                    }
                }
                return -1
            }
            displayText: page.cfg_timeZoneFontFamily || page.defaultFontLabel
            enabled: showLabels.checked
            onActivated: index => {
                page.cfg_timeZoneFontFamily = model[index].family
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
                            highlighted: family === page.cfg_timeZoneFontFamily

                            onClicked: {
                                page.cfg_timeZoneFontFamily = family
                                fontFamily.popup.close()
                            }
                        }
                    }
                }
            }
        }

        ComboBox {
            id: fontSize
            Kirigami.FormData.label: i18n("Label size:")
            model: [8, 9, 10, 11, 12, 13, 14, 16, 18]
            enabled: showLabels.checked
        }

        CheckBox {
            id: showDateLine
            Kirigami.FormData.label: i18n("Date line:")
            text: i18n("Emphasize the International Date Line")
            enabled: showTimeZoneBoundaries.checked
        }

        Label {
            Layout.fillWidth: true
            text: i18n("Time zone data by Timezone Boundary Builder; the International Date Line path is from Natural Earth.")
            wrapMode: Text.WordWrap
            opacity: 0.75
        }
    }
}
