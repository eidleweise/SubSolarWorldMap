pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    property alias cfg_showMoon: showMoon.checked
    property alias cfg_roundedMapCornerRadius: mapCornerRadius.value
    property alias cfg_mapOpacity: mapOpacity.value
    property alias cfg_showMapShadow: showMapShadow.checked
    property alias cfg_mapShadowOpacity: mapShadowOpacity.value
    property alias cfg_mapShadowDirection: mapShadowDirection.value
    property var cfg_showDateTime
    property var cfg_dateFormat
    property var cfg_timeFormat
    property var cfg_timezoneFormat
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
    property var cfg_showTimeZoneBoundaries
    property var cfg_timeZoneLineOpacity
    property var cfg_timeZoneDayLineColor
    property var cfg_timeZoneNightLineColor
    property var cfg_showTimeZoneLabels
    property var cfg_timeZoneLabelTop
    property var cfg_timeZoneLabelMiddle
    property var cfg_timeZoneLabelBottom
    property var cfg_timeZoneLabelFormat
    property var cfg_timeZoneFontFamily
    property var cfg_timeZoneFontSize
    property var cfg_showInternationalDateLine
    property var cfg_manualHomeLatitude
    property var cfg_manualHomeLongitude
    property var cfg_detectedHomeName
    property var cfg_detectedHomeDistanceKm
    property var cfg_detectedHomeAvailable
    property var cfg_detectedHomeLatitude
    property var cfg_detectedHomeLongitude
    property var cfg_detectedHomeCoordinatesKnown
    property var cfg_showDateTimeDefault
    property var cfg_showMoonDefault
    property var cfg_roundedMapCornerRadiusDefault
    property var cfg_mapOpacityDefault
    property var cfg_showMapShadowDefault
    property var cfg_mapShadowOpacityDefault
    property var cfg_mapShadowDirectionDefault
    property var cfg_dateFormatDefault
    property var cfg_timeFormatDefault
    property var cfg_timezoneFormatDefault
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
    property var cfg_showTimeZoneBoundariesDefault
    property var cfg_timeZoneLineOpacityDefault
    property var cfg_timeZoneDayLineColorDefault
    property var cfg_timeZoneNightLineColorDefault
    property var cfg_showTimeZoneLabelsDefault
    property var cfg_timeZoneLabelTopDefault
    property var cfg_timeZoneLabelMiddleDefault
    property var cfg_timeZoneLabelBottomDefault
    property var cfg_timeZoneLabelFormatDefault
    property var cfg_timeZoneFontFamilyDefault
    property var cfg_timeZoneFontSizeDefault
    property var cfg_showInternationalDateLineDefault
    property var cfg_manualHomeLatitudeDefault
    property var cfg_manualHomeLongitudeDefault
    property var cfg_detectedHomeNameDefault
    property var cfg_detectedHomeDistanceKmDefault
    property var cfg_detectedHomeAvailableDefault
    property var cfg_detectedHomeLatitudeDefault
    property var cfg_detectedHomeLongitudeDefault
    property var cfg_detectedHomeCoordinatesKnownDefault

    Kirigami.FormLayout {
        CheckBox {
            id: showMoon
            Kirigami.FormData.label: i18n("Map:")
            text: i18n("Show the Moon's location and phase")
            ToolTip.text: i18n("Mark where the Moon is directly overhead. Hover for its current phase and illumination.")
            ToolTip.visible: hovered
        }

        Slider {
            id: mapCornerRadius
            Kirigami.FormData.label: i18n("Corner rounding:")
            Layout.fillWidth: true
            Layout.minimumWidth: 300
            from: 0
            to: 100
            stepSize: 1
            ToolTip.text: i18n("Adjust the map corners from square to very rounded.")
            ToolTip.visible: hovered
        }

        Slider {
            id: mapOpacity
            Kirigami.FormData.label: i18n("Map opacity:")
            Layout.fillWidth: true
            Layout.minimumWidth: 300
            from: 0
            to: 100
            stepSize: 1
            ToolTip.text: i18n("Adjust how much of the desktop shows through the map.")
            ToolTip.visible: hovered
        }

        CheckBox {
            id: showMapShadow
            Kirigami.FormData.label: i18n("Map shadow:")
            text: i18n("Show a drop shadow")
            ToolTip.text: i18n("Add a soft shadow behind the map.")
            ToolTip.visible: hovered
        }

        Slider {
            id: mapShadowOpacity
            Kirigami.FormData.label: i18n("Shadow opacity:")
            Layout.fillWidth: true
            Layout.minimumWidth: 300
            from: 0
            to: 100
            stepSize: 1
            enabled: showMapShadow.checked
            ToolTip.text: i18n("Set the shadow transparency.")
            ToolTip.visible: hovered
        }

        Slider {
            id: mapShadowDirection
            Kirigami.FormData.label: i18n("Shadow direction:")
            Layout.fillWidth: true
            Layout.minimumWidth: 300
            from: 0
            to: 100
            stepSize: 1
            enabled: showMapShadow.checked
            ToolTip.text: i18n("Move the shadow from the left, around the bottom, to the right.")
            ToolTip.visible: hovered
        }
    }
}
