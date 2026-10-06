.pragma library

function normalizeDegrees(degrees) {
    return ((degrees + 180) % 360 + 360) % 360 - 180
}

function subsolarPoint(date) {
    if (!(date instanceof Date) || !Number.isFinite(date.getTime())) {
        throw new TypeError("subsolarPoint expects a valid Date")
    }

    const julianDay = date.getTime() / 86400000 + 2440587.5
    const century = (julianDay - 2451545.0) / 36525
    const meanLongitude = normalizeDegrees(
                280.46646 + century * (36000.76983 + century * 0.0003032))
    const meanAnomaly = normalizeDegrees(
                357.52911 + century * (35999.05029 - 0.0001537 * century))
    const anomalyRadians = meanAnomaly * Math.PI / 180
    const equationOfCenter = Math.sin(anomalyRadians)
            * (1.914602 - century * (0.004817 + 0.000014 * century))
            + Math.sin(2 * anomalyRadians) * (0.019993 - 0.000101 * century)
            + Math.sin(3 * anomalyRadians) * 0.000289
    const trueLongitude = meanLongitude + equationOfCenter
    const omega = (125.04 - 1934.136 * century) * Math.PI / 180
    const apparentLongitude = trueLongitude - 0.00569
            - 0.00478 * Math.sin(omega)

    const obliquitySeconds = 21.448 - century
            * (46.815 + century * (0.00059 - century * 0.001813))
    const meanObliquity = 23 + (26 + obliquitySeconds / 60) / 60
    const obliquity = meanObliquity + 0.00256 * Math.cos(omega)
    const obliquityRadians = obliquity * Math.PI / 180
    const apparentLongitudeRadians = apparentLongitude * Math.PI / 180
    const latitude = Math.asin(Math.sin(obliquityRadians)
                               * Math.sin(apparentLongitudeRadians))
            * 180 / Math.PI

    const y = Math.tan(obliquityRadians / 2) ** 2
    const eccentricity = 0.016708634 - century
            * (0.000042037 + 0.0000001267 * century)
    const equationOfTimeRadians = y * Math.sin(2 * meanLongitude * Math.PI / 180)
            - 2 * eccentricity * Math.sin(anomalyRadians)
            + 4 * eccentricity * y * Math.sin(anomalyRadians)
            * Math.cos(2 * meanLongitude * Math.PI / 180)
            - 0.5 * y * y * Math.sin(4 * meanLongitude * Math.PI / 180)
            - 1.25 * eccentricity * eccentricity * Math.sin(2 * anomalyRadians)
    const equationOfTimeMinutes = equationOfTimeRadians * 180 / Math.PI * 4
    const utcMinutes = date.getUTCHours() * 60 + date.getUTCMinutes()
            + date.getUTCSeconds() / 60 + date.getUTCMilliseconds() / 60000
    const longitude = normalizeDegrees(180 - utcMinutes / 4
                                       - equationOfTimeMinutes / 4)

    return {
        latitude: latitude,
        longitude: longitude
    }
}
