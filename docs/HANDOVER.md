# Handover Document: SubSolar World Map

**Project Name:** SubSolar World Map  
**Type:** KDE Plasma 6 Plasmoid / Desktop Widget  
**Core Functionality:** Real-time equirectangular world map displaying solar day/night cycles (terminator line); customizable timezone markers are planned follow-up work.  
**Target Platform:** KDE Plasma 6 (Linux)  

---

## 1. Executive Summary
SubSolar World Map is an open-source desktop widget designed for KDE Plasma 6. It renders a live daylight and night-shadow map based on astronomical solar positioning calculations, providing an aesthetic and functional global clock display inspired by classic mechanical map displays.

---

## 2. Technical Stack & Development Tools

| Component | Technology / Tool | Purpose |
| :--- | :--- | :--- |
| **User Interface** | QML (Qt Quick / Kirigami) | Native Plasma widget rendering, layout, and UI components. |
| **Day/Night Engine** | GLSL Shader / QML `ShaderEffect` | Hardware-accelerated dynamic masking of day/night textures. |
| **Logic & Math** | JavaScript (ECMAScript) | Subsolar point calculation, timezone offsets, and coordinate mapping. |
| **Recommended IDE** | JetBrains CLion / Qt Creator | Project editing, CMake integration, and QML debugging. |
| **Build System** | CMake | Standard build pipeline for KDE Plasma extensions. |

---

## 3. Project Architecture & Components

```text
SubSolar-World-Map/
├── CMakeLists.txt         # Build, shader compilation, and installation
└── package/
    ├── metadata.json      # Plasma 6 plasmoid metadata
    └── contents/
        ├── ui/
        │   ├── main.qml    # Plasmoid shell and solar update timer
        │   └── MapView.qml # Day/night textures and ShaderEffect
        ├── js/
        │   └── solarMath.js
        ├── shaders/
        │   ├── dayNight.frag    # GLSL fragment shader source
        │   └── dayNight.frag.qsb # Qt Quick shader package, built by CMake
        └── assets/
            ├── day/
            │   ├── world.equirectangular-2160x1080.png
            │   └── world.equirectangular-3840x1920.png
            └── night/
                ├── BlackMarble.equirectangular-2160x1080.png
                └── BlackMarble.equirectangular-3840x1920.png
```

### Core Implementation Strategy

1. **Solar Terminator Line:** Calculated via `solarMath.js` using UTC date/time to find the subsolar latitude ($\delta$) and longitude ($\lambda_0$). 
2. **Shader Rendering:** `MapView.qml` uses a `ShaderEffect` to mix the day and night textures along the curve defined by the equation:
   $$\sin(\text{lat}) \cdot \sin(\delta) + \cos(\text{lat}) \cdot \cos(\delta) \cdot \cos(\text{lon} - \lambda_0) = 0$$
3. **Subsolar Marker and Clock:** `MapView.qml` positions a small sun at the calculated subsolar coordinates; `main.qml` overlays the current local date and time at the top-center of the map, with configurable date, time, and timezone formats.
4. **Location Markers:** Latitude ($[-90, 90]$) and Longitude ($[-180, 180]$) coordinates are mapped linearly to $X/Y$ percentages on the equirectangular projection image.

Both textures cover the complete 2:1 longitude/latitude extent. The 2160x1080
and 3840x1920 variants are generated without cropping; the view chooses the
higher-resolution pair when its physical width exceeds 2160 pixels and keeps
the viewport at a 2:1 aspect ratio.

Plasma handles widget movement and resizing in desktop edit mode. The applet's
full representation advertises a compact 520x260 preferred size and 320x160
minimum size, both 2:1. The map viewport also remains 2:1 as the widget is
resized, and the date/time badge overlays its top-center rather than taking
space in a separate header. The applet opts out of Plasma's default background
so only the map and its overlay are visible; this does not constrain the
desktop resize handles or change the applet's actual bounds.

---

## 4. Legal & Naming Considerations

* **Brand Distinction:** The project name **SubSolar World Map** intentionally uses generic astronomical terminology ("subsolar") to avoid trademark conflicts with commercial brands (such as Geochron).
* **Licensing:** Proposed release under the **GPL-3.0** (or LGPL-3.0) license to align with the KDE community software ecosystem.
* **IDE Usage:** Developer environment utilizes JetBrains CLion under its free **Non-Commercial Use License**.

---

## 5. Build and Test

Run `./deploy.sh` to build and test the package, then install or upgrade it
in the current user's Plasma applet directory. No system-wide installation
or `sudo` is needed. After deployment, use the desktop's **Add Widgets**
interface to search for **SubSolar World Map** and add it to the desktop.

The package metadata must declare
`"X-Plasma-API-Minimum-Version": "6.0"` or Plasma 6's widget explorer will
label it as an unsupported widget. When upgrading, use the freshly generated
source package after building so the compiled shader is current.

When changing `dayNight.frag`, rebuild before upgrading so CMake regenerates
`dayNight.frag.qsb`. The shader's uniform block must start with
`mat4 qt_Matrix` and `float qt_Opacity`, followed by the custom solar uniforms
in declaration order. Keep both source textures available to the shader
through `ShaderEffectSource` items.

Mesa/EGL or portal errors from a containerized viewer may be unrelated to the
applet. Check for shader compilation and applet QML errors separately.

## 6. Next Steps & Roadmap

1. **Completed: Foundation and rendering:** Plasma package, static map, compiled day/night shader, and live solar uniforms.
2. **Completed: Solar model:** UTC solar position updates every 30 seconds, with deterministic math tests.
3. **Next: City markers:** Map latitude/longitude coordinates to the equirectangular view.
4. **Next: Configuration:** Add user configuration for selected and custom locations.

## 7. Tips for Using Black Marble with Blue Marble
* Pixel Alignment: Ensure both textures use the exact same base projection coordinates ($-180^\circ$ to $+180^\circ$ Longitude, $-90^\circ$ to $+90^\circ$ Latitude). NASA's standard 8K or 10K resolution Black Marble files pair directly with Blue Marble Next Generation images without needing manual warping or repositioning.
* Alpha Channel Adjustments: Standard Black Marble maps include ocean areas as solid black, which works cleanly in shaders when using an additive or blend mode over the daytime texture along the dark side of your solar terminator.