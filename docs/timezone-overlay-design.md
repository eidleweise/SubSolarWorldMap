# Time Zone Overlay: Design

## Status

Initial implementation is complete; the build/tests pass and desktop visual
validation is confirmed. The product direction is a decorative, secondary
time-zone guide, not a political or historical atlas.

## Goal

Add a configurable map layer showing time zone boundaries across land and
oceans, with readable labels and a visually emphasized International Date
Line (IDL). The layer should help users understand the map without obscuring
the day/night imagery or the existing location pins.

## Data and rendering

- Use the "same since now, with oceans" GeoJSON release from
  [Timezone Boundary Builder](https://github.com/evansiroky/timezone-boundary-builder)
  as the preferred candidate source. It includes ocean regions and merges
  regions whose timekeeping agrees now, which suits the decorative purpose
  better than showing every political or historical distinction. The bundled
  source is release 2026f, `timezones-with-oceans-now.geojson.zip`.
- Credit Timezone Boundary Builder and link to its project in the README and
  the widget's About information. The derived boundary data is ODbL 1.0 and
  based on OpenStreetMap; include the OSM attribution. The IDL uses Natural
  Earth's public-domain 10m geographic-lines data from release 5.1.2.
- Preprocess the selected boundary geometry for the widget's display scale
  using `tools/prepare_timezone_overlay.py` and Mapshaper 0.7.101. The script
  extracts shared boundaries between distinct timezone features and simplifies
  them with a 10 km Douglas-Peucker interval. Regeneration requires Python 3,
  Node.js/npm, the source GeoJSON, and the Natural Earth GeoJSON; the widget
  requires no network access or Python runtime.
- Render the geometry as a vector overlay in the existing equirectangular map
  projection. Place boundaries and labels above the day/night-rendered map but
  below the Sun marker and Home/city pins.
- Extract shared borders between different timekeeping regions once. Draw
  time-zone boundaries only; do not trace coastlines or polygon outlines just
  because they appear in the source geometry. Dataset selection alone does not
  deduplicate coincident polygon edges, so preprocessing must identify and
  deduplicate the shared region borders.
- Keep ocean zones in the same layer as land zones.

## Configuration

The dedicated **Time Zones** settings tab provides:

- Show/hide time zone boundaries.
- Boundary opacity.
- Separate day-side and night-side boundary colors. A border crossing the
  terminator must change style along its length, using the same solar geometry
  and twilight transition as the day/night map.
- Show/hide labels and independently enable label rows at the top, middle,
  and bottom of the map. Place the rows with a small inset from the map edges.
- Choose an offset label format: compact (`+1`), offset with UTC (`+1:00 UTC`),
  or zero-padded offset (`+01:00`). Default to `+1:00 UTC`.
- Label font family using the existing system-font selection/search approach,
  plus a time-zone-specific font size.
- Emphasize the International Date Line (IDL), with a bolder line treatment
  than ordinary boundaries and a distinct "International Date Line" label.

The boundary layer is secondary to the Sun and day/night map: use subdued lines,
no tinted zone fills, and avoid dense labels. Labels for small or narrow regions
will not always fit; the renderer should avoid overlapping labels and may omit
labels where there is insufficient room.

By default, show the subtle boundary layer and middle label row. Keep the top
and bottom label rows off until enabled by the user.

## Labels

Use current UTC offsets as the primary labels. Users can choose between compact
(`+1`), offset with UTC (`+1:00 UTC`), and zero-padded offset (`+01:00`)
formats; default to `+1:00 UTC`. Fractional offsets must retain their minutes
in every format (for example, `+5:30` or `+5:30 UTC`). Offsets change with
daylight-saving rules, so they must reflect the current instant and refresh
when an offset changes. The QML JavaScript engine does not provide `Intl`;
obtain offsets through Qt timezone support in C++ rather than assuming
JavaScript can format arbitrary IANA zones.

The top/middle/bottom options are independently enabled latitude bands with
small padding from the top and bottom edges. Place labels in the zone present at
each candidate map position, avoid collisions, and suppress labels where there
is insufficient room. Repeated offset labels across a band are acceptable
where they help orient the viewer; do not force a label into every narrow
region.

## International Date Line

Show the IDL users recognize; do not infer it from changes in adjacent zone
offsets or assume it is fully represented by time-zone boundaries. Use a
separately sourced or curated geographic path for the IDL, overlaid with the
same projection and styling system as the zone borders. Record its provenance
and validate its bends around islands against a reference map. This allows the
IDL to remain recognizable even where the timezone dataset's zone boundaries
do not follow it.

## Remaining design decisions

1. Revisit default colors, opacity, widths, and IDL styling after visual review.
2. Revisit the dataset release and simplification level if visual review shows
   missing or overly simplified boundaries.

## Implementation and validation criteria

- The Time Zones settings tab controls layer visibility and the agreed visual
  options, with configuration persisted across restarts.
- Ocean and land zone boundaries render in the correct positions on the
  existing equirectangular map.
- Day-side and night-side styling remains distinguishable across the moving
  terminator.
- The IDL follows its separately sourced/curated path and is visibly bolder
  than ordinary zone borders.
- Labels follow the selected offset format, font, size, and enabled placement rows;
  crowded and narrow regions do not produce excessive overlap.
- The overlay remains below the Sun and location pins and behaves correctly
  when the widget is resized.
- Bundled data has documented provenance, version, attribution, and license.
