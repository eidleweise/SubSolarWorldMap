const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")
const vm = require("node:vm")

const sourcePath = path.join(__dirname, "../package/contents/js/cityCatalog.js")
const source = fs.readFileSync(sourcePath, "utf8")
    .replace(/^\.pragma library\s*/m, "")
const catalog = vm.createContext({})
vm.runInContext(source, catalog, { filename: sourcePath })

const cities = [
    { cityId: "london", name: "London", country: "United Kingdom", latitude: 51.5072, longitude: -0.1276 },
    { cityId: "paris", name: "Paris", country: "France", latitude: 48.8566, longitude: 2.3522 }
]

test("nearest city resolves coordinates to the closest bundled city", () => {
    const nearest = catalog.nearestCity(cities, 51.5074, -0.1278)

    assert.equal(nearest.name, "London")
    assert.equal(nearest.country, "United Kingdom")
    assert.ok(nearest.distanceKm < 2)
})

test("nearest city rejects invalid coordinates", () => {
    assert.throws(() => catalog.nearestCity(cities, 91, 0), { name: "TypeError" })
    assert.throws(() => catalog.nearestCity(cities, 0, Infinity), { name: "TypeError" })
})

test("nearest city rejects an empty city list", () => {
    assert.throws(() => catalog.nearestCity([], 0, 0), { name: "TypeError" })
})

test("nearest city supports array-like Qt list values", () => {
    const qtListLike = { 0: cities[0], 1: cities[1], length: cities.length }
    const nearest = catalog.nearestCity(qtListLike, 51.5074, -0.1278)

    assert.equal(nearest.name, "London")
})
