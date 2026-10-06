.pragma library

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
