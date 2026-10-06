#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
VIEWER_CONTAINER="${VIEWER_CONTAINER:-fedora-dev}"

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

if command -v distrobox >/dev/null 2>&1; then
    distrobox enter --name "$VIEWER_CONTAINER" -- plasmoidviewer --applet "$staging_dir"
else
    PLASMOID_VIEWER=""
    for candidate in plasmoidviewer6 plasmoidviewer; do
        if command -v "$candidate" >/dev/null 2>&1; then
            PLASMOID_VIEWER="$candidate"
            break
        fi
    done

    if [[ -z "$PLASMOID_VIEWER" ]]; then
        printf 'Required command not found: distrobox or plasmoidviewer6/plasmoidviewer\n' >&2
        exit 1
    fi

    "$PLASMOID_VIEWER" --applet "$staging_dir"
fi
