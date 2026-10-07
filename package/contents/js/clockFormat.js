.pragma library

// Formats a clock string that mirrors the map-clock badge in main.qml, for a
// location pin tooltip.
//
// RUNTIME CONSTRAINT (confirmed by running inside the Plasma/Qt 6.11 QML JS
// engine): ECMAScript `Intl` is NOT defined in this engine — `typeof Intl` is
// "undefined", so any `Intl.DateTimeFormat(...)` call throws
// `ReferenceError: Intl is not defined`. A `.pragma library` JS file also does
// NOT receive the QML `Qt` object or the `Locale` enum. Because of this:
//
//   * The SYSTEM-LOCAL case (empty/missing zone — the Home pin always uses
//     this, and every pin uses it when Intl is absent) is produced by a
//     Qt-based `systemLocalFormatter` callback injected from the QML side
//     (main.qml -> MapView.qml). That callback shares the badge's exact
//     Qt.format*/toLocaleDateString logic, so the tooltip is byte-for-byte
//     identical to the badge and can never drift from it.
//
//   * The ARBITRARY-IANA-ZONE case (city pins with a real zone like
//     "Europe/London") still ATTEMPTS `Intl` first (so a future engine that
//     ships Intl would render true per-zone wall-clock time). On today's engine
//     that attempt throws and we fall back to the system-local callback, i.e.
//     city pins show SYSTEM-LOCAL time, not the pin's local time. This is the
//     lesser evil versus a blank/absent tooltip, and we do NOT invent timezone
//     offset math or tables to work around it.
//
// `formatLocationClock(...)` is guaranteed to NEVER throw out of the binding
// and NEVER return an empty string or "Invalid Date", under any input.

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

// Intl-backed clock string. This is the ONLY place `Intl` is used; every caller
// wraps it in try/catch because `Intl` is absent in the Plasma/Qt QML engine.
function buildClockString(date, dateFormat, timeFormat, timezoneFormat, localeName, ianaTimeZone) {
    var clockText = formatDateSegment(date, dateFormat, localeName, ianaTimeZone)
            + "  ·  " + formatTimeSegment(date, timeFormat, ianaTimeZone)
    var tz = formatTimezoneSegment(date, timezoneFormat, localeName, ianaTimeZone)
    if (tz) {
        clockText += " " + tz
    }
    return clockText
}

// Last-resort, dependency-free formatter. Uses only plain `Date` getters (no
// `Intl`, no `Qt`) so it can run in any engine and can never throw. Guards
// against an invalid date so it never emits "Invalid Date".
function safeFallback(date) {
    var d = (date instanceof Date) ? date : new Date(date)
    if (isNaN(d.getTime())) {
        d = new Date()
    }
    return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate())
            + "  ·  " + pad2(d.getHours()) + ":" + pad2(d.getMinutes())
}

// Public entry point. Returns the clock-formatted string for `date`.
//
// Resolution order (each step fully guarded so nothing can escape):
//   (a) if `ianaTimeZone` is a non-empty string, try Intl for that zone's
//       wall-clock time (works only if the engine ships Intl);
//   (b) if a `systemLocalFormatter` callback was supplied (QML-side Qt
//       formatter), use it for system-local time — this is the normal path in
//       the running plasmoid, and the only path that works without Intl;
//   (c) try the internal Intl-backed system-local build (what the node test
//       suite exercises, where Intl IS present);
//   (d) finally, a plain-`Date` fallback that always yields a sensible string.
//
// `systemLocalFormatter` is `(date, dateFormat, timeFormat, timezoneFormat) ->
// String`. It is optional; the node tests may omit it (they have Intl).
function formatLocationClock(date, dateFormat, timeFormat, timezoneFormat, localeName, ianaTimeZone, systemLocalFormatter) {
    var zone = (typeof ianaTimeZone === "string" && ianaTimeZone.length > 0) ? ianaTimeZone : undefined

    // (a) Arbitrary IANA zone via Intl (no-op on the current QML engine).
    if (zone) {
        try {
            return buildClockString(date, dateFormat, timeFormat, timezoneFormat, localeName, zone)
        } catch (zoneError) {
            // Intl absent, or invalid IANA id (RangeError): fall through to the
            // system-local paths below. City pins thus show system-local time
            // when Intl is unavailable (documented limitation).
        }
    }

    // (b) QML-side Qt system-local formatter (badge-identical). Primary path in
    // the running plasmoid.
    if (typeof systemLocalFormatter === "function") {
        try {
            var formatted = systemLocalFormatter(date, dateFormat, timeFormat, timezoneFormat)
            if (formatted) {
                return formatted
            }
        } catch (callbackError) {
            // Fall through to the internal best-effort below.
        }
    }

    // (c) Internal Intl-backed system-local build (used by the node tests, where
    // Intl is injected). Guarded so an Intl-less engine can never escape here.
    try {
        var local = buildClockString(date, dateFormat, timeFormat, timezoneFormat, localeName, undefined)
        if (local) {
            return local
        }
    } catch (localError) {
        // Fall through to the guaranteed plain-Date fallback.
    }

    // (d) Guaranteed non-empty, non-"Invalid Date" fallback.
    return safeFallback(date)
}
