# SubSolar World Map: Product Stories

This backlog captures the product direction implied by `README.md` and `HANDOVER.md`. It is intentionally written as a set of implementation-ready stories for a small KDE widget project.

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
movement, equivalent timezone representations, and invalid input.

### Story 4: Blend the map smoothly across day and night regions (complete)

As a user,
I want a smooth visual transition between day and night,
so that the terminator feels natural and readable rather than abrupt.

Acceptance criteria:

- a shader or equivalent effect blends day and night textures,
- the terminator edge is soft and visually continuous,
- the effect remains stable under resize and reflow.

### Story 5: Display only selected city markers from a configured list

As a user,
I want a subset of city markers displayed on the map,
so that I can focus on the places that matter to me without clutter.

Acceptance criteria:

- markers are positioned correctly based on latitude and longitude,
- labels or glyphs are readable,
- only enabled/selected cities from a configured list are displayed,
- each marker can show a city name and/or local time.

### Story 6: Configure custom timezone markers and resizable widget layout

As a user,
I want to choose cities from a searchable list and have the widget resize cleanly,
so that I can monitor the places I care about while fitting the desktop or panel layout.

Acceptance criteria:

- users can search the available city catalog and select or deselect cities,
- only selected cities are displayed as map markers,
- selected cities persist across restarts and catalog updates,
- users can add a custom location when it is not in the catalog,
- the widget remains readable and proportionally correct when resized.

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
- the widget loads a cached catalog (or packaged fallback) immediately and checks for updates asynchronously,
- a city dataset is downloaded only when the upstream version has changed, not on every launch,
- failed downloads or invalid updates keep the last known-good catalog and leave the widget usable offline,
- catalog updates preserve the user's selected cities,
- the UI can search the catalog without loading every city as a visible marker,
- the project provides the required ODbL attribution and documents any redistribution obligations.

## Suggested Priority Order

1. Foundation / plasmoid shell
2. Static equirectangular world view and shader blend
3. Real-time solar terminator
4. City marker support
5. Searchable city selection and persistence
6. Cached, asynchronous city-catalog updates
7. Packaging and release polish
8. Documentation and contributor onboarding

## Definition of Done for the Epic

The epic is complete when the widget:

- runs in KDE Plasma,
- updates dynamically with real time,
- shows the day/night boundary correctly,
- supports user-defined markers,
- is documented well enough for future contributors to continue development.
