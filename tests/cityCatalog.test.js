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
    { cityId: "paris", name: "Paris", country: "France", latitude: 48.8566, longitude: 2.3522 },
    { cityId: "londonderry", name: "Londonderry", country: "United Kingdom", latitude: 54.997, longitude: -7.309 },
    { cityId: "sumbe-a", name: "Sumbe", country: "Angola", latitude: -11.20605, longitude: 13.84371, population: 205832 },
    { cityId: "sumbe-b", name: "Sumbe", country: "Angola", latitude: -11.2061, longitude: 13.8448, population: 205832 },
    { cityId: "saavedra-a", name: "Saavedra", country: "Argentina", latitude: -34.5543121, longitude: -58.5097595, population: 50295 },
    { cityId: "saavedra-b", name: "Saavedra", country: "Argentina", latitude: -37.7395643, longitude: -63.1295918, population: 50295 }
]

test("city list is alphabetized and near-identical duplicate records collapse", () => {
    const results = catalog.uniqueCities(cities)

    assert.deepEqual(
        Array.from(results, city => city.cityId),
        ["london", "londonderry", "paris", "saavedra-a", "saavedra-b", "sumbe-a"]
    )
})

test("unique city list accepts array-like Qt list values", () => {
    const qtListLike = { 0: cities[0], 1: cities[1], length: 2 }
    const results = catalog.uniqueCities(qtListLike)

    assert.deepEqual(Array.from(results, city => city.name), ["London", "Paris"])
})

test("city search matches city and country names and prioritizes city-name prefixes", () => {
    const results = catalog.searchCities(cities, "lon", 8)

    assert.deepEqual(
        Array.from(results, city => city.cityId),
        ["london", "londonderry"]
    )
    assert.deepEqual(
        Array.from(catalog.searchCities(cities, "france", 8), city => city.cityId),
        ["paris"]
    )
})

test("searching a prepared catalog preserves the normal search results", () => {
    const prepared = catalog.uniqueCities(cities)
    const results = catalog.searchUniqueCities(prepared, "lon", 8)

    assert.deepEqual(
        Array.from(results, city => city.cityId),
        ["london", "londonderry"]
    )
})

test("city search limits results and ignores queries shorter than two characters", () => {
    assert.equal(catalog.searchCities(cities, "l", 8).length, 0)
    assert.equal(catalog.searchCities(cities, "on", 1).length, 1)
})

test("city search returns alphabetized results when names share a prefix", () => {
    const results = catalog.searchCities(cities, "lon", 8)

    assert.deepEqual(
        Array.from(results, city => city.name),
        ["London", "Londonderry"]
    )
})

test("city search rejects invalid inputs", () => {
    assert.throws(() => catalog.searchCities(null, "London", 8), { name: "TypeError" })
    assert.throws(() => catalog.searchCities(cities, null, 8), { name: "TypeError" })
    assert.throws(() => catalog.searchCities(cities, "London", 0), { name: "RangeError" })
})

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
    const qtListLike = { 0: cities[0], 1: cities[1], length: 2 }
    const nearest = catalog.nearestCity(qtListLike, 51.5074, -0.1278)

    assert.equal(nearest.name, "London")
})
