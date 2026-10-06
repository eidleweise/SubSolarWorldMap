.pragma library

function equirectangularPoint(latitude, longitude, width, height) {
    if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90
            || !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
        throw new TypeError("Coordinates must be finite latitude and longitude values in range")
    }
    if (!Number.isFinite(width) || width <= 0 || !Number.isFinite(height) || height <= 0) {
        throw new TypeError("Map dimensions must be finite positive values")
    }

    return {
        x: width * (longitude + 180) / 360,
        y: height * (90 - latitude) / 180
    }
}
