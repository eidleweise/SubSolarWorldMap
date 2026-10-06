.pragma library

function isValidCoordinates(coordinates) {
    return coordinates
            && Number.isFinite(coordinates.latitude)
            && coordinates.latitude >= -90
            && coordinates.latitude <= 90
            && Number.isFinite(coordinates.longitude)
            && coordinates.longitude >= -180
            && coordinates.longitude <= 180
}

function coordinatesForHomePin(locationAvailable,
                               detectedCoordinates,
                               useManualFallback,
                               manualCoordinates) {
    if (locationAvailable && isValidCoordinates(detectedCoordinates)) {
        return {
            latitude: detectedCoordinates.latitude,
            longitude: detectedCoordinates.longitude
        }
    }
    if (useManualFallback && isValidCoordinates(manualCoordinates)) {
        return {
            latitude: manualCoordinates.latitude,
            longitude: manualCoordinates.longitude
        }
    }
    return null
}
