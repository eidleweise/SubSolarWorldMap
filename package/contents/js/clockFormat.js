.pragma library

// Formats a clock string that mirrors the map-clock badge in main.qml, but can
// render the wall-clock time of an arbitrary IANA timezone.
//
// Why Intl.DateTimeFormat instead of Qt.format*: Qt.formatTime /
// Qt.formatDateTime / toLocaleDateString always render in the system-local
// zone and offer no way to target an arbitrary IANA zone. The pin tooltips need
// the time AT THE PIN'S LOCATION, so we use the JS engine's Intl.DateTimeFormat
// with a `timeZone` option to obtain that zone's wall-clock components, then
// assemble the string to byte-for-byte match the clock's chosen date/time/tz
// formats. When no (or an invalid) zone is supplied we fall back to the
// system-local zone, matching the clock exactly and never emitting
// "Invalid Date".

// The four time patterns, indexed by Plasmoid.configuration.timeFormat, exactly
// as the clock badge defines them.
var TIME_PATTERNS = ["HH:mm", "h:mm AP", "HH:mm:ss", "h:mm:ss AP"]

function pad2(value) {
    return value < 10 ? "0" + value : "" + value
}

// Extracts the named part produced by Intl.DateTimeFormat.formatToParts.
function partValue(parts, type) {
    for (var i = 0; i < parts.length; i++) {
        if (parts[i].type === type) {
            return parts[i].value
        }
    }
    return ""
}

// Builds the Intl options object, adding `timeZone` only when a zone is given so
// the system-local fallback path is a plain (zone-less) formatter.
function withZone(options, ianaTimeZone) {
    if (ianaTimeZone) {
        options.timeZone = ianaTimeZone
    }
    return options
}

// Date segment, matching main.qml's dateFormat switch:
//   0 -> short, 2 -> ISO (yyyy-MM-dd), default/1 -> long.
function formatDateSegment(date, dateFormat, localeName, ianaTimeZone) {
    if (dateFormat === 2) {
        var isoParts = new Intl.DateTimeFormat("en-CA", withZone({
            year: "numeric", month: "2-digit", day: "2-digit"
        }, ianaTimeZone)).formatToParts(date)
        return partValue(isoParts, "year") + "-"
                + partValue(isoParts, "month") + "-"
                + partValue(isoParts, "day")
    }
    var style = dateFormat === 0 ? "short" : "long"
    return new Intl.DateTimeFormat(localeName, withZone({
        dateStyle: style
    }, ianaTimeZone)).format(date)
}

// Time segment, matching main.qml's TIME_PATTERNS. Built from zone-local parts
// so output is identical to the clock's Qt.formatTime patterns (zero-padded 24h
// hour, uppercase AM/PM, optional seconds).
function formatTimeSegment(date, timeFormat, ianaTimeZone) {
    var pattern = TIME_PATTERNS[timeFormat] || TIME_PATTERNS[0]
    var is12Hour = pattern.indexOf("AP") !== -1
    var withSeconds = pattern.indexOf("ss") !== -1

    var options = {
        hour: "2-digit",
        minute: "2-digit",
        hour12: is12Hour,
        hourCycle: is12Hour ? "h12" : "h23"
    }
    if (withSeconds) {
        options.second = "2-digit"
    }
    var parts = new Intl.DateTimeFormat("en-US", withZone(options, ianaTimeZone)).formatToParts(date)

    var hour = parseInt(partValue(parts, "hour"), 10)
    var minute = partValue(parts, "minute")
    var second = partValue(parts, "second")

    var result
    if (is12Hour) {
        var dayPeriod = partValue(parts, "dayPeriod").toUpperCase()
        var hour12 = hour % 12
        if (hour12 === 0) {
            hour12 = 12
        }
        result = hour12 + ":" + minute
        if (withSeconds) {
            result += ":" + second
        }
        result += " " + dayPeriod
    } else {
        result = pad2(hour) + ":" + minute
        if (withSeconds) {
            result += ":" + second
        }
    }
    return result
}

// Timezone segment, matching main.qml's timezoneFormat switch:
//   0 -> hidden, 1 -> abbreviation (Qt "t"), 2 -> full name (Qt "tttt").
// Intl's timeZoneName short/long are the closest arbitrary-zone equivalents.
function formatTimezoneSegment(date, timezoneFormat, localeName, ianaTimeZone) {
    if (timezoneFormat !== 1 && timezoneFormat !== 2) {
        return ""
    }
    var nameStyle = timezoneFormat === 1 ? "short" : "long"
    var parts = new Intl.DateTimeFormat(localeName, withZone({
        hour: "2-digit",
        timeZoneName: nameStyle
    }, ianaTimeZone)).formatToParts(date)
    return partValue(parts, "timeZoneName")
}

function buildClockString(date, dateFormat, timeFormat, timezoneFormat, localeName, ianaTimeZone) {
    var clockText = formatDateSegment(date, dateFormat, localeName, ianaTimeZone)
            + "  ·  " + formatTimeSegment(date, timeFormat, ianaTimeZone)
    var tz = formatTimezoneSegment(date, timezoneFormat, localeName, ianaTimeZone)
    if (tz) {
        clockText += " " + tz
    }
    return clockText
}

// Public entry point. Returns the clock-formatted string for `date` in the
// given IANA zone, falling back to system-local time when `ianaTimeZone` is
// empty/missing or rejected by Intl (invalid id). Never throws out of the
// binding and never returns "Invalid Date".
function formatLocationClock(date, dateFormat, timeFormat, timezoneFormat, localeName, ianaTimeZone) {
    var zone = (typeof ianaTimeZone === "string" && ianaTimeZone.length > 0) ? ianaTimeZone : undefined
    if (zone) {
        try {
            return buildClockString(date, dateFormat, timeFormat, timezoneFormat, localeName, zone)
        } catch (e) {
            // Invalid IANA id (RangeError) or unsupported Intl: fall through to
            // system-local formatting below.
        }
    }
    return buildClockString(date, dateFormat, timeFormat, timezoneFormat, localeName, undefined)
}
