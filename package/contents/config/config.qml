import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Date & Time")
        icon: "preferences-system-time"
        source: "config/Appearance.qml"
    }
    ConfigCategory {
        name: i18n("Cities")
        icon: "mark-location"
        source: "config/Cities.qml"
    }
    ConfigCategory {
        name: i18n("Developer")
        icon: "applications-development"
        source: "config/Developer.qml"
    }
}
