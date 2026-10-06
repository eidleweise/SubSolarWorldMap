#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
VIEWER_CONTAINER="${VIEWER_CONTAINER:-fedora-dev}"
PLASMOID_ID="org.eidleweise.subsolarworldmap"
DEPLOY_TIMESTAMP="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

if ! command -v cmake >/dev/null 2>&1; then
    printf 'Required command not found: cmake\n' >&2
    exit 1
fi

cmake -S "$ROOT_DIR" -B "$BUILD_DIR"
cmake --build "$BUILD_DIR"

staging_dir="$(mktemp -d "$BUILD_DIR/viewer-package.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
cp -a "$ROOT_DIR/package/." "$staging_dir/"
cp "$BUILD_DIR/generated/buildInfo.js" "$staging_dir/contents/js/buildInfo.js"
printf 'var deployTimestamp = "%s"\n' "$DEPLOY_TIMESTAMP" >> "$staging_dir/contents/js/buildInfo.js"

if command -v distrobox >/dev/null 2>&1; then
    run_in_viewer() {
        distrobox enter --name "$VIEWER_CONTAINER" -- "$@"
    }
else
    run_in_viewer() {
        "$@"
    }
fi

if ! run_in_viewer sh -c 'command -v kpackagetool6 >/dev/null && command -v plasmawindowed >/dev/null'; then
    printf 'Required commands not found in viewer environment: kpackagetool6 and plasmawindowed\n' >&2
    exit 1
fi

installed_packages="$(run_in_viewer kpackagetool6 --type Plasma/Applet --list)"
if grep -Fqx "$PLASMOID_ID" <<<"$installed_packages"; then
    run_in_viewer kpackagetool6 --type Plasma/Applet --upgrade "$staging_dir"
else
    run_in_viewer kpackagetool6 --type Plasma/Applet --install "$staging_dir"
fi

run_in_viewer plasmawindowed "$PLASMOID_ID"
