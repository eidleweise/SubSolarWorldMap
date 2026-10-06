pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: page

    property alias cfg_dateFormat: dateFormat.currentIndex
    property alias cfg_timeFormat: timeFormat.currentIndex
    property alias cfg_timezoneFormat: timezoneFormat.currentIndex
    property string cfg_fontFamily: Plasmoid.configuration.fontFamily
    property alias cfg_fontSize: fontSize.currentValue
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
        ComboBox {
            id: dateFormat
            Kirigami.FormData.label: i18n("Date format:")
            model: [
                i18n("Short date"),
                i18n("Long date"),
                i18n("ISO date (YYYY-MM-DD)")
            ]
        }

        ComboBox {
            id: timeFormat
            Kirigami.FormData.label: i18n("Time format:")
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
            model: [
                i18n("Hidden"),
                i18n("Abbreviation (BST)"),
                i18n("Full name (British Summer Time)")
            ]
        }

        ComboBox {
            id: fontFamily
            Kirigami.FormData.label: i18n("Font family:")
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
            model: [10, 11, 12, 13, 14, 16, 18, 20, 24]
        }
    }
}
