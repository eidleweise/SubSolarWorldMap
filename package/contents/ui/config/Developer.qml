import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "../../lib/SubSolar/CityCatalog"

KCM.SimpleKCM {
    id: page

    // Plasma supplies every KConfig value and default to each category page.
    property alias cfg_showDeploymentTimestamp: showDeploymentTimestamp.checked
    property var cfg_showDateTime
    property var cfg_dateFormat
    property var cfg_timeFormat
    property var cfg_timezoneFormat
    property var cfg_fontFamily
    property var cfg_fontSize
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
    property string launchError: ""

    function openLocation(path) {
        if (!Qt.openUrlExternally("file://" + encodeURI(path))) {
            launchError = i18n("Could not open this location. Check that a file manager or text editor is available.")
            return
        }
        launchError = ""
    }

    CityCatalogManager {
        id: cityCatalog
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Label {
            Layout.fillWidth: true
            text: i18n("Developer options")
            font.bold: true
            font.pixelSize: 20
        }

        CheckBox {
            id: showDeploymentTimestamp
            text: i18n("Show deployment timestamp on the map")
            ToolTip.text: i18n("Display or hide the red timestamp that helps confirm when this widget was last deployed.")
            ToolTip.visible: hovered
        }

        Label {
            Layout.fillWidth: true
            text: i18n("Detailed diagnostics are written to a rotating log file. The current log and one previous log are kept; rotation starts at about 1 MiB.")
            wrapMode: Text.WordWrap
        }

        Label {
            Layout.fillWidth: true
            text: cityCatalog.logFilePath
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            Accessible.name: i18n("Diagnostic log file path")
        }

        RowLayout {
            Layout.fillWidth: true

            Button {
                text: i18n("Open Plasma journal")
                ToolTip.text: i18n("Show recent Plasma Shell journal messages and continue following new ones in a terminal.")
                ToolTip.visible: hovered
                onClicked: page.launchError = cityCatalog.openPlasmaJournal()
            }

            Button {
                text: i18n("Open current log")
                ToolTip.text: i18n("Open the current diagnostic log in the default text editor.")
                ToolTip.visible: hovered
                onClicked: page.openLocation(cityCatalog.logFilePath)
            }

            Button {
                text: i18n("Open log folder")
                ToolTip.text: i18n("Open the folder containing the current and rotated diagnostic logs.")
                ToolTip.visible: hovered
                onClicked: page.openLocation(
                               cityCatalog.logFilePath.substring(
                                   0, cityCatalog.logFilePath.lastIndexOf("/")))
            }
        }

        Label {
            Layout.fillWidth: true
            visible: page.launchError.length > 0
            text: page.launchError
            color: Kirigami.Theme.negativeTextColor
            wrapMode: Text.WordWrap
        }

        Label {
            Layout.fillWidth: true
            text: i18n("The journal opens in Konsole when available, otherwise your configured terminal. It shows Plasma Shell messages from the last 15 minutes and follows new messages.")
            wrapMode: Text.WordWrap
            opacity: 0.75
        }
    }
}
