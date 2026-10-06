const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")
const vm = require("node:vm")

const sourcePath = path.join(__dirname, "../package/contents/js/pinAppearance.js")
const source = fs.readFileSync(sourcePath, "utf8")
    .replace(/^\.pragma library\s*/m, "")
const appearance = vm.createContext({})
vm.runInContext(source, appearance, { filename: sourcePath })

test("city pins have independent color and opacity settings", () => {
    const settings = JSON.stringify({
        canberra: { color: 0, opacity: 45 },
        nairobi: { color: 4, opacity: 80 }
    })

    assert.deepEqual(
        { ...appearance.forCity(settings, "canberra") },
        { color: 0, opacity: 45 }
    )
    assert.deepEqual(
        { ...appearance.forCity(settings, "nairobi") },
        { color: 4, opacity: 80 }
    )
})

test("city pin settings default safely for unknown or invalid values", () => {
    assert.deepEqual(
        { ...appearance.forCity("not-json", "city") },
        { color: 1, opacity: 100 }
    )
    assert.deepEqual(
        { ...appearance.forCity(JSON.stringify({ city: { color: 99, opacity: 0 } }), "city") },
        { color: 1, opacity: 100 }
    )
})

test("shift-click opacity update changes all selected cities and preserves colors", () => {
    const settings = JSON.stringify({
        canberra: { color: 0, opacity: 45 },
        nairobi: { color: 4, opacity: 80 },
        unrelated: { color: 2, opacity: 65 }
    })
    const updated = JSON.parse(
        appearance.withOpacityForCities(settings, ["canberra", "nairobi"], 55))

    assert.deepEqual(updated.canberra, { color: 0, opacity: 55 })
    assert.deepEqual(updated.nairobi, { color: 4, opacity: 55 })
    assert.deepEqual(updated.unrelated, { color: 2, opacity: 65 })
})

test("bulk opacity accepts a Qt-style list of selected city IDs", () => {
    const settings = JSON.stringify({
        canberra: { color: 0, opacity: 45 },
        nairobi: { color: 4, opacity: 80 }
    })
    const selectedCities = { 0: "canberra", 1: "nairobi", length: 2 }
    const updated = JSON.parse(
        appearance.withOpacityForCities(settings, selectedCities, 55))

    assert.deepEqual(updated.canberra, { color: 0, opacity: 55 })
    assert.deepEqual(updated.nairobi, { color: 4, opacity: 55 })
})

test("bulk city opacity rejects invalid values", () => {
    assert.throws(
        () => appearance.withOpacityForCities("{}", ["city"], 0),
        { name: "RangeError" }
    )
})
