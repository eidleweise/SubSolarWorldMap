.pragma library

function forCity(serializedSettings, cityId) {
    const defaults = { color: 1, opacity: 100 }
    if (typeof serializedSettings !== "string" || serializedSettings.length === 0) {
        return defaults
    }

    try {
        const settings = JSON.parse(serializedSettings)
        const city = settings[cityId]
        if (!city || typeof city !== "object") {
            return defaults
        }

        return {
            color: Number.isInteger(city.color) && city.color >= 0 && city.color <= 5
                    ? city.color : defaults.color,
            opacity: Number.isInteger(city.opacity) && city.opacity >= 10 && city.opacity <= 100
                      ? city.opacity : defaults.opacity
        }
    } catch (error) {
        return defaults
    }
}

function withOpacityForCities(serializedSettings, cityIds, opacity) {
    if (!cityIds || typeof cityIds.length !== "number") {
        throw new TypeError("City IDs must be a list")
    }
    if (!Number.isInteger(opacity) || opacity < 10 || opacity > 100) {
        throw new RangeError("Pin opacity must be an integer from 10 to 100")
    }

    let settings = {}
    if (typeof serializedSettings === "string" && serializedSettings.length > 0) {
        try {
            settings = JSON.parse(serializedSettings)
        } catch (error) {
            settings = {}
        }
    }
    if (!settings || typeof settings !== "object" || Array.isArray(settings)) {
        settings = {}
    }

    for (let index = 0; index < cityIds.length; index++) {
        const cityId = cityIds[index]
        const existing = settings[cityId]
        settings[cityId] = {
            color: existing && Number.isInteger(existing.color)
                    && existing.color >= 0 && existing.color <= 5
                    ? existing.color : 1,
            opacity: opacity
        }
    }
    return JSON.stringify(settings)
}
