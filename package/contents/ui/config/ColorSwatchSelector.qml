import QtQuick
import QtQuick.Controls

Item {
    id: selector

    property var options: []
    property int currentIndex: 0
    property string toolTipText: ""
    signal activated(int index)
    implicitWidth: 32
    implicitHeight: 28

    SystemPalette {
        id: systemPalette
    }

    HoverHandler {
        id: selectorHoverHandler
    }

    ToolTip.text: selector.toolTipText
    ToolTip.visible: selectorHoverHandler.hovered && selector.toolTipText.length > 0

    Rectangle {
        anchors.centerIn: parent
        width: 16
        height: 16
        radius: 1
        color: selector.options[selector.currentIndex]
               ? selector.options[selector.currentIndex].value : "transparent"
        border.color: systemPalette.mid
        border.width: 1
    }

    MouseArea {
        anchors.fill: parent
        onClicked: palettePopup.open()
        Accessible.name: selector.options[selector.currentIndex]
                         ? selector.options[selector.currentIndex].name : ""
        Accessible.role: Accessible.Button
    }

    Popup {
        id: palettePopup
        y: selector.height
        width: 36
        padding: 4

        contentItem: Column {
            spacing: 2

            Repeater {
                model: selector.options

                delegate: Rectangle {
                    required property int index
                    required property var modelData
                    width: 28
                    height: 24
                    Accessible.name: modelData.name

                    HoverHandler {
                        id: swatchHoverHandler
                    }

                    ToolTip.text: modelData.name
                    ToolTip.visible: swatchHoverHandler.hovered

                    Rectangle {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        radius: 2
                        color: modelData.value
                        border.color: systemPalette.mid
                        border.width: 1
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            selector.activated(index)
                            palettePopup.close()
                        }
                    }
                }
            }
        }
    }
}
