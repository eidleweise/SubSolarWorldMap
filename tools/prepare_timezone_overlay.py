#!/usr/bin/env python3
"""Build the bundled, display-scale timezone overlay from source GeoJSON."""

import argparse
import json
import shutil
import subprocess
import tempfile
from pathlib import Path


MAPSHAPER_VERSION = "0.7.101"
LABEL_LATITUDES = {
    "top": 75.0,
    "middle": 0.0,
    "bottom": -75.0,
}


def load_json(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def find_mapshaper():
    executable = shutil.which("mapshaper")
    if executable:
        return [executable]
    npx = shutil.which("npx")
    if npx:
        return [npx, "--yes", f"mapshaper@{MAPSHAPER_VERSION}"]
    raise RuntimeError("Install mapshaper or Node.js/npm to run npx.")


def polygon_list(geometry):
    if geometry["type"] == "Polygon":
        return [geometry["coordinates"]]
    if geometry["type"] == "MultiPolygon":
        return geometry["coordinates"]
    return []


def scanline_intersections(rings, latitude):
    intersections = []
    for ring in rings:
        for first, second in zip(ring, ring[1:]):
            lon1, lat1 = first[:2]
            lon2, lat2 = second[:2]
            if (lat1 <= latitude < lat2) or (lat2 <= latitude < lat1):
                ratio = (latitude - lat1) / (lat2 - lat1)
                intersections.append(lon1 + ratio * (lon2 - lon1))
    intersections.sort()
    return intersections


def label_anchors(features, latitude):
    anchors = []
    for feature in features:
        properties = feature.get("properties") or {}
        tzid = properties.get("tzid")
        if not isinstance(tzid, str) or not tzid:
            continue
        geometry = feature.get("geometry") or {}
        for polygon in polygon_list(geometry):
            intersections = scanline_intersections(polygon, latitude)
            for index in range(0, len(intersections) - 1, 2):
                west, east = intersections[index:index + 2]
                if east - west >= 4.0:
                    anchors.append({
                        "tzid": tzid,
                        "longitude": round((west + east) / 2.0, 5),
                        "latitude": latitude,
                    })
    return anchors


def line_paths(geometry):
    geometry_type = geometry.get("type")
    coordinates = geometry.get("coordinates", [])
    if geometry_type == "LineString":
        return [coordinates]
    if geometry_type == "MultiLineString":
        return coordinates
    raise ValueError(f"Unexpected boundary geometry: {geometry_type}")


def international_date_line(source):
    matches = [
        feature for feature in source.get("features", [])
        if (feature.get("properties") or {}).get("name") == "International Date Line"
    ]
    if len(matches) != 1:
        raise ValueError(
            "Expected one Natural Earth feature named 'International Date Line'; "
            f"found {len(matches)}"
        )
    return line_paths(matches[0]["geometry"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("timezones", type=Path, help="Timezone Boundary Builder GeoJSON input")
    parser.add_argument("natural_earth", type=Path, help="Natural Earth geographic-lines GeoJSON")
    parser.add_argument("--timezone-version", required=True, help="Timezone Boundary Builder release tag")
    parser.add_argument("--natural-earth-version", required=True, help="Natural Earth release tag")
    parser.add_argument("--output", type=Path, required=True, help="Generated QML JavaScript data file")
    args = parser.parse_args()

    timezone_source = load_json(args.timezones)
    if timezone_source.get("type") != "FeatureCollection":
        raise ValueError("Timezone input must be a GeoJSON FeatureCollection")
    timezone_features = timezone_source.get("features")
    if not isinstance(timezone_features, list) or not timezone_features:
        raise ValueError("Timezone input contains no features")

    mapshaper = find_mapshaper()
    with tempfile.TemporaryDirectory(prefix="timezone-overlay-") as temp_dir:
        simplified_path = Path(temp_dir) / "boundaries.geojson"
        command = mapshaper + [
            str(args.timezones),
            "-innerlines",
            "where=A.tzid != B.tzid",
            "-simplify",
            "dp",
            "interval=10000m",
            "-o",
            "format=geojson",
            str(simplified_path),
        ]
        subprocess.run(command, check=True)
        simplified = load_json(simplified_path)
        geometries = simplified.get("geometries")
        if not isinstance(geometries, list):
            raise ValueError("Mapshaper output did not contain a GeoJSON GeometryCollection")
        boundaries = []
        for geometry in geometries:
            for path in line_paths(geometry):
                if len(path) >= 2:
                    boundaries.append([[round(point[0], 5), round(point[1], 5)]
                                       for point in path])

    natural_earth = load_json(args.natural_earth)
    date_line = [
        [[round(point[0], 5), round(point[1], 5)] for point in path]
        for path in international_date_line(natural_earth)
        if len(path) >= 2
    ]
    if not boundaries or not date_line:
        raise ValueError("Generated timezone boundaries or IDL path are empty")

    overlay = {
        "source": {
            "timezoneBoundaryBuilder": args.timezone_version,
            "naturalEarth": args.natural_earth_version,
        },
        "boundaries": boundaries,
        "dateLine": date_line,
        "labels": {
            row: [
                anchor
                for feature in timezone_features
                for anchor in label_anchors([feature], latitude)
            ]
            for row, latitude in LABEL_LATITUDES.items()
        },
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        ".pragma library\nvar overlayData = "
        + json.dumps(overlay, separators=(",", ":"), ensure_ascii=True)
        + "\n",
        encoding="utf-8",
    )
    print(
        f"Wrote {args.output}: {len(boundaries)} boundaries, "
        f"{sum(map(len, boundaries))} vertices, {len(date_line)} IDL paths"
    )


if __name__ == "__main__":
    main()
