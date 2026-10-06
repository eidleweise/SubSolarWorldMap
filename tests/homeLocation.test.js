const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")
const vm = require("node:vm")

const sourcePath = path.join(__dirname, "../package/contents/js/homeLocation.js")
const source = fs.readFileSync(sourcePath, "utf8")
    .replace(/^\.pragma library\s*/m, "")
const homeLocation = vm.createContext({})
vm.runInContext(source, homeLocation, { filename: sourcePath })

test("fresh system location takes precedence over manual fallback", () => {
    const coordinates = homeLocation.coordinatesForHomePin(
        true,
        { latitude: 51.5, longitude: -0.1 },
        true,
        { latitude: 40.7, longitude: -74 })

    assert.deepEqual({ ...coordinates }, { latitude: 51.5, longitude: -0.1 })
})

test("manual coordinates are used when no fresh system location is available", () => {
    const coordinates = homeLocation.coordinatesForHomePin(
        false,
        { latitude: 51.5, longitude: -0.1 },
        true,
        { latitude: 40.7, longitude: -74 })

    assert.deepEqual({ ...coordinates }, { latitude: 40.7, longitude: -74 })
})

test("stale saved coordinates are ignored when location is unavailable and fallback is disabled", () => {
    const coordinates = homeLocation.coordinatesForHomePin(
        false,
        { latitude: 51.5, longitude: -0.1 },
        false,
        { latitude: 40.7, longitude: -74 })

    assert.equal(coordinates, null)
})

test("invalid fresh coordinates fall back to valid manual coordinates", () => {
    const coordinates = homeLocation.coordinatesForHomePin(
        true,
        { latitude: 91, longitude: -0.1 },
        true,
        { latitude: 40.7, longitude: -74 })

    assert.deepEqual({ ...coordinates }, { latitude: 40.7, longitude: -74 })
})

test("invalid manual fallback coordinates do not produce a Home pin", () => {
    const coordinates = homeLocation.coordinatesForHomePin(
        false,
        null,
        true,
        { latitude: 40.7, longitude: -181 })

    assert.equal(coordinates, null)
})
