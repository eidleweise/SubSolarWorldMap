# SubSolar World Map

A real-time, astronomical world clock and daylight map widget for **KDE Plasma 6**.

Inspired by classic mechanical world clocks, **SubSolar World Map** renders an equirectangular projection of the Earth with a dynamic solar terminator line showing real-time day, night, and twilight cycles alongside customizable timezone markers.

---

## Features

- **Live Solar Map:** The subsolar point is calculated from UTC and refreshed every 30 seconds.
- **Sun Position and Local Clock:** A sun marker shows the current subsolar point, with the local date and time overlaid at the top-center of the map; timezone display is configurable.
- **Deployment Debug Timestamp:** A red timestamp at the lower-right of the map shows when the currently installed package was deployed.
- **Clock Format Settings:** Choose common date and time formats in the widget's context-menu configuration.
- **Day/Night Imagery:** Matched 2:1 equirectangular day and night maps are blended in a Qt Quick shader with a soft solar terminator.
- **Proportional Scaling:** The compact widget and map use a 2:1 ratio, and the map keeps its projection when resized while selecting higher-resolution textures for large/high-DPI views.
- **Transparent Widget Background:** Plasma's default applet background is hidden so the map is the visible widget content.
- **About Dialog:** Open the widget's context menu to view project and license information, including the local build date and time.
- **Plasma 6 Package:** Includes Plasma applet metadata and CMake install support.

City selection and map markers are planned follow-up work.

---

## Requirements

- **KDE Plasma 6**
- **Qt 6** (Qt Quick)
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
SubSolar World Map…**. The Appearance page provides date choices (short, long,
or ISO) and 12-/24-hour time choices, with optional seconds. The timezone can
be hidden, shown as a short abbreviation, or shown by its full name. The clock
font family and size can also be changed.
The font-family dropdown can be filtered by typing part of a font name
directly into it; a separate preview shows the selected family at the chosen
size.

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

### Planned City Data Attribution

When city data from the [Countries States Cities Database](https://github.com/dr5hn/countries-states-cities-database)
is bundled or redistributed, it is licensed under the
[Open Database License (ODbL) v1.0](https://github.com/dr5hn/countries-states-cities-database/blob/master/LICENSE)
and requires attribution. Credit:

> Data by Countries States Cities Database<br>
> https://github.com/dr5hn/countries-states-cities-database<br>
> Licensed under ODbL v1.0.

Any bundled, modified, or derived city dataset should also be reviewed for the
ODbL's share-alike requirements. This attribution applies to city data, not
the project's source code.
