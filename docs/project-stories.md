# SubSolar World Map: Product Stories

This backlog tracks implemented behavior and remaining validation for the KDE
Plasma widget. Status notes reflect the current source and test coverage; visual
and Plasma-runtime criteria still require checks on a live desktop.

## Epic: Live World Clock and Daylight Map

### Story 1: Load the plasmoid into Plasma

As a developer,
I want a working plasmoid shell,
so that the widget can render in KDE Plasma and be tested via `plasmoidviewer`.

Acceptance criteria:

- `metadata.json` exists and declares valid Plasma 6 metadata, including
  `"X-Plasma-API-Minimum-Version": "6.0"`.
- The project builds with CMake.
- `plasmoidviewer -a package` launches the widget without runtime errors.
- The widget displays a world map viewport.

### Story 2: Show a static equirectangular world map with daytime and nighttime imagery

As a user,
I want to see a flat equirectangular world map with day and night textures,
so that I have a clear visual representation of global daylight conditions in the first release.

Acceptance criteria:

- a day image is rendered in the widget as an equirectangular projection,
- a night image is rendered and visible in the dark hemisphere,
- image scaling works at different panel sizes and DPI settings,
- the widget can be moved and resized using Plasma's native edit-mode controls,
- the initial implementation does not require a 3D globe view.

Implementation note: day and night textures must retain the full 2:1
equirectangular extent (-180 to +180 degrees longitude and +90 to -90 degrees
latitude). Generate resolution variants without center-cropping; the map view
maintains a 2:1 viewport and switches to 3840x1920 textures for large
high-DPI views.

### Story 3: Calculate the current solar terminator

As a user,
I want the daylight boundary to move with the current sun position,
so that the map reflects the real-time time of day around the world.

Acceptance criteria:

- the app computes subsolar latitude and longitude from the current UTC time,
- the terminator updates every 30 seconds,
- a sun icon marks the subsolar point and the current local date/time appear in a top-center overlay on the map, with configurable date, time, and timezone formats,
- the result is consistent across repeated checks over a few minutes.

Implementation note: `solarMath.js` uses the UTC instant represented by a
JavaScript `Date`; it does not depend on the machine's local timezone. The
solar module has deterministic tests for equinox/solstice positions, longitude
movement, equivalent timezone representations, horizon transitions around
Greenwich equinox sunrise/sunset, polar-circle day/night at solstices, and
invalid input. `solarAltitudeCosine()` tests the daylight geometry used by the
map shader without requiring the user to change the system clock.

Status: **Implemented; automated edge-case checks pass.** The solar
position and shader update every 30 seconds, and the clock can be hidden or
configured for date format, time format, timezone, font family, and size. Time
with seconds refreshes independently each second. Automated calculation tests
cover representative dates and invalid inputs, as well as sunrise/sunset and
polar daylight geometry. A visual rendering pass remains optional follow-up.

### Story 4: Blend the map smoothly across day and night regions (complete)

As a user,
I want a smooth visual transition between day and night,
so that the terminator feels natural and readable rather than abrupt.

Acceptance criteria:

- a shader or equivalent effect blends day and night textures,
- the terminator edge is soft and visually continuous,
- the effect remains stable under resize and reflow.

### Story 5: Display only selected city markers from a configured list (complete)

As a user,
I want a subset of city markers displayed on the map,
so that I can focus on the places that matter to me without clutter.

Acceptance criteria:

- markers are positioned correctly based on latitude and longitude,
- the Cities settings page can search the downloaded, locally cached city list by city or country,
- city data is downloaded from the documented, versioned upstream CSV release on first use and cached per user,
- selected cities persist in applet configuration and only selected entries appear on the map,
- labels or glyphs are readable,
- each marker shows a city name.

Implementation note: selected catalog city pins currently show names, not local
times. Arbitrary user-entered locations are not supported; the selectable
markers come from the city catalog, alongside the separate Home pin.

### Story 6: Configure home location and selected city pins (complete)

As a user,
I want to choose cities from a searchable list and have the widget resize cleanly,
so that I can monitor the places I care about while fitting the desktop or panel layout.

Acceptance criteria:

- a distinct Home pin uses the system location through GeoClue,
- the applet requests a fresh GeoClue location at startup and continues periodic updates while running,
- the Home pin is labeled with the nearest catalog city and country when available,
- Home pins have configurable color and opacity; each selected city has its own color and opacity settings, with selectable city marker shapes,
- shift-clicking a selected city's opacity slider applies that opacity to all selected cities while preserving per-city colors,
- per-city opacity gestures and resulting saved values are recorded in the diagnostics log,
- the Cities settings page shows the nearest listed city and recalculates it when the location or catalog changes,
- opening Cities settings reuses the applet's latest location instead of starting another GeoClue watcher,
- users can configure manual Home coordinates as a fallback when a fresh system location is unavailable, rather than silently using stale saved coordinates,
- users can search the downloaded city catalog and select or deselect city pins,
- selected cities persist across restarts,
- the widget remains readable and proportionally correct when resized.

Status: **Implemented; helper tests added.** Automated tests cover fresh
GeoClue location precedence, manual fallback when no fresh fix exists, ignoring
stale saved coordinates, invalid location values, and no-pin behavior when
fallback is disabled. Fresh startup behavior was verified in the deployed
widget; opening settings reuses the applet's location watcher.

### Story 7: Provide a reusable solar math module

As a developer,
I want solar calculations isolated in a focused JavaScript module,
so that the logic is testable, maintainable, and reusable.

Acceptance criteria:

- `solarMath.js` contains the astronomical core functions,
- the module exposes deterministic inputs and outputs,
- the shader or view layer depends on that module rather than duplicating calculations.

### Story 8: Support a clean desktop aesthetic with Plasma-native styling

As a user,
I want the widget to feel native to KDE Plasma,
so that it integrates with the desktop environment instead of looking like a generic web widget.

Acceptance criteria:

- the widget matches Plasma UI conventions,
- sizing and spacing work well in panel and desktop modes,
- visual styling does not degrade readability at standard DPI settings.

### Story 9: Package the project for installation and distribution

As a maintainer,
I want the project to build and install cleanly,
so that it can be distributed or installed in a KDE environment.

Acceptance criteria:

- CMake install targets are defined correctly,
- the plasmoid can be installed to the expected Plasma directory,
- the widget loads after installation without source-path assumptions.

### Story 10: Add developer documentation and onboarding notes

As a contributor,
I want the project to include implementation and onboarding documentation,
so that future work is easy to understand and extend.

Acceptance criteria:

- the repo includes architecture notes,
- the solar and rendering approach is explained in plain language,
- the expected implementation phases are visible to contributors.

Status: **Complete.** README, handover, technical documentation, attribution,
deployment notes, logging instructions, and this backlog are maintained.

### Story 10a: Configure the map date and time display (complete)

As a user,
I want to control whether the clock appears and how it is formatted,
so that the overlay fits my preferred map presentation.

Acceptance criteria:

- users can show or hide the date/time overlay,
- date, time, timezone, font family, and font size are configurable,
- second-level clock refresh runs only when a seconds format is selected and
  the overlay is visible.

### Story 10b: Provide developer diagnostics (complete)

As a developer,
I want to inspect deployment information and diagnostics,
so that I can troubleshoot the widget without manually locating its files.

Acceptance criteria:

- the deployment timestamp is optional and off by default,
- settings open the current rotating widget log and its containing folder,
- settings can open recent Plasma Shell journal messages in a terminal,
- runtime launch failures are surfaced in the settings UI.

## Epic: Quality and Maintainability

### Story 11: Validate visual correctness against real-world time changes

As a developer,
I want to compare the rendered daylight mask against actual sun movement,
so that the terminator and map logic remain trustworthy.

Acceptance criteria:

- the map changes over the course of multiple time checks,
- daylight and nighttime regions correspond to expected hemispheres,
- odd edge cases such as sunrise/sunset and near-polar conditions are reviewed.

### Story 12: Create a small testable configuration model

As a developer,
I want marker and timezone data to follow a simple schema,
so that the project is easier to test and extend.

Acceptance criteria:

- configuration is serializable to JSON,
- test data can be loaded without a running UI,
- invalid or missing entries fail gracefully.

### Story 13: Refresh the city catalog from its upstream source

As a user,
I want the available city list to receive updates from its maintained data source,
so that I can find current locations without manually replacing the list.

Acceptance criteria:

- the catalog includes city names, numeric latitude/longitude, and timezone identifiers when available,
- the widget loads the per-user cached catalog immediately and checks for upstream updates asynchronously at startup,
- a city dataset is downloaded only when the upstream version has changed, not on every launch,
- failed downloads or invalid updates keep the last known-good catalog and leave the widget usable offline,
- catalog updates preserve the user's selected cities,
- the UI can search the catalog without loading every city as a visible marker,
- the project provides the required ODbL attribution and documents any redistribution obligations.

Status: **Implemented.** The app loads a per-user cache immediately and checks
upstream release metadata at most every six hours. The check timestamp is
updated only after a successful metadata check, so network failures do not
delay retries. Changed data is downloaded, SHA-256 verified, parsed, and
atomically saved before replacing the active cache.

### Story 14: Validate settings pages and runtime behavior in Plasma

As a maintainer,
I want to verify the applet's settings pages and location behavior in the
target Plasma runtime,
so that successful builds also correspond to a clean interactive experience.

Acceptance criteria:

- opening each settings category produces no missing `cfg_*` property errors,
- startup location refresh updates the Home pin when GeoClue succeeds,
- automated tests verify manual fallback selection when a fresh location is unavailable,
- settings-page scene-placement warnings are understood and resolved or
  documented as benign,
- deployment and journal buttons behave correctly in the user's environment.

Status: **In progress.** Missing `cfg_*` declarations have been fixed and
verified in the deployed settings pages; the previous missing-property errors
are gone. After the latest redeploy, the journal confirmed a fresh startup
GeoClue request, a valid position update, and a nearest-city update to
Solihull. Automated tests now cover manual fallback selection without disabling
GeoClue on the user's desktop. A live settings pass confirmed Appearance,
Cities, and Developer render and respond normally, while About opens without a warning.
Plasma still reports "Created graphical object was not placed in the graphics
scene" when the three custom settings pages open. No functional failure was
observed, so this currently appears to be a benign lifecycle warning, though
its cause is not confirmed.

## Remaining Priority Order

1. Optionally confirm the manual fallback visually in Plasma; its selection
   behavior is covered by automated helper tests.
2. Optionally investigate the non-blocking Plasma settings-page
   scene-placement warning if it recurs or starts affecting behavior.
3. Optionally inspect the rendered map against the automated sunrise/sunset
   and polar-geometry scenarios.
4. Optionally add local times to city pins or arbitrary custom locations if
   those become product requirements.

## Definition of Done for the Epic

The epic is complete when the widget:

- runs in KDE Plasma,
- updates dynamically with real time,
- shows the day/night boundary correctly,
- supports selected city markers and a configurable Home location,
- is documented well enough for future contributors to continue development.

Core rendering, marker selection, catalog updating, configuration, packaging,
and documentation are implemented. The remaining work is runtime/visual
validation rather than foundational feature development.
