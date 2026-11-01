# SubSolar World Map
<img width="1283" height="642" alt="Screenshot_20261101_170608" src="https://github.com/user-attachments/assets/4020572a-66c3-458e-9e1a-a1d7991151bb" />

SubSolar World Map is a KDE Plasma 6 widget written for Fedora 44 / Bazzite that shows which parts of Earth
are in daylight and darkness.

## What you can do

- See the Sun's current position and the moving day/night boundary.
- Show the Moon's current overhead location with an illuminated phase icon;
  hover to see its phase and illumination.
- Show land and ocean time-zone boundaries, current UTC-offset labels, and an
  emphasized International Date Line.
- Show or hide the map's date and time, and choose its format and text style.
- Show your current location automatically, choose a city, or enter latitude
  and longitude for the Home pin.
- Search the alphabetized city list and add map pins. Duplicate catalog entries
  are combined; distinct places with the same name remain separate.
- Set each pin's color and opacity.
- Choose a shape for city pins.

The city list downloads the first time you open Cities settings and is then
stored on your device for offline use. Automatic location uses the location
services available on your device (such as GPS or network location). Or search
the downloaded city list or enter latitude and longitude to set the Home pin
yourself. Your coordinates are not sent to a geocoding service.

## Add the widget

In Plasma, right-click the desktop and choose **Add Widgets**. Search for
**SubSolar World Map** and add it to your desktop.

### Install from a source checkout

On a KDE Plasma 6 Linux system with the project build dependencies installed:

```sh
git clone https://github.com/eidleweise/SubSolarWorldMap.git
cd SubSolarWorldMap
./deploy.sh --restart-shell
```

The script builds and tests the widget, installs it for your user, and restarts
Plasma Shell. You can then add it from the desktop's **Add Widgets** menu as
described above. No `sudo` is needed.

### Create a release

To publish a release, install and authenticate the
[GitHub CLI](https://cli.github.com/) with `gh auth login`. Update the version
in both `package/metadata.json` and `CMakeLists.txt`, then commit and push the
changes on a branch that tracks its remote. With a clean, up-to-date worktree,
run:

```sh
./release.sh
```

The script reads the version from `package/metadata.json` and checks it against
CMake, builds the project, runs the tests, creates a versioned source archive
and SHA-256 checksum, then asks before creating the matching `v`-prefixed tag
and GitHub Release. Before publishing, it proposes a release title and
description for you to accept or edit, then asks you to type `publish`.
It uses a separate `build-release/` directory so a build
configured on the host or in another container cannot leave incompatible
compiler paths in CMake's cache. The archive and checksum are also kept in
`build-release/releases/`. Use `./release.sh --dry-run` to build and create the
artifacts without publishing.

Releases are source packages, not universal precompiled binaries. To install
one, download and extract the source archive from
[GitHub Releases](https://github.com/eidleweise/SubSolarWorldMap/releases),
then run `./deploy.sh --restart-shell` in the extracted folder. This builds
the native Qt plugin for your system, so you need the required build tools and
KDE/Qt development packages. See [docs/HANDOVER.md](docs/HANDOVER.md) for
build details.

## Settings

Right-click the widget and choose **Configure SubSolar World Map…**:
<img width="1402" height="809" alt="Screenshot_20261101_224148" src="https://github.com/user-attachments/assets/b5637f4e-c667-4747-a687-f1ab031e2b45" />


- **Date & Time** controls the clock overlay, its formatting, and whether the
  Moon marker is shown.
- **Cities** lets you choose automatic location, search for a city or enter
  coordinates for the Home pin, and manage selected city pins.
- **Time Zones** controls the timezone-boundary overlay, UTC-offset labels, and
  International Date Line styling.
- **Developer** can show the deployment timestamp and open diagnostic logs or
  recent Plasma Shell messages.

The deployment timestamp is off by default. The Developer page is optional for
normal use.

## Credits and license

This project is licensed under the [GNU General Public License v3.0](LICENSE).

Daytime map imagery is adapted from NASA's
[Blue Marble: Next Generation](https://science.nasa.gov/earth/earth-observatory/blue-marble-next-generation/base-topography-bathymetry/).
Nighttime imagery is adapted from NASA's
[Black Marble](https://www.earthdata.nasa.gov/data/projects/black-marble) (VIIRS).

City data comes from the
[Countries States Cities Database](https://github.com/dr5hn/countries-states-cities-database),
which is licensed under the
[Open Database License (ODbL) v1.0](https://github.com/dr5hn/countries-states-cities-database/blob/master/LICENSE).
The widget downloads a filtered subset of its city data. Credit:

> Data by Countries States Cities Database<br>
> https://github.com/dr5hn/countries-states-cities-database<br>
> Licensed under ODbL v1.0.

Time-zone boundaries are derived from the
[Timezone Boundary Builder](https://github.com/evansiroky/timezone-boundary-builder)
2026f `timezones-with-oceans-now` dataset, based on OpenStreetMap data. The
derived boundary data is licensed under the
[Open Data Commons Open Database License (ODbL) v1.0](https://opendatacommons.org/licenses/odbl/).
© [OpenStreetMap contributors](https://www.openstreetmap.org/copyright).
The International Date Line geometry is from
[Natural Earth](https://www.naturalearthdata.com/), public domain.

For build, architecture, and contribution details, see
[docs/HANDOVER.md](docs/HANDOVER.md) and
[docs/technical-code-document.md](docs/technical-code-document.md). The
[time zone overlay design](docs/timezone-overlay-design.md) records the current
behavior and remaining visual decisions.
