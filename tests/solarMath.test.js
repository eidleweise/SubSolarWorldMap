const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")
const vm = require("node:vm")

const sourcePath = path.join(__dirname, "../package/contents/js/solarMath.js")
const source = fs.readFileSync(sourcePath, "utf8")
    .replace(/^\.pragma library\s*/m, "")
const solarMath = vm.createContext({ Date })
vm.runInContext(source, solarMath, { filename: sourcePath })

test("subsolar point is near the equator at the March equinox", () => {
    const point = solarMath.subsolarPoint(new Date("2024-03-20T12:00:00Z"))

    assert.ok(Math.abs(point.latitude) < 0.2, `latitude was ${point.latitude}`)
    assert.ok(Math.abs(point.longitude) < 3, `longitude was ${point.longitude}`)
})

test("subsolar latitude matches the June solstice", () => {
    const point = solarMath.subsolarPoint(new Date("2024-06-20T12:00:00Z"))

    assert.ok(Math.abs(point.latitude - 23.44) < 0.2,
              `latitude was ${point.latitude}`)
})

test("subsolar longitude advances westward as UTC time advances", () => {
    const before = solarMath.subsolarPoint(new Date("2024-06-20T12:00:00Z"))
    const after = solarMath.subsolarPoint(new Date("2024-06-20T13:00:00Z"))
    const westwardChange = ((before.longitude - after.longitude + 540) % 360) - 180

    assert.ok(westwardChange > 14 && westwardChange < 16,
              `longitude changed westward by ${westwardChange} degrees`)
})

test("calculation depends on the UTC instant, not the local timezone", () => {
    const utc = solarMath.subsolarPoint(new Date("2024-06-20T12:00:00Z"))
    const offset = solarMath.subsolarPoint(new Date("2024-06-20T07:00:00-05:00"))

    assert.ok(Math.abs(utc.latitude - offset.latitude) < 1e-10)
    assert.ok(Math.abs(utc.longitude - offset.longitude) < 1e-10)
})

test("solar altitude crosses the horizon around Greenwich equinox sunrise and sunset", () => {
    const beforeSunrise = solarMath.subsolarPoint(new Date("2024-03-20T06:00:00Z"))
    const afterSunrise = solarMath.subsolarPoint(new Date("2024-03-20T07:00:00Z"))
    const beforeSunset = solarMath.subsolarPoint(new Date("2024-03-20T18:00:00Z"))
    const afterSunset = solarMath.subsolarPoint(new Date("2024-03-20T19:00:00Z"))

    assert.ok(solarMath.solarAltitudeCosine(51.4779, 0, beforeSunrise) < 0)
    assert.ok(solarMath.solarAltitudeCosine(51.4779, 0, afterSunrise) > 0)
    assert.ok(solarMath.solarAltitudeCosine(51.4779, 0, beforeSunset) > 0)
    assert.ok(solarMath.solarAltitudeCosine(51.4779, 0, afterSunset) < 0)
})

test("polar-circle locations remain in daylight in June and darkness in December", () => {
    const juneSunrise = solarMath.subsolarPoint(new Date("2024-06-20T00:00:00Z"))
    const juneSunset = solarMath.subsolarPoint(new Date("2024-06-20T12:00:00Z"))
    const decemberSunrise = solarMath.subsolarPoint(new Date("2024-12-21T00:00:00Z"))
    const decemberSunset = solarMath.subsolarPoint(new Date("2024-12-21T12:00:00Z"))

    assert.ok(solarMath.solarAltitudeCosine(80, 0, juneSunrise) > 0)
    assert.ok(solarMath.solarAltitudeCosine(80, 0, juneSunset) > 0)
    assert.ok(solarMath.solarAltitudeCosine(80, 0, decemberSunrise) < 0)
    assert.ok(solarMath.solarAltitudeCosine(80, 0, decemberSunset) < 0)
})

test("invalid date inputs fail explicitly", () => {
    assert.throws(() => solarMath.subsolarPoint(new Date("invalid")),
                  { name: "TypeError" })
    assert.throws(() => solarMath.subsolarPoint("2024-06-20T12:00:00Z"),
                  { name: "TypeError" })
})

test("solar altitude calculation rejects invalid coordinates", () => {
    const sun = solarMath.subsolarPoint(new Date("2024-03-20T12:00:00Z"))

    assert.throws(() => solarMath.solarAltitudeCosine(91, 0, sun),
                  { name: "TypeError" })
    assert.throws(() => solarMath.solarAltitudeCosine(0, 181, sun),
                  { name: "TypeError" })
    assert.throws(() => solarMath.solarAltitudeCosine(0, 0, null),
                  { name: "TypeError" })
})
