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
