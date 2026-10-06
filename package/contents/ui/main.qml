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

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: qsTr("About SubSolar World Map")
            icon.name: "help-about"
            onTriggered: aboutDialog.open()
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
        property var solarPosition: SolarMath.subsolarPoint(currentDateTime)

        function updateSolarPosition() {
            const now = new Date()
            solarPosition = SolarMath.subsolarPoint(now)
            currentDateTime = now
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
                font.pixelSize: 13
                text: fullView.currentDateTime.toLocaleDateString()
                      + "  ·  "
                      + fullView.currentDateTime.toLocaleTimeString()
            }
        }

        Timer {
            interval: 30000
            repeat: true
            running: true
            onTriggered: fullView.updateSolarPosition()
        }
    }

    Controls.Dialog {
        id: aboutDialog

        title: qsTr("About SubSolar World Map")
        modal: true
        standardButtons: Controls.Dialog.Close
        anchors.centerIn: Controls.Overlay.overlay
        width: 400

        contentItem: ColumnLayout {
            spacing: 12

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
