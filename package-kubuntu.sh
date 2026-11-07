#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
KUBUNTU_DISTROBOX_NAME="${KUBUNTU_DISTROBOX_NAME:-kubuntu-dev}"
KUBUNTU_DISTROBOX_IMAGE="${KUBUNTU_DISTROBOX_IMAGE:-docker.io/library/ubuntu:26.04}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build-kubuntu}"
if [[ "$BUILD_DIR" != /* ]]; then
    BUILD_DIR="$ROOT_DIR/$BUILD_DIR"
fi

build_package() {
    cd "$ROOT_DIR"
    if [[ -d /usr/lib/qt6/bin ]]; then
        export PATH="/usr/lib/qt6/bin:$PATH"
    fi

    for command in cmake ctest git jq zip sha256sum cc c++; do
        if ! command -v "$command" >/dev/null 2>&1; then
            printf 'Required command not found in the Ubuntu container: %s\n' "$command" >&2
            exit 1
        fi
    done

    if [[ ! -r /etc/os-release ]]; then
        printf 'Cannot identify the package build environment; /etc/os-release is missing.\n' >&2
        exit 1
    fi

    source /etc/os-release
    if [[ "${ID:-}" != "ubuntu" || ! "${VERSION_ID:-}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        printf 'Expected an Ubuntu container for the Kubuntu Plasma 6 package; found %s.\n' \
            "${ID:-unknown}" >&2
        exit 1
    fi

    version="$(jq -er '.KPlugin.Version | strings | select(length > 0)' package/metadata.json)"
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
        printf 'Unsupported package version in package/metadata.json: %s\n' "$version" >&2
        exit 1
    fi

    cmake_version="$(sed -nE 's/^project\([^ ]+ VERSION ([^ )]+).*/\1/p' CMakeLists.txt)"
    if [[ "$cmake_version" != "$version" ]]; then
        printf 'Version mismatch: package metadata is %s, CMake project is %s\n' \
            "$version" "${cmake_version:-missing}" >&2
        exit 1
    fi

    architecture="$(dpkg --print-architecture)"
    printf 'Building SubSolar World Map %s for Ubuntu %s (%s)\n' \
        "$version" "$VERSION_ID" "$architecture"
    cmake -S "$ROOT_DIR" -B "$BUILD_DIR"
    cmake --build "$BUILD_DIR"
    ctest --test-dir "$BUILD_DIR" --output-on-failure

    staging_root="$(mktemp -d "$BUILD_DIR/package.XXXXXX")"
    trap 'rm -rf "$staging_root"' EXIT
    cmake --install "$BUILD_DIR" --prefix "$staging_root"

    plasmoid_dir="$staging_root/share/plasma/plasmoids/org.eidleweise.subsolarworldmap"
    if [[ ! -f "$plasmoid_dir/metadata.json" || ! -f "$plasmoid_dir/contents/lib/SubSolar/CityCatalog/libcitycatalogplugin.so" ]]; then
        printf 'Installed staging tree is missing plasmoid metadata or the native Qt plugin.\n' >&2
        exit 1
    fi

    package_dir="$BUILD_DIR/packages"
    mkdir -p "$package_dir"
    package_name="SubSolarWorldMap-$version-kubuntu$VERSION_ID-$architecture.plasmoid"
    package_path="$package_dir/$package_name"
    temporary_package="$staging_root/$package_name"
    (
        cd "$plasmoid_dir"
        zip -qr "$temporary_package" .
    )
    mv -f "$temporary_package" "$package_path"
    (
        cd "$package_dir"
        sha256sum "$package_name" > "$package_name.sha256"
    )

    printf '\nCreated Kubuntu Plasma widget package:\n%s\n' "$package_path"
    printf 'SHA-256 checksum:\n%s.sha256\n' "$package_path"
    printf '\nInstall or upgrade for your user with:\n'
    printf 'kpackagetool6 --type Plasma/Applet --install "%s"\n' "$package_path"
    printf '\nThis package contains a native Qt plugin built for Ubuntu %s on %s. Build with an Ubuntu release matching your Kubuntu host.\n' \
        "$VERSION_ID" "$architecture"
}

if [[ "${1:-}" == "--build-inside-container" ]]; then
    shift
    if (($# != 1)); then
        printf 'Internal usage error: expected the build directory.\n' >&2
        exit 2
    fi
    BUILD_DIR="$1"
    build_package
    exit 0
fi

case "${1:-}" in
    --help|-h)
        printf 'Usage: %s\n' "${0##*/}"
        printf 'Build and test the widget in the kubuntu-dev Distrobox, then create a .plasmoid package and checksum.\n'
        printf 'Defaults to Ubuntu 26.04 LTS. Override the image to match the Kubuntu host (for example, Ubuntu 26.10).\n'
        printf 'Other overrides: KUBUNTU_DISTROBOX_NAME and BUILD_DIR.\n'
        exit 0
        ;;
    "")
        ;;
    *)
        printf 'Unknown option: %s\nUsage: %s\n' "$1" "${0##*/}" >&2
        exit 2
        ;;
esac

if ! command -v distrobox >/dev/null 2>&1; then
    printf 'Required command not found: distrobox\n' >&2
    exit 1
fi

KUBUNTU_DISTROBOX_NAME="$KUBUNTU_DISTROBOX_NAME" \
KUBUNTU_DISTROBOX_IMAGE="$KUBUNTU_DISTROBOX_IMAGE" \
    "$ROOT_DIR/makeKubuntuDevDistroBox.sh"

distrobox enter --name "$KUBUNTU_DISTROBOX_NAME" -- \
    bash "$ROOT_DIR/package-kubuntu.sh" --build-inside-container "$BUILD_DIR"

package_dir="$BUILD_DIR/packages"
if command -v xdg-open >/dev/null 2>&1 && xdg-open "$package_dir" >/dev/null 2>&1; then
    :
else
    printf 'Open this folder to access the package and checksum:\n%s\n' "$package_dir"
fi
