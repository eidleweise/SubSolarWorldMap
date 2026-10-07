# SubSolar World Map: Technical Code Document

This document captures the engineering intent for the project described in `README.md` and `HANDOVER.md`. It is intended as a design baseline for implementation, review, and future backlog planning.

## 1. Product Overview

SubSolar World Map is a KDE Plasma 6 plasmoid that renders a live equirectangular world map showing day, night, and twilight regions based on the current solar position. The initial release is intentionally a flat, map-style presentation rather than a 3D globe. The widget is aesthetically inspired by historical world clocks, but it also carries practical value as a global time and daylight awareness tool.

The core visual concept is a flat world map with:

- a daytime texture,
- a night-time texture,
- a continuously updated solar terminator line,
- user-configurable timezone/city markers.

The project combines Qt Quick/QML for the UI, JavaScript for the astronomical logic, and GLSL shader rendering for smooth visual blending.

## 2. Goals

- Provide a native-looking KDE Plasma widget that feels at home in a desktop panel or desktop surface.
- Display a real-time daylight/night map using a subsolar-point model.
- Render the terminator smoothly with a hardware-accelerated shader.
- Support configurable markers for cities and timezones.
- Keep the visual and computational model simple enough to remain maintainable and easy to debug.

## 3. Non-Goals

- Not a general-purpose geographic map editor.
- Not a full astronomy engine or ephemeris service.
- Not a cross-platform desktop app outside KDE Plasma.
- Not intended to replace a full timezone library for offline or enterprise-scale date calculations.

## 4. Target Platform and Runtime

- Platform: KDE Plasma 6 / Linux
- UI framework: Qt Quick + Kirigami
- Home location: Qt Positioning with the GeoClue provider
- Catalog runtime: Qt Network, Qt Concurrent, and zlib
- Build system: CMake
- Execution environment: Plasma widget loaded in `plasmoidviewer` or installed as a plasmoid

## 5. Functional Requirements

### 5.1 Live Solar Terminator

The app shall compute the current subsolar point from the current UTC time and update it continuously.

The terminator shall be derived from the equation:

sin(lat) * sin(delta) + cos(lat) * cos(delta) * cos(lon - lambda_0) = 0

where:

- lat = latitude
- lon = longitude
- delta = solar declination
- lambda_0 = subsolar longitude

A practical implementation should treat the terminator as a visual mask and render the day/night transition as a shader-driven mix between the daytime and nighttime textures.

### 5.2 Day/Night Rendering

The app shall:

- render a base day map,
- overlay a night map,
- blend them along the terminator,
- smooth the transition using a shader or fragment pipeline,
- update the blend based on current solar conditions.

### 5.3 Timezone / City Markers

The app shall support marker objects positioned on the map to represent cities or timezone reference points.

The widget shall be resizable in a way that preserves the equirectangular layout and keeps the world map readable across panel and desktop sizes.

Only a selected subset of cities may be displayed at any time, so the project should support a configured list of active markers rather than rendering every possible city by default.

Each marker shall carry:

- label,
- latitude/longitude,
- timezone identifier or offset,
- optional local time display,
- optional style metadata,
- enabled/visible state for filtering.

The cached catalog is read, validated, deduplicated, and alphabetized on a
QtConcurrent worker so a large catalog does not block the Plasma UI thread.
The manager publishes both the original records (for nearest-city lookup) and
the prepared unique list (for settings and selectable pins); QML reuses the
prepared list rather than sorting and deduplicating it during each search.

### 5.4 Configuration

The plasmoid exposes a Date & Time page through Plasma's native applet
settings. It stores the clock visibility and date and time format choices in
`Plasmoid.configuration`; date formats include short, long, and ISO, while time formats offer 12- or
24-hour clocks with optional seconds. Users can hide the timezone, show its
abbreviation or full name, and select the clock font family and size. Future
configuration work includes adding custom locations and extending the city
catalog.

Location pins show the same date, time, and timezone line in their tooltips.
The Plasma/Qt QML JavaScript engine does not provide the ECMAScript `Intl`
object, so these clock strings are built by Qt-based formatters rather than in
pure JavaScript. The on-map clock badge, the Home pin, and `clockFormat.js`
share a single system-local formatter (`formatSystemLocalClock`) that lives in
`main.qml`; sharing one formatter keeps the badge and the system-local tooltips
identical and means `clockFormat.js` never depends on `Intl` for the common
case.

City pins instead display the pin's OWN current local wall-clock time. Because
`Intl` is unavailable, the IANA timezone conversion is performed in C++ by
`CityCatalogManager::formatZonedClock` (`QTimeZone`/`QDateTime`/`QLocale`),
exposed to QML as a `Q_INVOKABLE` and injected into `MapView.qml` through a
`cityClock` callback that parallels the system-local one. The returned string
reproduces the badge's format contract exactly — the same date, time, and
timezone format choices and the `  ·  ` separator — differing only in the zone
used. The Home pin and the on-map clock badge remain system-local and
unchanged. When a city record has an empty or invalid IANA id, the C++
formatter returns an empty string and the tooltip falls back to the existing
system-local path, so a tooltip never shows a blank string or "Invalid Date".

A correctness trap drove this design: a raw `QDateTime` handed to QML is
re-formatted by `Qt.formatTime`/`Qt.formatDateTime` in the system-local zone,
which silently undoes the timezone conversion. To avoid this, the full clock
line is assembled in C++ and returned as a finished `QString`; QML inserts it
verbatim rather than re-formatting it. The fallback path's `formatLocationClock`
is also written so it can never throw out of the tooltip binding.

The applet requests a fresh Qt Positioning/GeoClue fix at every startup and
continues periodic updates while running. Users can instead choose a city
from the local catalog or enter coordinates; a manual location takes priority
over automatic location. Until a valid fix arrives, stale saved coordinates
are not treated as current. Other pins are selected from the locally cached
city catalog and persisted as city IDs. The nearest city shown for automatic
coordinates is an approximation, not reverse geocoding. Precise coordinates
are not sent to a geocoding service.

The Developer settings page controls the deployment timestamp and opens the
diagnostic log or its containing directory. `CityCatalogManager` writes
timestamped, categorized events to a per-user log, rotates it at about 1 MiB,
and keeps one previous copy. The settings page can also launch `journalctl` in
Konsole (when installed) or the configured terminal to inspect the last 15
minutes of Plasma Shell logs and follow new entries. Konsole is preferred so
host `journalctl` is available even when the configured terminal is sandboxed.

## 6. Proposed Architecture

### 6.1 Layered Structure

The project naturally breaks into a few clear layers:

1. UI Layer
   - Root widget container
   - Layout and viewport management
   - Marker rendering
   - User controls and settings panel

2. Simulation / Logic Layer
   - Time update loop
   - Subsolar-point calculation
   - Timezone conversion logic
   - Marker coordinate normalization

3. Rendering Layer
   - Day map and night map image layers
   - ShaderEffect-driven blend
   - Background and visibility controls

4. Data Layer
   - Marker definitions
   - Timezone metadata
   - Optional persisted user settings

### 6.2 Recommended File Structure

```text
SubSolar-World-Map/
├── CMakeLists.txt
├── metadata.json
├── README.md
├── HANDOVER.md
├── package/
│   └── contents/
│       ├── ui/
│       │   ├── main.qml
│       │   ├── MapView.qml
│       │   ├── Marker.qml
│       │   └── Settings.qml
│       ├── js/
│       │   ├── solarMath.js
│       │   ├── timezone.js
│       │   ├── markerModel.js
│       │   └── cityCatalog.js
│       ├── assets/
│       │   ├── day/
│       │   ├── night/
│       │   └── original/
│       └── config/
│           └── defaultMarkers.json
└── docs/
    ├── technical-code-document.md
    └── project-stories.md
```

For the first implementation, the map is treated as a flat equirectangular projection. A 3D globe render is not required for the initial milestone and should be treated as a later enhancement rather than a baseline requirement.

## 7. Core Components

### 7.1 `main.qml`

This is the root plasmoid view. It is responsible for:

- creating the widget shell,
- attaching the world map view,
- starting the timer or update loop,
- wiring the model data to the view.

### 7.2 `MapView.qml`

This component owns the visual map surface. Responsibilities include:

- loading the daytime and nighttime textures,
- setting shader uniforms,
- updating the terminator or brightness mask,
- placing markers over the map,
- scaling/resizing the view for screen and panel density.

### 7.3 `Marker.qml`

This component represents a city or timezone reference anchor. It should be lightweight and reusable.

A marker should support:

- x/y position computed from latitude/longitude,
- label rendering, optional glow,
- day/night state semantics,
- hover/click actions if made interactive.

### 7.4 `solarMath.js`

This file should encapsulate the astronomical calculations required to determine daylight conditions.

Responsibilities:

- compute Julian day from current time,
- compute solar declination,
- compute equation of time if needed,
- compute subsolar longitude and latitude,
- expose functions usable from QML.

## 8. Rendering Model

### 8.1 Shader Strategy

The day and night textures should be mixed using a fragment shader working over normalized world coordinates. The most direct approach is to:

- map latitude and longitude to UV coordinates,
- compute the sign of the daylight condition for each fragment,
- blend between the day and night textures according to proximity to the terminator.

This approach avoids expensive world geometry and is well suited to Qt Quick rendering.

### 8.2 Visual Considerations

The shader should support:

- soft edge blending at the terminator,
- configurable twilight band width,
- optional night-light glow intensity,
- smooth performance even at high DPI or 4K presentation sizes.

The map view uses a Qt Quick `ShaderEffect` to sample the day and night
textures and blend them from the solar-altitude equation. The GLSL fragment
shader is precompiled to Qt's portable `.qsb` format for the runtime; its
source is kept next to the compiled asset under `contents/shaders/`. This
keeps the terminator smooth and avoids per-pixel JavaScript work.

The shader converts normalized texture coordinates to equirectangular
latitude/longitude, evaluates the cosine of the solar altitude, and uses
`smoothstep` to blend the textures across a narrow twilight band. Both map
images are supplied through live `ShaderEffectSource` items so they are
available as shader samplers. The night texture is blended as an opaque image;
the implementation does not depend on an alpha mask.

The day and night source images must share the same equirectangular 2:1 extent:
longitude runs from -180 to +180 degrees across the width and latitude from
+90 to -90 degrees down the height. Do not center-crop them to 16:9, since
that removes polar coverage and shifts the texture coordinates relative to the
solar mask. The supplied 2160x1080 and 3840x1920 variants preserve the full
extent. `MapView.qml` keeps its displayed surface at 2:1 and selects the
larger texture pair when physical width exceeds 2160 pixels.

The applet uses Plasma's native edit-mode controls for moving and resizing;
do not add a map-level drag handler that would intercept the desktop's
interaction. The full representation has a 520x300 preferred size and a
320x200 minimum, with a compact date/time header above the 2:1 map.

### 8.3 Implementation Lessons

- A Plasma applet's root should be a `PlasmoidItem` with a `fullRepresentation`.
  Set a useful implicit and minimum size on the representation so the map does
  not open as a tiny desktop applet.
- Plasma 6's widget explorer treats packages without
  `X-Plasma-API-Minimum-Version` as unsupported legacy widgets. Declare
  `"X-Plasma-API-Minimum-Version": "6.0"` at the top level of `metadata.json`
  and upgrade the installed package before adding it from the desktop. Check
  the installed `metadata.json` after upgrade: upgrading from an older staging
  directory can silently restore stale metadata from before the source fix.
- `plasmoidviewer --applet` looks up installed applets by plugin ID; passing a
  source directory is not a reliable live-preview workflow. Build and stage
  install the package, upgrade it with `kpackagetool6`, then launch
  `plasmoidviewer --applet org.eidleweise.subsolarworldmap`.
- Rebuild the `.qsb` file whenever the GLSL source changes. CMake runs `qsb`
  when available and the generated shader is included in the staged package;
  compare the installed shader with the build output when diagnosing stale
  visuals.
- A shader can report `Compiled` and still render incorrectly. The uniform
  block must match Qt Quick's expected layout: `mat4 qt_Matrix`, then
  `float qt_Opacity`, followed by custom uniforms in the same order as the
  shader declarations. Omitting the matrix shifts the following values.
- Verify shader inputs separately from the final composition: a solid-color
  day/night mask confirms solar math, and rendering one sampled texture at a
  time confirms sampler wiring. This exposed the uniform layout issue before
  restoring the real texture blend.
- Container graphics warnings and plasmoidviewer containment errors can be
  independent of applet QML. Check the widget's own QML and shader status
  separately rather than treating every viewer warning as a rendering error.
- Preserve the source maps' full 2:1 projection when resizing assets. The
  previous `imageSize.sh` used ImageMagick's `^` resize plus center crop to
  16:9; that discarded polar rows, so the displayed map no longer matched the
  shader's latitude coordinates. Fit to the target bounds without cropping.

## 9. Time and Astronomical Logic

### 9.1 Time Source

The app should use the system clock and convert to UTC or local time as needed. It should update at a regular interval and avoid unnecessary recomputation.

### 9.2 Solar Calculations

The astronomical calculation lives in `package/contents/js/solarMath.js` and
is kept separate from the view code. It derives the Julian day from the
timestamp, computes solar declination and equation of time, then returns the
subsolar latitude and longitude. JavaScript `Date` timestamps identify an
absolute instant; UTC accessors make the result independent of the system's
local timezone. Invalid dates fail explicitly.

The plasmoid computes an initial position at startup and refreshes it every
30 seconds. The shader receives the current subsolar coordinates as uniforms,
so the terminator tracks solar motion without regenerating textures. The map
also places a small sun marker at the same subsolar latitude/longitude using
the map's 2:1 equirectangular coordinates. A header displays the system-local
date and time with configurable date, time, and timezone formats, and refreshes
with the solar position.
When either seconds-enabled time format is selected, a separate one-second
timer refreshes only the displayed clock; solar calculations remain on the
30-second timer.

The header clock, like the Home pin, is always system-local. Per-city pin
tooltips are the exception: they show each city's own wall-clock time, computed
from its IANA timezone id in C++ via `CityCatalogManager::formatZonedClock`
(`QTimeZone`/`QDateTime`/`QLocale`) because the QML JS engine lacks `Intl`
(see section 5.4). The conversion is deliberately kept in C++ and returned as a
finished string: handing a raw `QDateTime` back to QML would let
`Qt.formatTime`/`Qt.formatDateTime` re-interpret it in the system-local zone and
undo the conversion. An empty or invalid IANA id falls back to the system-local
path, so a tooltip is never blank and never reads "Invalid Date".

Run the deterministic math tests with `node --test tests/solarMath.test.js`, or
use `ctest --test-dir build --output-on-failure` after configuring CMake with
Node.js available. Tests cover equinox and solstice reference positions,
westward longitude movement, equivalent timestamps with different timezone
notations, and rejection of invalid inputs.

### 9.3 Data Normalization

Because map textures are equirectangular, coordinates should normalize to the standard ranges:

- latitude: -90 to +90
- longitude: -180 to +180

A marker's world position can be converted to a normalized 0..1 coordinate pair for placement in QML.

## 10. Data Model

The application should keep model data simple and serializable.

The canonical source of truth for each city should be its geographic position in latitude/longitude, not its rendered pixel position. This keeps the list stable across different widget sizes and future map variants.

### Example marker object

```js
{
  id: "london",
  name: "London",
  latitude: 51.5074,
  longitude: -0.1278,
  timezone: "Europe/London",
  enabled: true,
  color: "#ffffff"
}
```

This model is friendly to JSON, to user settings persistence, and to future UI editing.

### 10.1 Converting latitude/longitude to map position

For an equirectangular projection, the geographic coordinates can be converted into a normalized position in map space.

```js
const x = (longitude + 180.0) / 360.0;
const y = (90.0 - latitude) / 180.0;
```

These values are in the range 0..1, where:

- x = 0 is the left edge of the map
- x = 1 is the right edge of the map
- y = 0 is the top edge of the map
- y = 1 is the bottom edge of the map

This can then be mapped to the current widget size:

```js
const pixelX = x * mapWidth;
const pixelY = y * mapHeight;
```

This is the preferred approach because it keeps the city list independent from the widget size. The pin position is derived from the current map dimensions at render time, so when the widget is resized the markers remain correctly aligned to the map.

## 11. Configuration and Persistence

The project should ideally support a lightweight configuration file with a default marker list and optional user overrides.

Recommended approach:

- a city catalog used to search and select locations,
- selected city IDs and user-added locations stored in a local config path or Plasma config object,
- simple JSON schema for readability and maintainability.

### 11.1 External City Catalog

The catalog manager downloads the latest versioned `csv-cities.csv.gz` release
asset of the [Countries States Cities Database](https://github.com/dr5hn/countries-states-cities-database)
on first use; it does not use the managed API or bundle city data with the
plasmoid. It keeps a per-user cache under the XDG data directory. On startup,
the cached copy loads immediately and the manager checks GitHub release
metadata, rate-limited to once every six hours. A newer archive is downloaded
in the background, SHA-256 verified using the release asset digest, gzip
decompressed and parsed off the UI thread. Only valid records with population
of at least 10,000 are retained. A `QSaveFile` atomically replaces the cache
only after parsing succeeds; failed network requests or invalid data leave the
last good cache usable. On first use, the city list remains unavailable until
the initial download completes.

Only selected city IDs are rendered as pins. Selection is stored separately
in Plasma applet configuration, so catalog updates do not reset it. Catalog
filtering happens in the settings page and the list view virtualizes rows.

Only selected cities are rendered as map pins. Their latitude/longitude remains the positioning source of truth, with normalized x/y derived from the current map dimensions. Convert upstream coordinate strings to numbers and validate coordinate ranges before use.

The source database is licensed under ODbL 1.0 and requires attribution. The
downloaded, filtered cache is a transformed database; review ODbL share-alike
obligations before redistributing it. Provide attribution and retain relevant
license information.

## 12. Quality and Performance

### 12.1 Performance Expectations

The widget must update smoothly in a live desktop session without excessive CPU use.

Target characteristics:

- low-latency refresh for the current solar state,
- no heavy work on every frame beyond UI refresh throttling,
- shader-based blending instead of complex polygon generation.

### 12.2 Reliability

Important reliability concerns:

- safe handling of timezone offsets,
- avoiding invalid coordinate values,
- ensuring shader uniforms are set correctly when resizing,
- testing fallback behavior when config files are missing,
- keeping the widget usable offline and when an upstream catalog update fails,
- avoiding expensive city-catalog parsing on the UI thread.

## 13. Risks and Constraints

- Plasma compatibility changes across versions may require small adaptation work.
- High-resolution textures may be memory intensive if not managed carefully.
- Some visual accuracy depends on the matching of map projection and coordinate conventions.
- The project is a UI-heavy widget, so design polish may matter as much as implementation quality.
- A remote city catalog introduces network availability, upstream format/version, and ODbL attribution/share-alike considerations.

## 14. Development and Packaging Environment

The widget links a native Qt plugin, so its binaries must match the ABI of the
Plasma host they run on. Two helper scripts use a Fedora
[Distrobox](https://distrobox.it/) container to build and preview against a
matching toolchain rather than the host directly. These scripts complement
`deploy.sh` (user install) and `release.sh` (source release) rather than
replacing them.

### 14.1 Live preview with `view.sh`

`view.sh` builds the project, stages the package (including the generated
`buildInfo.js` deployment timestamp and the native CityCatalog plugin), then
installs or upgrades it and launches `plasmawindowed` for a quick windowed
preview.

- The target container defaults to `fedora-dev` and is overridable through the
  `VIEWER_CONTAINER` environment variable.
- When `distrobox` is on `PATH`, the install, upgrade, and launch steps run
  inside the container via `distrobox enter --name "$VIEWER_CONTAINER" -- …`.
  When `distrobox` is absent, the same commands run directly on the host, so
  the script also works outside a container.
- The viewer environment must provide `kpackagetool6` and `plasmawindowed`;
  the script checks for both before continuing.

### 14.2 Bazzite packaging with `package-bazzite.sh`

`package-bazzite.sh` produces a prebuilt `.plasmoid` for the immutable
[Bazzite](https://bazzite.gg/) host. Because the host is immutable, the package
must be built inside a Fedora Distrobox whose ABI matches Bazzite.

- The script reads `/etc/os-release` and refuses to run unless `ID=fedora`,
  printing a reminder to build inside a Fedora Distrobox to match the Bazzite
  host ABI. It currently supports `x86_64` only.
- It verifies the `package/metadata.json` version matches the CMake project
  version, builds, runs `ctest`, installs into a staging prefix, and confirms
  the staged tree contains both the plasmoid metadata and the native
  `libcitycatalogplugin.so`.
- It emits a versioned package named
  `SubSolarWorldMap-<version>-fedora<VERSION_ID>-<arch>.plasmoid` plus a
  SHA-256 checksum under `build-bazzite/packages/`. The result is a binary
  package tied to the building Fedora release and architecture, so it must be
  rebuilt for other Fedora releases or architectures.

## 15. Implementation Phases

### Phase 1: Foundation

- create plasmoid skeleton,
- load a static world map,
- verify QML runtime integration in `plasmoidviewer`.

### Phase 2: Rendering Pipeline

- implement day/night texture mixing,
- verify shader behavior and image scaling,
- tune terminal blending quality.

### Phase 3: Solar Model

- add JavaScript-based solar calculations,
- connect UTC time to the render loop,
- validate terminator movement over time.

### Phase 4: Marker System

- add Home and selected city markers,
- map lat/lon to screen space,
- allow configuration of selected city pins and a manual Home fallback.

### Phase 5: Polish and Packaging

- settings UI,
- packaging and install metadata,
- final validation and release readiness.

## 16. Acceptance Criteria

A version should be considered ready for initial milestone release when:

- the widget loads in Plasma without errors,
- the day/night map is visible and updates over time,
- the terminator moves with the sun as time passes,
- markers render at the correct world positions,
- the project builds with CMake and runs under `plasmoidviewer`.

## 17. Recommendation

The implementation should prioritize clarity and maintainability over cleverness. The best long-term design is: small QML view components, a single solar calculation module, and a tightly scoped shader texture blend. This keeps the product understandable for future contributors and makes it easier to test each step independently.
