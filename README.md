# SubSolar World Map

SubSolar World Map is a KDE Plasma 6 widget that shows which parts of Earth
are in daylight and darkness.

## What you can do

- See the Sun's current position and the moving day/night boundary.
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

If you are installing from a source checkout, run `./deploy.sh --restart-shell`
from the project directory. This builds and installs the widget for your user
and restarts Plasma Shell so it can load the new version.

## Settings

Right-click the widget and choose **Configure SubSolar World Map…**:

- **Date & Time** controls the clock overlay and its formatting.
- **Cities** lets you choose automatic location, search for a city or enter
  coordinates for the Home pin, and manage selected city pins.
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

For build, architecture, and contribution details, see
[docs/HANDOVER.md](docs/HANDOVER.md) and
[docs/technical-code-document.md](docs/technical-code-document.md).
