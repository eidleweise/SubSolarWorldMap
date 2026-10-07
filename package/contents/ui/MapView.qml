pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Window
import "../js/mapProjection.js" as MapProjection
import "../js/clockFormat.js" as ClockFormat

Item {
    id: mapView

    property var solarPosition
    property var homeLocation
    property var selectedCities: []
    property int cityPinStyle: 0
    // Clock format config threaded in from main.qml (MapView is a plain Item and
    // does not have the Plasmoid attached object available).
    property int dateFormat: 0
    property int timeFormat: 0
    property int timezoneFormat: 0
    property string localeName: Qt.locale().name
    readonly property var pinPalette: [
        "#ff7043", "#4fc3f7", "#e53935", "#43a047", "#8e24aa", "#ffffff"
    ]
    readonly property var solarPoint: solarPosition
                                       ? MapProjection.equirectangularPoint(
                                             solarPosition.latitude,
                                             solarPosition.longitude,
                                             width,
                                             height)
                                       : null
    readonly property string textureResolution: width * Screen.devicePixelRatio > 2160
                                                ? "3840x1920" : "2160x1080"

    function pinColor(colorIndex, opacityPercent) {
        const selected = pinPalette[colorIndex] || pinPalette[0]
        const rgb = Qt.color(selected)
        return Qt.rgba(rgb.r, rgb.g, rgb.b, rgb.a * Math.max(0, Math.min(100, opacityPercent)) / 100)
    }

    Image {
        id: dayMap
        anchors.fill: parent
        source: Qt.resolvedUrl("../assets/day/world.equirectangular-"
                               + mapView.textureResolution + ".png")
        fillMode: Image.Stretch
        smooth: true
        asynchronous: true

        onStatusChanged: {
            if (status === Image.Error) {
                console.error("Unable to load daytime map:", source, sourceSize)
            }
        }
    }

    ShaderEffectSource {
        id: dayTextureSource
        anchors.fill: parent
        sourceItem: dayMap
        hideSource: true
        live: true
    }

    Image {
        id: nightMap
        anchors.fill: parent
        source: Qt.resolvedUrl("../assets/night/BlackMarble.equirectangular-"
                               + mapView.textureResolution + ".png")
        fillMode: Image.Stretch
        smooth: true
        asynchronous: true
        z: -1

        onStatusChanged: {
            if (status === Image.Error) {
                console.error("Unable to load nighttime map:", source, sourceSize)
            }
        }
    }

    ShaderEffectSource {
        id: nightTextureSource
        anchors.fill: parent
        sourceItem: nightMap
        hideSource: true
        live: true
    }

    ShaderEffect {
        id: mapShader

        anchors.fill: parent
        z: 1
        property var dayTexture: dayTextureSource
        property var nightTexture: nightTextureSource
        property real subsolarLatitude: mapView.solarPosition
                                       ? mapView.solarPosition.latitude : 0
        property real subsolarLongitude: mapView.solarPosition
                                        ? mapView.solarPosition.longitude : 0

        fragmentShader: Qt.resolvedUrl("../shaders/dayNight.frag.qsb")

        onStatusChanged: {
            if (status === ShaderEffect.Error)
                console.error("Unable to load day/night map shader:", log)
        }
    }

    Item {
        id: sunMarker
        x: mapView.solarPoint ? mapView.solarPoint.x - width / 2 : 0
        y: mapView.solarPoint ? mapView.solarPoint.y - height / 2 : 0
        width: 32
        height: 32
        z: 2
        visible: !!mapView.solarPosition
        Accessible.name: qsTr("Subsolar point")

        HoverHandler {
            id: sunHoverHandler
        }

        Controls.ToolTip.text: qsTr("The Sun is directly overhead at this point.")
        Controls.ToolTip.visible: sunHoverHandler.hovered

        Rectangle {
            anchors.centerIn: parent
            width: 26
            height: 26
            radius: width / 2
            color: "#99000000"
            border.color: "#ccfff8d6"
        }

        Repeater {
            model: 8

            delegate: Rectangle {
                id: sunRay
                required property int index

                width: 4
                height: 9
                x: (sunMarker.width - sunRay.width) / 2
                y: 0
                radius: 2
                color: "#ffd54f"
                border.color: "#704f00"
                border.width: 1

                transform: Rotation {
                    origin.x: 2
                    origin.y: sunMarker.height / 2
                    angle: sunRay.index * 45
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 13
            height: 13
            radius: width / 2
            color: "#ffca28"
            border.color: "#fff8d6"
            border.width: 1
        }
    }

    Repeater {
        model: mapView.homeLocation ? [mapView.homeLocation] : []

        delegate: Item {
            required property var modelData
            readonly property var point: MapProjection.equirectangularPoint(
                                             modelData.latitude,
                                             modelData.longitude,
                                             mapView.width,
                                             mapView.height)
            readonly property real pinX: point.x
            readonly property real pinY: point.y
            x: pinX - 15
            y: pinY - 36
            width: homeLabel.implicitWidth + 42
            height: 36
            z: 3
            Accessible.name: qsTr("Home: %1").arg(modelData.name)

            HoverHandler {
                id: homePinHoverHandler
            }

            // Home pin has no IANA timezone (derived from GeoClue/manual
            // coordinates), so the clock line falls back to system-local time.
            Controls.ToolTip.text: qsTr("Home location: %1").arg(modelData.name)
                                    + "\n"
                                    + ClockFormat.formatLocationClock(
                                          new Date(),
                                          mapView.dateFormat,
                                          mapView.timeFormat,
                                          mapView.timezoneFormat,
                                          mapView.localeName,
                                          "")
            Controls.ToolTip.visible: homePinHoverHandler.hovered

            Rectangle {
                x: 0
                anchors.top: parent.top
                width: 30
                height: 30
                radius: width / 2
                color: mapView.pinColor(modelData.colorIndex, modelData.opacity)
                border.color: mapView.pinColor(5, modelData.opacity)
                border.width: 2

                Text {
                    anchors.centerIn: parent
                    text: "⌂"
                    color: mapView.pinColor(5, modelData.opacity)
                    font.pixelSize: 21
                    font.bold: true
                }
            }

            Rectangle {
                x: 10
                anchors.top: parent.top
                anchors.topMargin: 24
                width: 10
                height: 10
                color: mapView.pinColor(modelData.colorIndex, modelData.opacity)
                rotation: 45
                z: -1
            }

            Text {
                id: homeLabel
                x: 38
                y: (parent.height - implicitHeight) / 2
                text: modelData.name
                color: "white"
                style: Text.Outline
                styleColor: "#cc000000"
                font.pixelSize: 12
            }
        }
    }

    Repeater {
        model: mapView.selectedCities

        delegate: Item {
            required property var modelData
            readonly property var point: MapProjection.equirectangularPoint(
                                             modelData.latitude,
                                             modelData.longitude,
                                             mapView.width,
                                             mapView.height)
            x: point.x
            y: point.y
            width: cityLabel.implicitWidth + 18
            height: 0
            z: 3
            Accessible.name: modelData.name

            // The delegate Item has height 0 and draws its marker/label at
            // negative offsets, so a delegate-level HoverHandler would never
            // register a hover. Attach the hover + tooltip to a dedicated
            // hit-area that actually covers the drawn pin dot and label,
            // without moving the visible marker or label.
            Rectangle {
                id: cityPinHitArea
                x: -6
                y: -cityLabel.implicitHeight / 2
                width: 16 + cityLabel.implicitWidth
                height: Math.max(12, cityLabel.implicitHeight)
                color: "transparent"

                HoverHandler {
                    id: cityPinHoverHandler
                }

                // City pins carry an IANA timezone from the catalog; an empty
                // value falls back gracefully to system-local time inside the
                // helper.
                Controls.ToolTip.text: qsTr("Selected city: %1").arg(modelData.name)
                                        + "\n"
                                        + ClockFormat.formatLocationClock(
                                              new Date(),
                                              mapView.dateFormat,
                                              mapView.timeFormat,
                                              mapView.timezoneFormat,
                                              mapView.localeName,
                                              modelData.timezone)
                Controls.ToolTip.visible: cityPinHoverHandler.hovered
            }

            Rectangle {
                x: -6
                y: -6
                width: 12
                height: 12
                radius: mapView.cityPinStyle === 0 ? width / 2 : 0
                rotation: mapView.cityPinStyle === 1 ? 45 : 0
                color: mapView.pinColor(modelData.pinColorIndex, modelData.pinOpacity)
                border.color: mapView.pinColor(5, modelData.pinOpacity)
                border.width: 1
            }

            Text {
                id: cityLabel
                x: 10
                y: -implicitHeight / 2
                text: modelData.name
                color: "white"
                style: Text.Outline
                styleColor: "#cc000000"
                font.pixelSize: 12
            }
        }
    }
}
