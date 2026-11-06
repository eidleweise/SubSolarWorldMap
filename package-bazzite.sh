#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FEDORA_DISTROBOX_NAME="${FEDORA_DISTROBOX_NAME:-fedora-dev}"
FEDORA_DISTROBOX_IMAGE="${FEDORA_DISTROBOX_IMAGE:-registry.fedoraproject.org/fedora:latest}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build-bazzite}"
if [[ "$BUILD_DIR" != /* ]]; then
    BUILD_DIR="$ROOT_DIR/$BUILD_DIR"
fi

build_package() {
    cd "$ROOT_DIR"

    for command in cmake ctest git jq zip sha256sum cc c++; do
        if ! command -v "$command" >/dev/null 2>&1; then
            printf 'Required command not found in the Fedora container: %s\n' "$command" >&2
            exit 1
        fi
    done

    if [[ ! -r /etc/os-release ]]; then
        printf 'Cannot identify the package build environment; /etc/os-release is missing.\n' >&2
        exit 1
    fi

    source /etc/os-release
    if [[ "${ID:-}" != "fedora" || ! "${VERSION_ID:-}" =~ ^[0-9]+$ ]]; then
        printf 'Build this package in a Fedora Distrobox to match the Bazzite host ABI.\n' >&2
        exit 1
    fi

    architecture="$(uname -m)"
    if [[ "$architecture" != "x86_64" ]]; then
        printf 'This Bazzite package build currently supports x86_64 only; found %s.\n' \
            "$architecture" >&2
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

    printf 'Building SubSolar World Map %s for Fedora %s (%s)\n' \
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
    package_name="SubSolarWorldMap-$version-fedora$VERSION_ID-$architecture.plasmoid"
    package_path="$package_dir/$package_name"
    checksum_path="$package_path.sha256"
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

    printf '\nCreated Fedora Plasma widget package:\n%s\n' "$package_path"
    printf 'SHA-256 checksum:\n%s\n' "$checksum_path"
    printf '\nInstall for your user with:\n'
    printf 'kpackagetool6 --type Plasma/Applet --install "%s"\n' "$package_path"
    printf '\nThis binary package is for Fedora %s on %s; rebuild it for other Fedora releases or architectures.\n' \
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
        printf 'Build and test the widget in the fedora-dev Distrobox, then create a .plasmoid package and checksum for Bazzite.\n'
        printf 'Override the defaults with FEDORA_DISTROBOX_NAME, FEDORA_DISTROBOX_IMAGE, or BUILD_DIR.\n'
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

FEDORA_DISTROBOX_NAME="$FEDORA_DISTROBOX_NAME" \
FEDORA_DISTROBOX_IMAGE="$FEDORA_DISTROBOX_IMAGE" \
    "$ROOT_DIR/makeFedoraDevDistroBox.sh"

distrobox enter --name "$FEDORA_DISTROBOX_NAME" -- \
    bash "$ROOT_DIR/package-bazzite.sh" --build-inside-container "$BUILD_DIR"

package_dir="$BUILD_DIR/packages"
if command -v xdg-open >/dev/null 2>&1 && xdg-open "$package_dir" >/dev/null 2>&1; then
    :
else
    printf 'Open this folder to access the package and checksum:\n%s\n' "$package_dir"
fi
