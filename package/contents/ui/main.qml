pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import "../js/solarMath.js" as SolarMath
import "../js/buildInfo.js" as BuildInfo

PlasmoidItem {
    id: root

    property bool aboutVisible: false

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: qsTr("About SubSolar World Map")
            icon.name: "help-about"
            onTriggered: root.aboutVisible = true
        }
    ]

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
        }

        Rectangle {
            id: dateTimeBadge
            anchors.top: mapViewContent.top
            anchors.horizontalCenter: mapViewContent.horizontalCenter
            anchors.topMargin: 8
            width: dateTimeLabel.implicitWidth + 20
            height: 30
            radius: height / 2
            color: "#cc20252a"
            border.color: "#55ffffff"
            z: 3

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
            running: Plasmoid.configuration.timeFormat === 2
                     || Plasmoid.configuration.timeFormat === 3
            onTriggered: fullView.updateClock()
        }

        Rectangle {
            id: aboutOverlay
            anchors.fill: parent
            color: "#99000000"
            visible: root.aboutVisible
            z: 10

            MouseArea {
                anchors.fill: parent
                onClicked: mouse => mouse.accepted = true
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(400, parent.width - 24)
                height: Math.min(parent.height - 24, aboutContent.implicitHeight + 32)
                radius: 8
                color: "#f020252a"
                border.color: "#99ffffff"

                ColumnLayout {
                    id: aboutContent
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        Controls.Label {
                            Layout.fillWidth: true
                            text: qsTr("About SubSolar World Map")
                            font.bold: true
                            font.pixelSize: 16
                        }

                        Controls.Button {
                            text: qsTr("Close")
                            onClicked: root.aboutVisible = false
                        }
                    }

                    Controls.Label {
                        Layout.fillWidth: true
                        text: qsTr("A real-time world map showing daylight and nighttime based on the current position of the Sun.")
                        wrapMode: Text.WordWrap
                    }

                    Controls.Label {
                        Layout.fillWidth: true
                        text: qsTr("Version 0.1.0 · Licensed under GPL-3.0-only")
                              + "\n"
                              + qsTr("Build date: %1").arg(BuildInfo.buildTimestamp)
                        wrapMode: Text.WordWrap
                    }

                    Controls.Label {
                        Layout.fillWidth: true
                        text: "<a href=\"https://github.com/eidleweise/SubSolarWorldMap\">"
                              + qsTr("Project website")
                              + "</a>"
                        textFormat: Text.RichText
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }

                    Controls.Label {
                        Layout.fillWidth: true
                        text: qsTr("Map imagery adapted from ")
                              + "<a href=\"https://science.nasa.gov/earth/earth-observatory/blue-marble-next-generation/base-topography-bathymetry/\">"
                              + qsTr("NASA Blue Marble: Next Generation")
                              + "</a>"
                              + qsTr(" and ")
                              + "<a href=\"https://www.earthdata.nasa.gov/data/projects/black-marble\">"
                              + qsTr("NASA Black Marble (VIIRS)")
                              + "</a>."
                        textFormat: Text.RichText
                        wrapMode: Text.WordWrap
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }
                }
            }
        }
    }
}
