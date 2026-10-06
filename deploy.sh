#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
PLASMOID_ID="org.eidleweise.subsolarworldmap"
DEPLOY_TIMESTAMP="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
RESTART_SHELL=false

case "${1:-}" in
    --restart-shell)
        RESTART_SHELL=true
        ;;
    --help|-h)
        printf 'Usage: %s [--restart-shell]\n' "${0##*/}"
        printf 'Build, test, and install the plasmoid. Optionally restart Plasma Shell to reload it immediately.\n'
        exit 0
        ;;
    "")
        ;;
    *)
        printf 'Unknown option: %s\nUsage: %s [--restart-shell]\n' "$1" "${0##*/}" >&2
        exit 2
        ;;
esac

for command in cmake ctest kpackagetool6; do
    if ! command -v "$command" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$command" >&2
        exit 1
    fi
done

if "$RESTART_SHELL"; then
    if ! command -v systemctl >/dev/null 2>&1; then
        printf 'Required command not found: systemctl\n' >&2
        exit 1
    fi
    if ! systemctl --user is-active --quiet plasma-plasmashell.service; then
        printf 'Plasma Shell service is not active; cannot restart it.\n' >&2
        exit 1
    fi
fi

cmake -S "$ROOT_DIR" -B "$BUILD_DIR"
cmake --build "$BUILD_DIR"
ctest --test-dir "$BUILD_DIR" --output-on-failure

staging_dir="$(mktemp -d "$BUILD_DIR/deploy-package.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
cp -a "$ROOT_DIR/package/." "$staging_dir/"
cp "$BUILD_DIR/generated/buildInfo.js" "$staging_dir/contents/js/buildInfo.js"
printf 'var deployTimestamp = "%s"\n' "$DEPLOY_TIMESTAMP" >> "$staging_dir/contents/js/buildInfo.js"
catalog_module_dir="$staging_dir/contents/lib/SubSolar/CityCatalog"
mkdir -p "$catalog_module_dir"
cp "$BUILD_DIR/qml/SubSolar/CityCatalog/qmldir" \
    "$BUILD_DIR/qml/SubSolar/CityCatalog/libcitycatalogplugin.so" \
    "$BUILD_DIR/libcitycatalogmanager.so" \
    "$catalog_module_dir/"

installed_packages="$(kpackagetool6 --type Plasma/Applet --list)"
if grep -Fqx "$PLASMOID_ID" <<<"$installed_packages"; then
    kpackagetool6 --type Plasma/Applet --upgrade "$staging_dir"
else
    kpackagetool6 --type Plasma/Applet --install "$staging_dir"
fi

if "$RESTART_SHELL"; then
    printf '\nRestarting Plasma Shell to load the updated applet...\n'
    systemctl --user restart plasma-plasmashell.service
else
    printf '\nPlasma Shell may still have the previous applet version loaded.\n'
    printf 'To reload it without logging out, run: systemctl --user restart plasma-plasmashell.service\n'
    printf 'For future deployments, use: ./deploy.sh --restart-shell\n'
fi

printf '\nInstalled %s for your Plasma user account.\n' "$PLASMOID_ID"
printf 'Open the desktop context menu, choose "Enter Edit Mode" or "Add Widgets", search for "SubSolar World Map", then drag it onto the desktop.\n'
