#!/usr/bin/env bash
set -euo pipefail

ARCH_DISTROBOX_NAME="${ARCH_DISTROBOX_NAME:-cachy-dev}"
ARCH_DISTROBOX_IMAGE="${ARCH_DISTROBOX_IMAGE:-docker.io/library/archlinux:latest}"

case "${1:-}" in
    --help|-h)
        printf 'Usage: %s\n' "${0##*/}"
        printf 'Create or update an Arch Linux Distrobox for CachyOS/Arch Plasma development.\n'
        printf 'Override the defaults with ARCH_DISTROBOX_NAME or ARCH_DISTROBOX_IMAGE.\n'
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

if ! distrobox list --no-color | awk -F'|' -v target="$ARCH_DISTROBOX_NAME" '
    NR > 1 {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
        if ($2 == target) found = 1
    }
    END { exit !found }
'; then
    printf 'Creating Arch Linux Distrobox "%s" from %s\n' \
        "$ARCH_DISTROBOX_NAME" "$ARCH_DISTROBOX_IMAGE"
    distrobox create --yes --name "$ARCH_DISTROBOX_NAME" --image "$ARCH_DISTROBOX_IMAGE"
fi

printf 'Updating Arch and installing development dependencies in "%s"...\n' \
    "$ARCH_DISTROBOX_NAME"
distrobox enter --name "$ARCH_DISTROBOX_NAME" -- \
    sudo pacman -Syu --needed --noconfirm \
    base-devel cmake coreutils git gawk grep jq nodejs qt6-base \
    qt6-declarative qt6-positioning qt6-shadertools sed zlib zip \
    plasma-sdk plasma-workspace

printf '\nArch development environment "%s" is ready.\n' "$ARCH_DISTROBOX_NAME"
printf 'Enter it with: distrobox enter --name %s\n' "$ARCH_DISTROBOX_NAME"
