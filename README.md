# SubSolar World Map

A real-time, astronomical world clock and daylight map widget for **KDE Plasma 6**.

Inspired by classic mechanical world clocks, **SubSolar World Map** renders an equirectangular projection of the Earth with a dynamic solar terminator line showing real-time day, night, and twilight cycles alongside customizable timezone markers.

---

## Features

- **Live Solar Map:** The subsolar point is calculated from UTC and refreshed every 30 seconds.
- **Sun Position and Local Clock:** A sun marker shows the current subsolar point, with an optional local date and time overlay at the top-center of the map; date, time, timezone, and font display are configurable.
- **Deployment Debug Timestamp:** A red timestamp at the lower-right of the map shows when the currently installed package was deployed.
- **Date & Time Settings:** Choose whether to show the map clock, and configure its date, time, timezone, and font display in the widget settings.
- **Developer Settings:** Toggle the deployment timestamp, open the current diagnostic log or its containing folder, and inspect recent Plasma Shell journal messages in the configured terminal.
- **Home and City Pins:** Show a distinct Home pin from GeoClue system location, with manual fallback, and select city pins from the downloaded, locally cached city list.
- **Day/Night Imagery:** Matched 2:1 equirectangular day and night maps are blended in a Qt Quick shader with a soft solar terminator.
- **Proportional Scaling:** The compact widget and map use a 2:1 ratio, and the map keeps its projection when resized while selecting higher-resolution textures for large/high-DPI views.
- **Transparent Widget Background:** Plasma's default applet background is hidden so the map is the visible widget content.
- **About Information:** The widget settings include Plasma's native About page with project, version, license, and attribution information.
- **Plasma 6 Package:** Includes Plasma applet metadata and CMake install support.

---

## Requirements

- **KDE Plasma 6**
- **Qt 6** (Qt Quick)
- **Qt Positioning with GeoClue** (system location for the Home pin)
- **Qt QML, Network, Concurrent, and zlib development libraries** (city catalog support)
- **CMake** (3.16 or higher)
- **Qt Shader Tools** (`qsb`) to rebuild the fragment shader
- **Node.js** (optional, for solar math tests)

---

## Development & Testing

### Deploying to Your Plasma Desktop

Run the deployment script from the project directory. It builds the package,
runs the available tests, and installs or upgrades the applet in your user
account's Plasma applets directory. It does not require `sudo`. The package
metadata must declare
`"X-Plasma-API-Minimum-Version": "6.0"` or Plasma 6's Add Widgets panel will
mark it unsupported.

```bash
./deploy.sh --restart-shell
```

The option restarts Plasma Shell after installation so the running desktop
loads the updated applet; the panel and desktop may briefly disappear during
the restart. To install without restarting, use `./deploy.sh`, then run
`systemctl --user restart plasma-plasmashell.service` when you want the desktop
to load the new version. This does not require logging out.

After installation, right-click the desktop, enter edit mode or choose **Add
Widgets**, search for **SubSolar World Map**, then drag the widget onto the
desktop. Plasma's panel widget picker may need to be closed and reopened to
refresh its list.

To change the clock display, right-click the widget and choose **Configure
SubSolar World Map…**. The Date & Time page lets you show or hide the map clock
and provides date choices (short, long,
or ISO) and 12-/24-hour time choices, with optional seconds. The timezone can
be hidden, shown as a short abbreviation, or shown by its full name. The clock
font family and size can also be changed.

The **Developer** page controls the red deployment timestamp (off by default),
provides shortcuts to the rotating diagnostic log and its folder, and can open
recent Plasma Shell journal messages in the configured terminal. It shows the
last 15 minutes and follows new messages. The app keeps the current log and one
rotated copy; the journal is useful for Plasma or Qt warnings outside the
widget's detailed log. Konsole is used when available to ensure host
`journalctl` runs outside a sandboxed terminal; otherwise the configured
`xdg-terminal-exec` launcher is used.
The font-family dropdown can be filtered by typing part of a font name
directly into it; a separate preview shows the selected family at the chosen
size.
The **Cities** page downloads the city catalog on first use and caches it in
your user data directory. It checks the upstream release metadata at startup
(at most once every six hours) and downloads a changed catalog in the
background, keeping the cached version available until the replacement has
been verified and saved. The nearest city for the GeoClue Home location is
shown as an approximation, without sending coordinates to an external
geocoding service.
The page separates **Home**, **Selected Cities**, and **Add Cities** into
collapsible sections. Home includes side-by-side manual fallback coordinates;
it also lets you hide or show the Home pin independently. Selected Cities lists
the active map pins; Add Cities searches the cached list.
The applet requests a fresh GeoClue location at startup and refreshes it while
running; opening the Cities settings page reuses its latest successful position
and does not start another location watcher. If a fresh fix is unavailable,
users can enable manual fallback coordinates instead of silently using stale
saved coordinates. Home pin color and opacity are configurable. Each selected
city has its own color and opacity controls beside its name; city pin shape
can also be set to circles, diamonds, or squares. Shift-click any selected
city's opacity slider to set every selected city's opacity to that position
while preserving individual colors. The other sliders jump to that value
immediately. Color selectors show color swatches instead of color names.
The catalog is sourced from
the versioned Countries States Cities Database city CSV release and includes
places with population of at least 10,000. Network access is required the
first time the catalog is downloaded; the last good copy remains available
offline afterward.

Catalog and Home-location diagnostics are appended to:

`~/.local/share/subsolar-world-map/subsolar-world-map.log`

The **Cities** settings page also shows the full log path. Follow it with
`tail -f ~/.local/share/subsolar-world-map/subsolar-world-map.log`. The log
reports cache loading, release checks, downloads, parsing and save results,
GeoClue update/error events, and nearest-city updates. It does not print
precise Home coordinates and rotates at 1 MiB, retaining one previous log.
Per-city opacity interactions are tagged `[SubSolar pin opacity]`; check for
`Shift pointer handler pressed`, `Shift-click detected`, `Slider moved`,
`Bulk update requested`, and `Bulk update stored` to trace the gesture and
confirm the value now saved for each selected city.

### Previewing in a Standalone Plasma Window

To build and install or upgrade the applet for your user, then preview it in a
resizable standalone Plasma window, run:

```bash
./view.sh
```

This uses `plasmawindowed` and `kpackagetool6` in the `fedora-dev` Distrobox
when `distrobox` is available. Set `VIEWER_CONTAINER` to use a different
container. Without Distrobox, those commands must be available on the host.
The standalone window is useful for checking rendering and resizing, but does
not provide Plasma Shell's applet context menu or settings dialog. Test those
on the desktop by right-clicking the installed widget; logging out is not
required.

### Moving and Resizing on the Desktop

Plasma owns applet movement and resizing. On the desktop, right-click the
widget and choose **Enter Edit Mode** (or use the desktop's edit-mode control),
then drag the widget to move it or drag its resize handles. The widget's
preferred and minimum sizes (520×260 and 320×160) follow the map's 2:1 ratio;
the map viewport also stays 2:1 when resized. The surrounding applet area is
transparent; it remains part of the widget's resize bounds.

---

## Technical Documentation & Roadmap

For detailed architectural diagrams, mathematical formulations for the solar terminator, and developer handover notes, please refer to:

- [docs/HANDOVER.md](docs/HANDOVER.md)
- [docs/technical-code-document.md](docs/technical-code-document.md)
- [docs/project-stories.md](docs/project-stories.md)

---

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).

### Map Imagery Attribution

The map textures are adapted from NASA imagery: daytime imagery from
[Blue Marble: Next Generation](https://science.nasa.gov/earth/earth-observatory/blue-marble-next-generation/base-topography-bathymetry/)
and nighttime-lights imagery from [NASA's Black Marble project](https://www.earthdata.nasa.gov/data/projects/black-marble)
(VIIRS). The source datasets are credited to NASA and their contributing
missions and teams; the textures here have been resized for this widget.

### City Data Attribution

The runtime city catalog is derived from the latest tagged release of the
[Countries States Cities Database](https://github.com/dr5hn/countries-states-cities-database),
using its `csv-cities.csv.gz` asset rather than its managed API. The source data is licensed under the
[Open Database License (ODbL) v1.0](https://github.com/dr5hn/countries-states-cities-database/blob/master/LICENSE)
and requires attribution. Credit:

> Data by Countries States Cities Database<br>
> https://github.com/dr5hn/countries-states-cities-database<br>
> Licensed under ODbL v1.0.

The generated catalog is a filtered, modified subset. Review the ODbL
share-alike requirements when redistributing it. This attribution applies to
city data, not the project's source code.
