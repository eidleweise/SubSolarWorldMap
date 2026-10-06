pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window

Item {
    id: mapView

    property var solarPosition
    readonly property string textureResolution: width * Screen.devicePixelRatio > 2160
                                                ? "3840x1920" : "2160x1080"

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
        x: mapView.solarPosition
           ? mapView.width * (mapView.solarPosition.longitude + 180) / 360 - width / 2 : 0
        y: mapView.solarPosition
           ? mapView.height * (90 - mapView.solarPosition.latitude) / 180 - height / 2 : 0
        width: 32
        height: 32
        z: 2
        visible: !!mapView.solarPosition
        Accessible.name: qsTr("Subsolar point")

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
}
