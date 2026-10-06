const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")
const vm = require("node:vm")

const sourcePath = path.join(__dirname, "../package/contents/js/mapProjection.js")
const source = fs.readFileSync(sourcePath, "utf8")
    .replace(/^\.pragma library\s*/m, "")
const projection = vm.createContext({})
vm.runInContext(source, projection, { filename: sourcePath })

test("equirectangular projection maps geographic bounds to map edges", () => {
    const northwest = projection.equirectangularPoint(90, -180, 360, 180)
    const southeast = projection.equirectangularPoint(-90, 180, 360, 180)
    const origin = projection.equirectangularPoint(0, 0, 360, 180)

    assert.equal(northwest.x, 0)
    assert.equal(northwest.y, 0)
    assert.equal(southeast.x, 360)
    assert.equal(southeast.y, 180)
    assert.equal(origin.x, 180)
    assert.equal(origin.y, 90)
})

test("equirectangular projection places known city coordinates consistently", () => {
    const point = projection.equirectangularPoint(51.5072, -0.1276, 1280, 640)

    assert.ok(Math.abs(point.x - 639.546) < 0.01)
    assert.ok(Math.abs(point.y - 136.863) < 0.01)
})

test("equirectangular projection rejects invalid coordinates or dimensions", () => {
    assert.throws(() => projection.equirectangularPoint(91, 0, 360, 180), { name: "TypeError" })
    assert.throws(() => projection.equirectangularPoint(0, 0, 0, 180), { name: "TypeError" })
})
