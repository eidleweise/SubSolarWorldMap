#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
PLASMOID_ID="org.eidleweise.subsolarworldmap"

for command in cmake ctest kpackagetool6; do
    if ! command -v "$command" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$command" >&2
        exit 1
    fi
done

cmake -S "$ROOT_DIR" -B "$BUILD_DIR"
cmake --build "$BUILD_DIR"
ctest --test-dir "$BUILD_DIR" --output-on-failure

staging_dir="$(mktemp -d "$BUILD_DIR/deploy-package.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
cp -a "$ROOT_DIR/package/." "$staging_dir/"
cp "$BUILD_DIR/generated/buildInfo.js" "$staging_dir/contents/js/buildInfo.js"

installed_packages="$(kpackagetool6 --type Plasma/Applet --list)"
if grep -Fqx "$PLASMOID_ID" <<<"$installed_packages"; then
    kpackagetool6 --type Plasma/Applet --upgrade "$staging_dir"
else
    kpackagetool6 --type Plasma/Applet --install "$staging_dir"
fi

printf '\nInstalled %s for your Plasma user account.\n' "$PLASMOID_ID"
printf 'Open the desktop context menu, choose "Enter Edit Mode" or "Add Widgets", search for "SubSolar World Map", then drag it onto the desktop.\n'
