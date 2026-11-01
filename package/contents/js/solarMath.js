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

function sublunarPoint(date) {
    if (!(date instanceof Date) || !Number.isFinite(date.getTime())) {
        throw new TypeError("sublunarPoint expects a valid Date")
    }

    const julianDay = date.getTime() / 86400000 + 2440587.5
    const daysSinceEpoch = julianDay - 2451543.5
    const radians = Math.PI / 180
    const node = normalizeDegrees(125.1228 - 0.0529538083 * daysSinceEpoch)
    const inclination = 5.1454
    const periapsis = normalizeDegrees(318.0634 + 0.1643573223 * daysSinceEpoch)
    const eccentricity = 0.0549
    const meanAnomaly = normalizeDegrees(115.3654 + 13.0649929509 * daysSinceEpoch)
    const eccentricAnomaly = meanAnomaly + eccentricity / radians
            * Math.sin(meanAnomaly * radians)
            * (1 + eccentricity * Math.cos(meanAnomaly * radians))
    const x = Math.cos(eccentricAnomaly * radians) - eccentricity
    const y = Math.sqrt(1 - eccentricity * eccentricity)
            * Math.sin(eccentricAnomaly * radians)
    const trueAnomaly = Math.atan2(y, x) / radians
    const orbitalLongitude = trueAnomaly + periapsis
    const longitude = Math.atan2(
        Math.sin(node * radians) * Math.cos(orbitalLongitude * radians)
                + Math.cos(node * radians) * Math.sin(orbitalLongitude * radians)
                * Math.cos(inclination * radians),
        Math.cos(node * radians) * Math.cos(orbitalLongitude * radians)
                - Math.sin(node * radians) * Math.sin(orbitalLongitude * radians)
                * Math.cos(inclination * radians)) / radians
    const latitude = Math.asin(
        Math.sin(orbitalLongitude * radians) * Math.sin(inclination * radians))
            / radians

    const sunMeanAnomaly = normalizeDegrees(
        356.0470 + 0.9856002585 * daysSinceEpoch)
    const sunMeanLongitude = normalizeDegrees(282.9404
                                               + 4.70935e-5 * daysSinceEpoch
                                               + sunMeanAnomaly)
    const meanElongation = normalizeDegrees(node + periapsis + meanAnomaly
                                             - sunMeanLongitude)
    const argumentOfLatitude = normalizeDegrees(node + periapsis + meanAnomaly - node)
    const lunarLongitude = normalizeDegrees(longitude)
    const longitudeCorrection = -1.274 * Math.sin((meanAnomaly - 2 * meanElongation) * radians)
            + 0.658 * Math.sin(2 * meanElongation * radians)
            - 0.186 * Math.sin(sunMeanAnomaly * radians)
            - 0.059 * Math.sin((2 * meanAnomaly - 2 * meanElongation) * radians)
            - 0.057 * Math.sin((meanAnomaly - 2 * meanElongation + sunMeanAnomaly) * radians)
            + 0.053 * Math.sin((meanAnomaly + 2 * meanElongation) * radians)
            + 0.046 * Math.sin((2 * meanElongation - sunMeanAnomaly) * radians)
            + 0.041 * Math.sin((meanAnomaly - sunMeanAnomaly) * radians)
            - 0.035 * Math.sin(meanElongation * radians)
            - 0.031 * Math.sin((meanAnomaly + sunMeanAnomaly) * radians)
            - 0.015 * Math.sin((2 * argumentOfLatitude - 2 * meanElongation) * radians)
            + 0.011 * Math.sin((meanAnomaly - 4 * meanElongation) * radians)
    const latitudeCorrection = -0.173 * Math.sin((argumentOfLatitude - 2 * meanElongation) * radians)
            - 0.055 * Math.sin((meanAnomaly - argumentOfLatitude - 2 * meanElongation) * radians)
            - 0.046 * Math.sin((meanAnomaly + argumentOfLatitude - 2 * meanElongation) * radians)
            + 0.033 * Math.sin((argumentOfLatitude + 2 * meanElongation) * radians)
            + 0.017 * Math.sin((2 * meanAnomaly + argumentOfLatitude) * radians)
    const correctedLongitude = (lunarLongitude + longitudeCorrection) * radians
    const correctedLatitude = (latitude + latitudeCorrection) * radians
    const obliquity = (23.4393 - 3.563e-7 * daysSinceEpoch) * radians
    const rightAscension = Math.atan2(
        Math.sin(correctedLongitude) * Math.cos(obliquity)
                - Math.tan(correctedLatitude) * Math.sin(obliquity),
        Math.cos(correctedLongitude)) / radians
    const declination = Math.asin(
        Math.sin(correctedLatitude) * Math.cos(obliquity)
                + Math.cos(correctedLatitude) * Math.sin(obliquity)
                * Math.sin(correctedLongitude)) / radians
    const centuries = (julianDay - 2451545.0) / 36525
    const siderealDegrees = normalizeDegrees(
        280.46061837 + 360.98564736629 * (julianDay - 2451545.0)
        + 0.000387933 * centuries * centuries
        - centuries * centuries * centuries / 38710000)

    return {
        latitude: declination,
        longitude: normalizeDegrees(rightAscension - siderealDegrees)
    }
}

function lunarPhase(date) {
    if (!(date instanceof Date) || !Number.isFinite(date.getTime())) {
        throw new TypeError("lunarPhase expects a valid Date")
    }

    const julianDay = date.getTime() / 86400000 + 2440587.5
    const phaseAge = ((julianDay - 2451550.1) % 29.530588853 + 29.530588853)
            % 29.530588853
    const phaseAngle = phaseAge / 29.530588853 * 360
    const illumination = (1 - Math.cos(phaseAngle * Math.PI / 180)) / 2
    const phaseIndex = Math.floor((phaseAngle + 22.5) / 45) % 8
    const phases = [
        "New Moon",
        "Waxing Crescent",
        "First Quarter",
        "Waxing Gibbous",
        "Full Moon",
        "Waning Gibbous",
        "Last Quarter",
        "Waning Crescent"
    ]

    return {
        name: phases[phaseIndex],
        illumination: illumination,
        waxing: phaseAngle < 180,
        angle: phaseAngle
    }
}

function solarAltitudeCosine(latitude, longitude, solarPosition) {
    if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90
            || !Number.isFinite(longitude) || longitude < -180 || longitude > 180
            || !solarPosition
            || !Number.isFinite(solarPosition.latitude)
            || solarPosition.latitude < -90 || solarPosition.latitude > 90
            || !Number.isFinite(solarPosition.longitude)
            || solarPosition.longitude < -180 || solarPosition.longitude > 180) {
        throw new TypeError("solarAltitudeCosine expects valid geographic coordinates")
    }

    const radians = Math.PI / 180
    const locationLatitude = latitude * radians
    const locationLongitude = longitude * radians
    const sunLatitude = solarPosition.latitude * radians
    const sunLongitude = solarPosition.longitude * radians
    return Math.sin(locationLatitude) * Math.sin(sunLatitude)
            + Math.cos(locationLatitude) * Math.cos(sunLatitude)
            * Math.cos(locationLongitude - sunLongitude)
}
