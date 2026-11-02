#!/usr/bin/env bash
set -euo pipefail

FEDORA_DISTROBOX_NAME="${FEDORA_DISTROBOX_NAME:-fedora-dev}"
FEDORA_DISTROBOX_IMAGE="${FEDORA_DISTROBOX_IMAGE:-registry.fedoraproject.org/fedora:latest}"

case "${1:-}" in
    --help|-h)
        printf 'Usage: %s\n' "${0##*/}"
        printf 'Create or update a Fedora Distrobox for SubSolar World Map development and Bazzite packaging.\n'
        printf 'Override the defaults with FEDORA_DISTROBOX_NAME or FEDORA_DISTROBOX_IMAGE.\n'
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

if ! distrobox list --no-color | awk -F'|' -v target="$FEDORA_DISTROBOX_NAME" '
    NR > 1 {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
        if ($2 == target) found = 1
    }
    END { exit !found }
'; then
    printf 'Creating Fedora Distrobox "%s" from %s\n' \
        "$FEDORA_DISTROBOX_NAME" "$FEDORA_DISTROBOX_IMAGE"
    distrobox create --yes --name "$FEDORA_DISTROBOX_NAME" --image "$FEDORA_DISTROBOX_IMAGE"
fi

printf 'Updating Fedora and installing development dependencies in "%s"...\n' \
    "$FEDORA_DISTROBOX_NAME"
distrobox enter --name "$FEDORA_DISTROBOX_NAME" -- \
    sudo dnf upgrade -y
distrobox enter --name "$FEDORA_DISTROBOX_NAME" -- \
    sudo dnf install -y \
    cmake gcc-c++ git gawk grep jq nodejs zip zlib-devel \
    qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtpositioning-devel \
    qt6-qtshadertools-devel kf6-kcmutils kf6-kirigami kf6-kpackage \
    plasma-sdk plasma-workspace

printf '\nFedora development environment "%s" is ready.\n' "$FEDORA_DISTROBOX_NAME"
printf 'Enter it with: distrobox enter --name %s\n' "$FEDORA_DISTROBOX_NAME"
