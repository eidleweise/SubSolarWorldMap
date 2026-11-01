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

test("sublunar point agrees with the Moon's overhead position during the 2024 eclipse", () => {
    const point = solarMath.sublunarPoint(new Date("2024-04-08T18:17:00Z"))
    const sun = solarMath.subsolarPoint(new Date("2024-04-08T18:17:00Z"))

    assert.ok(Math.abs(point.latitude - sun.latitude) < 1,
              `latitude was ${point.latitude}`)
    const longitudeDifference = ((point.longitude - sun.longitude + 540) % 360) - 180
    assert.ok(Math.abs(longitudeDifference) < 1,
              `longitude was ${point.longitude}`)
})

test("sublunar longitude advances westward and remains within map bounds", () => {
    const before = solarMath.sublunarPoint(new Date("2024-04-08T18:00:00Z"))
    const after = solarMath.sublunarPoint(new Date("2024-04-08T19:00:00Z"))
    const westwardChange = ((before.longitude - after.longitude + 540) % 360) - 180

    assert.ok(westwardChange > 13 && westwardChange < 17,
              `longitude changed westward by ${westwardChange} degrees`)
    assert.ok(after.latitude >= -90 && after.latitude <= 90)
    assert.ok(after.longitude >= -180 && after.longitude < 180)
})

test("lunar phase identifies new and full moons with correct illumination", () => {
    const newMoon = solarMath.lunarPhase(new Date("2024-04-08T18:21:00Z"))
    const fullMoon = solarMath.lunarPhase(new Date("2024-03-25T07:00:00Z"))

    assert.equal(newMoon.name, "New Moon")
    assert.ok(newMoon.illumination < 0.01,
              `new moon illumination was ${newMoon.illumination}`)
    assert.equal(fullMoon.name, "Full Moon")
    assert.ok(fullMoon.illumination > 0.99,
              `full moon illumination was ${fullMoon.illumination}`)
})

test("lunar phase preserves waxing and waning direction", () => {
    const waxing = solarMath.lunarPhase(new Date("2024-04-12T12:00:00Z"))
    const waning = solarMath.lunarPhase(new Date("2024-04-28T12:00:00Z"))

    assert.equal(waxing.waxing, true)
    assert.equal(waning.waxing, false)
    assert.ok(waxing.illumination > 0 && waxing.illumination < 1)
    assert.ok(waning.illumination > 0 && waning.illumination < 1)
})

test("lunar calculations depend on the UTC instant, not local timezone notation", () => {
    const utc = new Date("2024-04-12T12:00:00Z")
    const offset = new Date("2024-04-12T07:00:00-05:00")
    const utcPoint = solarMath.sublunarPoint(utc)
    const offsetPoint = solarMath.sublunarPoint(offset)
    const utcPhase = solarMath.lunarPhase(utc)
    const offsetPhase = solarMath.lunarPhase(offset)

    assert.ok(Math.abs(utcPoint.latitude - offsetPoint.latitude) < 1e-10)
    assert.ok(Math.abs(utcPoint.longitude - offsetPoint.longitude) < 1e-10)
    assert.equal(utcPhase.name, offsetPhase.name)
    assert.ok(Math.abs(utcPhase.illumination - offsetPhase.illumination) < 1e-10)
})

test("lunar calculations reject invalid dates", () => {
    assert.throws(() => solarMath.sublunarPoint(new Date("invalid")),
                  { name: "TypeError" })
    assert.throws(() => solarMath.lunarPhase("2024-04-08T18:21:00Z"),
                  { name: "TypeError" })
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
