const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")
const vm = require("node:vm")

const sourcePath = path.join(__dirname, "../package/contents/js/clockFormat.js")
const source = fs.readFileSync(sourcePath, "utf8")
    .replace(/^\.pragma library\s*/m, "")
const clock = vm.createContext({ Intl, parseInt })
vm.runInContext(source, clock, { filename: sourcePath })

// A fixed instant: 2024-01-15T18:05:09Z. In Europe/London (GMT, winter) this is
// 18:05:09; in Asia/Tokyo (UTC+9) it is 2024-01-16 03:05:09.
const instant = new Date("2024-01-15T18:05:09Z")

// Config enum values mirror main.qml / Appearance.qml.
const DATE_SHORT = 0
const DATE_LONG = 1
const DATE_ISO = 2
const TIME_24H = 0
const TIME_12H = 1
const TIME_24H_SEC = 2
const TIME_12H_SEC = 3
const TZ_HIDDEN = 0
const TZ_ABBREV = 1
const TZ_FULL = 2

test("ISO date and 24h time render in the given zone", () => {
    const result = clock.formatLocationClock(
        instant, DATE_ISO, TIME_24H, TZ_HIDDEN, "en-GB", "Europe/London")
    assert.equal(result, "2024-01-15  ·  18:05")
})

test("zone shifts the wall-clock date and time", () => {
    const tokyo = clock.formatLocationClock(
        instant, DATE_ISO, TIME_24H_SEC, TZ_HIDDEN, "en-GB", "Asia/Tokyo")
    // UTC+9 pushes the instant into the next calendar day.
    assert.equal(tokyo, "2024-01-16  ·  03:05:09")
})

test("12-hour time uses uppercase AM/PM", () => {
    const result = clock.formatLocationClock(
        instant, DATE_ISO, TIME_12H, TZ_HIDDEN, "en-GB", "Europe/London")
    assert.equal(result, "2024-01-15  ·  6:05 PM")
})

test("12-hour time with seconds", () => {
    const result = clock.formatLocationClock(
        instant, DATE_ISO, TIME_12H_SEC, TZ_HIDDEN, "en-GB", "Europe/London")
    assert.equal(result, "2024-01-15  ·  6:05:09 PM")
})

test("midnight renders as 12 in 12-hour mode", () => {
    // 2024-01-15T18:05:09Z is 2024-01-16 00:05:09 in UTC+6 (Asia/Dhaka).
    const result = clock.formatLocationClock(
        instant, DATE_ISO, TIME_12H, TZ_HIDDEN, "en-GB", "Asia/Dhaka")
    assert.equal(result, "2024-01-16  ·  12:05 AM")
})

test("short date segment is produced without throwing", () => {
    const result = clock.formatLocationClock(
        instant, DATE_SHORT, TIME_24H, TZ_HIDDEN, "en-GB", "Europe/London")
    assert.match(result, /·  18:05$/)
    assert.ok(result.length > 0)
})

test("long date segment is produced without throwing", () => {
    const result = clock.formatLocationClock(
        instant, DATE_LONG, TIME_24H, TZ_HIDDEN, "en-GB", "Europe/London")
    assert.match(result, /·  18:05$/)
    assert.ok(result.includes("2024"))
})

test("abbreviation timezone segment is appended", () => {
    const result = clock.formatLocationClock(
        instant, DATE_ISO, TIME_24H, TZ_ABBREV, "en-GB", "Europe/London")
    // Winter in London -> GMT. Intl short name yields "GMT".
    assert.equal(result, "2024-01-15  ·  18:05 GMT")
})

test("full name timezone segment is appended", () => {
    const result = clock.formatLocationClock(
        instant, DATE_ISO, TIME_24H, TZ_FULL, "en-GB", "Europe/London")
    assert.match(result, /^2024-01-15  ·  18:05 .+/)
    // The full name is longer than the abbreviation.
    assert.ok(result.length > "2024-01-15  ·  18:05 GMT".length)
})

test("empty zone falls back to system-local formatting without throwing", () => {
    assert.doesNotThrow(() => {
        const result = clock.formatLocationClock(
            instant, DATE_ISO, TIME_24H, TZ_HIDDEN, "en-GB", "")
        assert.match(result, /^\d{4}-\d{2}-\d{2}  ·  \d{2}:\d{2}$/)
    })
})

test("undefined zone falls back to system-local formatting without throwing", () => {
    assert.doesNotThrow(() => {
        const result = clock.formatLocationClock(
            instant, DATE_ISO, TIME_24H, TZ_HIDDEN, "en-GB", undefined)
        assert.match(result, /^\d{4}-\d{2}-\d{2}  ·  \d{2}:\d{2}$/)
    })
})

test("invalid IANA id falls back without throwing or Invalid Date", () => {
    let result
    assert.doesNotThrow(() => {
        result = clock.formatLocationClock(
            instant, DATE_ISO, TIME_24H, TZ_HIDDEN, "en-GB", "Not/AZone")
    })
    assert.ok(!result.includes("Invalid Date"))
    assert.match(result, /^\d{4}-\d{2}-\d{2}  ·  \d{2}:\d{2}$/)
})

// --- Intl-absent environment (mirrors the real Plasma/Qt QML JS engine) ------
//
// The QML JS engine does NOT define ECMAScript `Intl`, so load the library in a
// VM context WITHOUT `Intl` to prove formatLocationClock still never throws,
// never returns empty, and never produces "Invalid Date". A `systemLocalClock`
// stand-in mimics the Qt-based badge formatter injected from QML.
// `vm.createContext` still exposes the host's standard built-ins (including
// `Intl`), so explicitly remove `Intl` to faithfully reproduce the Qt engine
// where `typeof Intl === "undefined"`.
const noIntlClock = vm.createContext({ parseInt })
vm.runInContext("delete this.Intl; var Intl = undefined;", noIntlClock, { filename: "<no-intl-setup>" })
vm.runInContext(source, noIntlClock, { filename: sourcePath })

// Stand-in for main.qml's formatSystemLocalClock (ISO date + 24h time here).
function systemLocalStandIn(date, dateFormat, timeFormat, timezoneFormat) {
    const pad = (n) => (n < 10 ? "0" + n : "" + n)
    const dateText = date.getUTCFullYear() + "-"
        + pad(date.getUTCMonth() + 1) + "-" + pad(date.getUTCDate())
    const timeText = pad(date.getUTCHours()) + ":" + pad(date.getUTCMinutes())
    return dateText + "  ·  " + timeText + " [local]"
}

test("without Intl, empty zone uses the systemLocalFormatter callback", () => {
    let result
    assert.doesNotThrow(() => {
        result = noIntlClock.formatLocationClock(
            instant, DATE_ISO, TIME_24H, TZ_HIDDEN, "en-GB", "", systemLocalStandIn)
    })
    assert.equal(result, "2024-01-15  ·  18:05 [local]")
})

test("without Intl, a real zone falls back to the systemLocalFormatter callback", () => {
    let result
    assert.doesNotThrow(() => {
        result = noIntlClock.formatLocationClock(
            instant, DATE_ISO, TIME_24H, TZ_HIDDEN, "en-GB", "Europe/London", systemLocalStandIn)
    })
    // Intl is unavailable, so the zone cannot be honoured; the callback (system
    // -local) result is returned instead of throwing or blanking.
    assert.equal(result, "2024-01-15  ·  18:05 [local]")
    assert.ok(!result.includes("Invalid Date"))
})

test("without Intl and no callback, safeFallback yields a sensible string", () => {
    let result
    assert.doesNotThrow(() => {
        result = noIntlClock.formatLocationClock(
            instant, DATE_ISO, TIME_24H, TZ_HIDDEN, "en-GB", "")
    })
    assert.ok(result.length > 0)
    assert.ok(!result.includes("Invalid Date"))
    assert.match(result, /^\d{4}-\d{2}-\d{2}  ·  \d{2}:\d{2}$/)
})

test("without Intl and no callback, an invalid date never yields Invalid Date", () => {
    let result
    assert.doesNotThrow(() => {
        result = noIntlClock.formatLocationClock(
            new Date("nonsense"), DATE_ISO, TIME_24H, TZ_HIDDEN, "en-GB", "")
    })
    assert.ok(!result.includes("Invalid Date"))
    assert.match(result, /^\d{4}-\d{2}-\d{2}  ·  \d{2}:\d{2}$/)
})
