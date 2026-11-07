#!/usr/bin/env bash
set -euo pipefail

KUBUNTU_DISTROBOX_NAME="${KUBUNTU_DISTROBOX_NAME:-kubuntu-dev}"
KUBUNTU_DISTROBOX_IMAGE="${KUBUNTU_DISTROBOX_IMAGE:-docker.io/library/ubuntu:26.04}"

case "${1:-}" in
    --help|-h)
        printf 'Usage: %s\n' "${0##*/}"
        printf 'Create or update an Ubuntu Distrobox with Qt 6 and KDE Plasma 6 dependencies for Kubuntu packaging.\n'
        printf 'Defaults to Ubuntu 26.04 LTS; set KUBUNTU_DISTROBOX_IMAGE to match the Kubuntu release (for example, Ubuntu 26.10).\n'
        printf 'Override the defaults with KUBUNTU_DISTROBOX_NAME or KUBUNTU_DISTROBOX_IMAGE.\n'
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

if ! distrobox list --no-color | awk -F'|' -v target="$KUBUNTU_DISTROBOX_NAME" '
    NR > 1 {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
        if ($2 == target) found = 1
    }
    END { exit !found }
'; then
    printf 'Creating Kubuntu build Distrobox "%s" from %s\n' \
        "$KUBUNTU_DISTROBOX_NAME" "$KUBUNTU_DISTROBOX_IMAGE"
    distrobox create --yes --name "$KUBUNTU_DISTROBOX_NAME" --image "$KUBUNTU_DISTROBOX_IMAGE"
fi

printf 'Updating Ubuntu and installing Qt 6 / Plasma 6 build dependencies in "%s"...\n' \
    "$KUBUNTU_DISTROBOX_NAME"
distrobox enter --name "$KUBUNTU_DISTROBOX_NAME" -- \
    sudo apt-get update
distrobox enter --name "$KUBUNTU_DISTROBOX_NAME" -- \
    sudo apt-get install -y software-properties-common
distrobox enter --name "$KUBUNTU_DISTROBOX_NAME" -- \
    sudo add-apt-repository -y universe
distrobox enter --name "$KUBUNTU_DISTROBOX_NAME" -- \
    sudo apt-get update
distrobox enter --name "$KUBUNTU_DISTROBOX_NAME" -- \
    sudo apt-get upgrade -y
distrobox enter --name "$KUBUNTU_DISTROBOX_NAME" -- \
    sudo apt-get install -y \
    build-essential cmake git gawk grep jq nodejs zip zlib1g-dev \
    qt6-base-dev qt6-declarative-dev qt6-positioning-dev qt6-shadertools-dev qt6-shader-baker \
    libkf6kcmutils-dev plasma-sdk plasma-workspace

printf '\nKubuntu build environment "%s" is ready.\n' "$KUBUNTU_DISTROBOX_NAME"
printf 'Enter it with: distrobox enter --name %s\n' "$KUBUNTU_DISTROBOX_NAME"
