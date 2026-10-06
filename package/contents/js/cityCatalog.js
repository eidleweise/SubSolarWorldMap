.pragma library

function distanceKm(left, right) {
    const radians = Math.PI / 180
    const latitudeDelta = (right.latitude - left.latitude) * radians
    const longitudeDelta = (right.longitude - left.longitude) * radians
    const haversine = Math.sin(latitudeDelta / 2) ** 2
            + Math.cos(left.latitude * radians) * Math.cos(right.latitude * radians)
            * Math.sin(longitudeDelta / 2) ** 2
    const safeHaversine = Math.min(1, Math.max(0, haversine))
    return 6371 * 2 * Math.atan2(
        Math.sqrt(safeHaversine),
        Math.sqrt(1 - safeHaversine))
}

function uniqueCities(cities) {
    if (!cities || typeof cities.length !== "number") {
        throw new TypeError("City catalog must be an array")
    }

    const grouped = new Map()
    for (let index = 0; index < cities.length; index++) {
        const city = cities[index]
        const key = (city.name + "\u0000" + city.country).toLocaleLowerCase()
        const sameName = grouped.get(key) || []
        const duplicateIndex = sameName.findIndex(existing => distanceKm(existing, city) < 2)
        if (duplicateIndex < 0) {
            sameName.push(city)
        } else if ((city.population || 0) > (sameName[duplicateIndex].population || 0)) {
            sameName[duplicateIndex] = city
        }
        grouped.set(key, sameName)
    }

    const unique = []
    for (const sameName of grouped.values()) {
        unique.push(...sameName)
    }
    return unique.sort((left, right) =>
        left.name.localeCompare(right.name) || left.country.localeCompare(right.country))
}

function searchCities(cities, query, limit) {
    return searchUniqueCities(uniqueCities(cities), query, limit)
}

function searchUniqueCities(cities, query, limit) {
    if (!cities || typeof cities.length !== "number") {
        throw new TypeError("City catalog must be an array")
    }
    if (typeof query !== "string") {
        throw new TypeError("City search query must be a string")
    }
    if (!Number.isInteger(limit) || limit < 1) {
        throw new RangeError("City search limit must be a positive integer")
    }

    const normalizedQuery = query.trim().toLocaleLowerCase()
    if (normalizedQuery.length < 2) {
        return []
    }
    const matches = []
    for (let index = 0; index < cities.length; index++) {
        const city = cities[index]
        const name = String(city.name || "")
        const country = String(city.country || "")
        if ((name + " " + country).toLocaleLowerCase().includes(normalizedQuery)) {
            matches.push({
                city,
                startsWithQuery: name.toLocaleLowerCase().startsWith(normalizedQuery)
            })
        }
    }
    matches.sort((left, right) => {
        if (left.startsWithQuery !== right.startsWithQuery) {
            return left.startsWithQuery ? -1 : 1
        }
        return String(left.city.name || "").localeCompare(String(right.city.name || ""))
                || String(left.city.country || "").localeCompare(String(right.city.country || ""))
    })
    return matches.slice(0, limit).map(match => match.city)
}

function nearestCity(cities, latitude, longitude) {
    if (!cities || typeof cities.length !== "number" || cities.length === 0) {
        throw new TypeError("City catalog must be a non-empty array")
    }
    if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90
            || !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
        throw new TypeError("Coordinates must be finite latitude and longitude values in range")
    }

    const radians = Math.PI / 180
    let nearest = null
    let nearestDistance = Infinity

    for (let index = 0; index < cities.length; index++) {
        const city = cities[index]
        const latitudeDelta = (city.latitude - latitude) * radians
        const longitudeDelta = (city.longitude - longitude) * radians
        const haversine = Math.sin(latitudeDelta / 2) ** 2
                + Math.cos(latitude * radians) * Math.cos(city.latitude * radians)
                * Math.sin(longitudeDelta / 2) ** 2
        const safeHaversine = Math.min(1, Math.max(0, haversine))
        const distanceKm = 6371 * 2 * Math.atan2(
            Math.sqrt(safeHaversine),
            Math.sqrt(1 - safeHaversine))

        if (distanceKm < nearestDistance) {
            nearest = city
            nearestDistance = distanceKm
        }
    }

    return {
        cityId: nearest.cityId,
        name: nearest.name,
        country: nearest.country,
        distanceKm: nearestDistance
    }
}
