# SubSolar World Map
<img width="1283" height="642" alt="Screenshot_20261101_170608" src="https://github.com/user-attachments/assets/4020572a-66c3-458e-9e1a-a1d7991151bb" />

SubSolar World Map is a KDE Plasma 6 widget written for Fedora 44 / Bazzite that shows which parts of Earth
are in daylight and darkness.

## What this thing does

- At a glance, see where on Earth it's daytime and where it's night. The map tracks the Sun as the day/night line moves around the globe.
- Add city pins to see the local time where friends, family, or colleagues are. (Hover over a pin to see their time.)
- Show the Moon's location and phase, if that's your thing.
- Turn on time-zone borders, UTC offsets, and the International Date Line.
- Put a clock on the map so you can see your time too.
- Set a Home pin automatically, choose a city, or enter coordinates.
- Pretty much everything is customizable: opacity, colours, fonts, sizes, and time formats. I like options.

The city list downloads the first time you open Cities settings and is then
stored on your device for offline use. Automatic location uses the location
services available on your device (such as GPS or network location). Or search
the downloaded city list or enter latitude and longitude to set the Home pin
yourself. Your coordinates are not sent to a geocoding service.

## Add the widget

In Plasma, right-click the desktop and choose **Add Widgets**. Search for
**SubSolar World Map** and add it to your desktop.

## Store Page
The KDE Store lists [SubSolarWorldMap](https://store.kde.org/p/2380863/) and you can download the appropriate widget from their manually too.

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

### Fedora / Bazzite development environment

On a host with Distrobox installed, create or update the Fedora development
container:

```sh
./makeFedoraDevDistroBox.sh
```

This provisions the `fedora-dev` container with the compiler, Qt 6, Plasma
development/runtime tools, and project test dependencies. Enter it with
`distrobox enter --name fedora-dev`. To build and package a Bazzite-compatible
widget, run `./package-bazzite.sh` from the host checkout; it updates the
container, builds inside it, and opens the output folder when complete.

### CachyOS / Arch Linux development environment

On a host with Distrobox installed, create or update the Arch development
container:

```sh
./makeCachyArchDistroBox.sh
```

This provisions a `cachy-dev` container with the compiler, Qt 6, Plasma
development/runtime tools, and project test dependencies. Enter it for the
normal development workflow:

```sh
distrobox enter --name cachy-dev
```

To build a `.plasmoid` package for the CachyOS host, run this from the
repository on the host:

```sh
./package-cachy.sh
```

It updates the development container, builds and tests the widget there, and
creates a package and SHA-256 checksum in `build-cachy/packages/`. Use the
printed `kpackagetool6` command on the host to install it. Since the package
contains a native Qt plugin, keep CachyOS updated and rebuild if the host Qt
ABI differs from the container.

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


- **General** controls Moon visibility, map opacity and corner rounding, and an
  optional drop shadow with configurable opacity and direction.
- **Date & Time** controls the clock overlay, its formatting, and font.
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
