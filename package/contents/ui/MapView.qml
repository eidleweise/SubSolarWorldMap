pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Window
import "../js/mapProjection.js" as MapProjection
import "../js/clockFormat.js" as ClockFormat
import "../js/timezoneOverlayData.js" as TimeZoneOverlayData

Item {
    id: mapView

    property var solarPosition
    property var lunarPosition
    property var lunarPhase
    property bool showMoon: true
    property var homeLocation
    property var selectedCities: []
    property int cityPinStyle: 0
    // Clock format config threaded in from main.qml (MapView is a plain Item and
    // does not have the Plasmoid attached object available).
    property int dateFormat: 0
    property int timeFormat: 0
    property int timezoneFormat: 0
    property string localeName: Qt.locale().name
    // Qt-based system-local clock formatter injected from main.qml. The QML JS
    // engine has no ECMAScript `Intl`, so clockFormat.js relies on this
    // callback to render the system-local clock line (identical to the badge).
    property var systemLocalClock: null
    // Per-city zoned clock formatter injected from main.qml. Delegates the IANA
    // timezone conversion to C++ (CityCatalogManager::formatZonedClock) since
    // the QML JS engine has no `Intl`. Returns the city's own local wall-clock
    // string, or an empty string for an empty/invalid zone (falls back to the
    // system-local path below).
    property var cityClock: null
    property var utcOffsetFormatter: null
    property bool showTimeZoneBoundaries: true
    property int timeZoneLineOpacity: 60
    property int timeZoneDayLineColor: 1
    property int timeZoneNightLineColor: 4
    property bool showTimeZoneLabels: true
    property bool timeZoneLabelTop: false
    property bool timeZoneLabelMiddle: true
    property bool timeZoneLabelBottom: false
    property int timeZoneLabelFormat: 1
    property string timeZoneFontFamily: ""
    property int timeZoneFontSize: 11
    property bool showInternationalDateLine: true

    function lunarPhaseName(name) {
        switch (name) {
        case "New Moon": return qsTr("New Moon")
        case "Waxing Crescent": return qsTr("Waxing Crescent")
        case "First Quarter": return qsTr("First Quarter")
        case "Waxing Gibbous": return qsTr("Waxing Gibbous")
        case "Full Moon": return qsTr("Full Moon")
        case "Waning Gibbous": return qsTr("Waning Gibbous")
        case "Last Quarter": return qsTr("Last Quarter")
        case "Waning Crescent": return qsTr("Waning Crescent")
        default: return name
        }
    }
    readonly property var pinPalette: [
        "#ff7043", "#4fc3f7", "#e53935", "#43a047", "#8e24aa", "#ffffff"
    ]
    readonly property var timeZoneLinePalette: [
        "#ffffff", "#263238", "#80deea", "#ffd54f", "#cfd8dc", "#ff8a65"
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

    Canvas {
        id: timeZoneOverlay
        anchors.fill: parent
        z: 1.5
        visible: mapView.showTimeZoneBoundaries
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Cooperative

        function coordinate(longitude, latitude) {
            return {
                x: width * (longitude + 180) / 360,
                y: height * (90 - latitude) / 180
            }
        }

        function daylight(latitude, longitude) {
            if (!mapView.solarPosition) {
                return 0.5
            }
            const radians = Math.PI / 180
            const lat = latitude * radians
            const solarLat = mapView.solarPosition.latitude * radians
            const longitudeDifference =
                (longitude - mapView.solarPosition.longitude) * radians
            const altitudeCosine = Math.sin(lat) * Math.sin(solarLat)
                    + Math.cos(lat) * Math.cos(solarLat)
                    * Math.cos(longitudeDifference)
            const edge = 0.035
            const value = Math.max(0, Math.min(1, (altitudeCosine + edge) / (2 * edge)))
            return value * value * (3 - 2 * value)
        }

        function addSegment(buckets, longitude1, latitude1, longitude2, latitude2) {
            const longitudeDelta = longitude2 - longitude1
            const latitudeDelta = latitude2 - latitude1
            const steps = Math.max(1, Math.ceil(
                Math.max(Math.abs(longitudeDelta), Math.abs(latitudeDelta)) * 2))
            for (let index = 0; index < steps; index++) {
                const start = index / steps
                const end = (index + 1) / steps
                const middle = (start + end) / 2
                const middleLongitude = longitude1 + longitudeDelta * middle
                const middleLatitude = latitude1 + latitudeDelta * middle
                const bucket = Math.max(0, Math.min(15,
                    Math.floor(daylight(middleLatitude, middleLongitude) * 16)))
                const first = coordinate(longitude1 + longitudeDelta * start,
                                         latitude1 + latitudeDelta * start)
                const second = coordinate(longitude1 + longitudeDelta * end,
                                          latitude1 + latitudeDelta * end)
                buckets[bucket].push(first.x, first.y, second.x, second.y)
            }
        }

        function addWrappedSegment(buckets, longitude1, latitude1, longitude2, latitude2) {
            if (Math.abs(longitude2 - longitude1) <= 180) {
                addSegment(buckets, longitude1, latitude1, longitude2, latitude2)
                return
            }
            const adjustedLongitude2 = longitude2 + (longitude2 > longitude1 ? -360 : 360)
            const seamLongitude = longitude1 >= 0 ? 180 : -180
            const denominator = adjustedLongitude2 - longitude1
            if (Math.abs(denominator) < 0.000001) {
                return
            }
            const fraction = (seamLongitude - longitude1) / denominator
            if (fraction < 0 || fraction > 1) {
                return
            }
            const seamLatitude = latitude1 + (latitude2 - latitude1) * fraction
            addSegment(buckets, longitude1, latitude1, seamLongitude, seamLatitude)
            addSegment(buckets, -seamLongitude, seamLatitude, longitude2, latitude2)
        }

        function rgba(color, alpha) {
            return "rgba(" + Math.round(color.r * 255) + ","
                    + Math.round(color.g * 255) + ","
                    + Math.round(color.b * 255) + "," + alpha + ")"
        }

        function mixedColor(nightColor, dayColor, mix) {
            return Qt.rgba(nightColor.r + (dayColor.r - nightColor.r) * mix,
                           nightColor.g + (dayColor.g - nightColor.g) * mix,
                           nightColor.b + (dayColor.b - nightColor.b) * mix,
                           1)
        }

        function paintBoundaries(context) {
            const paths = TimeZoneOverlayData.overlayData.boundaries
            const buckets = Array.from({ length: 16 }, () => [])
            for (const path of paths) {
                for (let index = 1; index < path.length; index++) {
                    const first = path[index - 1]
                    const second = path[index]
                    addWrappedSegment(buckets, first[0], first[1], second[0], second[1])
                }
            }

            const dayColor = Qt.color(mapView.timeZoneLinePalette[
                                          mapView.timeZoneDayLineColor] || "#263238")
            const nightColor = Qt.color(mapView.timeZoneLinePalette[
                                            mapView.timeZoneNightLineColor] || "#cfd8dc")
            context.lineWidth = 0.8
            context.lineCap = "round"
            context.lineJoin = "round"
            context.globalAlpha = Math.max(0, Math.min(100, mapView.timeZoneLineOpacity)) / 100
            for (let bucket = 0; bucket < buckets.length; bucket++) {
                const segments = buckets[bucket]
                if (segments.length === 0) {
                    continue
                }
                context.beginPath()
                for (let index = 0; index < segments.length; index += 4) {
                    context.moveTo(segments[index], segments[index + 1])
                    context.lineTo(segments[index + 2], segments[index + 3])
                }
                context.strokeStyle = rgba(mixedColor(nightColor, dayColor, bucket / 15), 1)
                context.stroke()
            }
            context.globalAlpha = 1
        }

        function paintDateLine(context) {
            if (!mapView.showInternationalDateLine) {
                return
            }
            const paths = TimeZoneOverlayData.overlayData.dateLine
            const buckets = Array.from({ length: 16 }, () => [])
            for (const path of paths) {
                for (let index = 1; index < path.length; index++) {
                    const first = path[index - 1]
                    const second = path[index]
                    addWrappedSegment(buckets, first[0], first[1], second[0], second[1])
                }
            }
            const segments = []
            for (const bucket of buckets) {
                for (const segment of bucket) {
                    segments.push(segment)
                }
            }
            context.lineCap = "round"
            context.lineJoin = "round"
            context.globalAlpha = Math.max(0, Math.min(100, mapView.timeZoneLineOpacity)) / 100
            context.beginPath()
            for (let index = 0; index < segments.length; index += 4) {
                context.moveTo(segments[index], segments[index + 1])
                context.lineTo(segments[index + 2], segments[index + 3])
            }
            context.strokeStyle = "#15191d"
            context.lineWidth = 3.2
            context.stroke()
            context.strokeStyle = "#ffe082"
            context.lineWidth = 1.8
            context.stroke()

            context.font = "bold " + mapView.timeZoneFontSize + "px "
                    + (mapView.timeZoneFontFamily || "sans-serif")
            context.textAlign = "right"
            context.textBaseline = "bottom"
            context.lineWidth = 2.5
            context.strokeStyle = "#15191d"
            context.fillStyle = "#ffe082"
            const labelY = height * (90 + 2.509434) / 180
            context.strokeText(qsTr("International Date Line"), width - 7, labelY)
            context.fillText(qsTr("International Date Line"), width - 7, labelY)
            context.globalAlpha = 1
        }

        function paintLabels(context) {
            if (!mapView.showTimeZoneLabels
                    || typeof mapView.utcOffsetFormatter !== "function") {
                return
            }
            const data = TimeZoneOverlayData.overlayData.labels
            const rows = []
            if (mapView.timeZoneLabelTop) {
                rows.push({ name: "top", y: height * (90 - 75) / 180 })
            }
            if (mapView.timeZoneLabelMiddle) {
                rows.push({ name: "middle", y: height / 2 })
            }
            if (mapView.timeZoneLabelBottom) {
                rows.push({ name: "bottom", y: height * (90 + 75) / 180 })
            }

            context.font = mapView.timeZoneFontSize + "px "
                    + (mapView.timeZoneFontFamily || "sans-serif")
            context.textAlign = "center"
            context.textBaseline = "middle"
            context.lineWidth = 2.5
            context.strokeStyle = "rgba(0, 0, 0, 0.75)"
            context.fillStyle = "#fffdf4"
            for (const row of rows) {
                const anchors = data[row.name].slice().sort(
                    (first, second) => first.longitude - second.longitude)
                let lastRight = -Infinity
                for (const anchor of anchors) {
                    const text = mapView.utcOffsetFormatter(
                        anchor.tzid, mapView.timeZoneLabelFormat)
                    if (!text) {
                        continue
                    }
                    const point = coordinate(anchor.longitude, anchor.latitude)
                    const textWidth = context.measureText(text).width + 10
                    const left = point.x - textWidth / 2
                    const right = point.x + textWidth / 2
                    if (left < 4 || right > width - 4 || left < lastRight + 6) {
                        continue
                    }
                    context.strokeText(text, point.x, row.y)
                    context.fillText(text, point.x, row.y)
                    lastRight = right
                }
            }
        }

        onPaint: {
            const context = getContext("2d")
            context.clearRect(0, 0, width, height)
            if (!visible || width <= 0 || height <= 0) {
                return
            }
            paintBoundaries(context)
            paintDateLine(context)
            paintLabels(context)
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: requestPaint()

        Connections {
            target: mapView

            function onSolarPositionChanged() { timeZoneOverlay.requestPaint() }
            function onUtcOffsetFormatterChanged() { timeZoneOverlay.requestPaint() }
            function onTimeZoneLineOpacityChanged() { timeZoneOverlay.requestPaint() }
            function onTimeZoneDayLineColorChanged() { timeZoneOverlay.requestPaint() }
            function onTimeZoneNightLineColorChanged() { timeZoneOverlay.requestPaint() }
            function onShowTimeZoneLabelsChanged() { timeZoneOverlay.requestPaint() }
            function onTimeZoneLabelTopChanged() { timeZoneOverlay.requestPaint() }
            function onTimeZoneLabelMiddleChanged() { timeZoneOverlay.requestPaint() }
            function onTimeZoneLabelBottomChanged() { timeZoneOverlay.requestPaint() }
            function onTimeZoneLabelFormatChanged() { timeZoneOverlay.requestPaint() }
            function onTimeZoneFontFamilyChanged() { timeZoneOverlay.requestPaint() }
            function onTimeZoneFontSizeChanged() { timeZoneOverlay.requestPaint() }
            function onShowInternationalDateLineChanged() { timeZoneOverlay.requestPaint() }
        }
    }

    Item {
        id: moonMarker
        readonly property var point: mapView.lunarPosition
                                      ? MapProjection.equirectangularPoint(
                                            mapView.lunarPosition.latitude,
                                            mapView.lunarPosition.longitude,
                                            mapView.width,
                                            mapView.height)
                                      : null
        x: point ? point.x - width / 2 : 0
        y: point ? point.y - height / 2 : 0
        width: 30
        height: 30
        z: 2
        visible: mapView.showMoon && !!point && !!mapView.lunarPhase
        Accessible.name: qsTr("Sublunar point, %1").arg(
                             mapView.lunarPhase
                             ? mapView.lunarPhaseName(mapView.lunarPhase.name) : "")

        HoverHandler {
            id: moonHoverHandler
        }

        Controls.ToolTip.text: qsTr("Moon overhead\n%1 · %2% illuminated").arg(
                                   mapView.lunarPhase
                                   ? mapView.lunarPhaseName(mapView.lunarPhase.name) : "")
                                   .arg(mapView.lunarPhase
                                        ? Math.round(mapView.lunarPhase.illumination * 100) : 0)
        Controls.ToolTip.visible: moonHoverHandler.hovered

        Canvas {
            id: moonIcon
            anchors.centerIn: parent
            width: 22
            height: 22

            onPaint: {
                if (!mapView.lunarPhase) {
                    return
                }
                const context = getContext("2d")
                const radius = width / 2 - 1
                const centerX = width / 2
                const centerY = height / 2
                const phase = mapView.lunarPhase
                const angle = phase.angle * Math.PI / 180
                const terminator = Math.cos(angle) * radius
                const side = phase.waxing ? 1 : -1

                context.clearRect(0, 0, width, height)
                context.beginPath()
                context.arc(centerX, centerY, radius, 0, 2 * Math.PI)
                context.fillStyle = "#263238"
                context.fill()
                context.save()
                context.beginPath()
                context.arc(centerX, centerY, radius, 0, 2 * Math.PI)
                context.clip()
                context.beginPath()
                context.moveTo(centerX, centerY - radius)
                context.arc(centerX, centerY, radius,
                            -Math.PI / 2,
                            phase.waxing ? Math.PI / 2 : -3 * Math.PI / 2,
                            !phase.waxing)
                context.bezierCurveTo(centerX + side * terminator,
                                      centerY + radius * 0.55,
                                      centerX + side * terminator,
                                      centerY - radius * 0.55,
                                      centerX, centerY - radius)
                context.closePath()
                context.fillStyle = "#fff1b8"
                context.fill()
                context.restore()
                context.beginPath()
                context.arc(centerX, centerY, radius, 0, 2 * Math.PI)
                context.strokeStyle = "#fff8d6"
                context.lineWidth = 1
                context.stroke()
            }

            Connections {
                target: mapView

                function onLunarPhaseChanged() { moonIcon.requestPaint() }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 4
            height: 4
            radius: width / 2
            color: "#fff8d6"
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
                                          "",
                                          mapView.systemLocalClock)
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

                // City pins carry an IANA timezone from the catalog. Prefer the
                // C++ zoned-clock path (the city's OWN local time); if it is
                // unavailable or the zone is empty/invalid it returns an empty
                // string and we fall back to system-local via clockFormat.js.
                readonly property string cityZonedClock: {
                    if (typeof mapView.cityClock === "function") {
                        var zoned = mapView.cityClock(new Date(),
                                                      modelData.timezone,
                                                      mapView.dateFormat,
                                                      mapView.timeFormat,
                                                      mapView.timezoneFormat)
                        if (zoned) {
                            return zoned
                        }
                    }
                    return ClockFormat.formatLocationClock(
                               new Date(),
                               mapView.dateFormat,
                               mapView.timeFormat,
                               mapView.timezoneFormat,
                               mapView.localeName,
                               modelData.timezone,
                               mapView.systemLocalClock)
                }
                Controls.ToolTip.text: qsTr("Selected city: %1").arg(modelData.name)
                                        + "\n"
                                        + cityZonedClock
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
