#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build-release}"
DRY_RUN=false

case "${1:-}" in
    --dry-run)
        DRY_RUN=true
        ;;
    --help|-h)
        printf 'Usage: %s [--dry-run]\n' "${0##*/}"
        printf 'Build and test the project, create a versioned source archive, and publish a GitHub Release.\n'
        printf 'The release tag is read from package/metadata.json and checked against CMakeLists.txt.\n'
        exit 0
        ;;
    "")
        ;;
    *)
        printf 'Unknown option: %s\nUsage: %s [--dry-run]\n' "$1" "${0##*/}" >&2
        exit 2
        ;;
esac

for command in cmake ctest git jq sha256sum cc c++; do
    if ! command -v "$command" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$command" >&2
        exit 1
    fi
done

if ! $DRY_RUN; then
    for command in gh; do
        if ! command -v "$command" >/dev/null 2>&1; then
            printf 'Required command not found: %s (install and authenticate GitHub CLI first)\n' "$command" >&2
            exit 1
        fi
    done
fi

version="$(jq -er '.KPlugin.Version | strings | select(length > 0)' package/metadata.json)"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
    printf 'Unsupported release version in package/metadata.json: %s\n' "$version" >&2
    exit 1
fi

cmake_version="$(sed -nE 's/^project\([^ ]+ VERSION ([^ )]+).*/\1/p' CMakeLists.txt)"
if [[ "$cmake_version" != "$version" ]]; then
    printf 'Version mismatch: package metadata is %s, CMake project is %s\n' \
        "$version" "${cmake_version:-missing}" >&2
    exit 1
fi

tag="v$version"
if [[ -n "$(git status --porcelain --untracked-files=all)" ]]; then
    printf 'The worktree must be clean before releasing. Commit or remove these changes first:\n' >&2
    git status --short >&2
    exit 1
fi

branch="$(git branch --show-current)"
if [[ -z "$branch" ]]; then
    printf 'Releases must be made from a named branch, not detached HEAD.\n' >&2
    exit 1
fi

upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
if [[ -z "$upstream" ]]; then
    printf 'Branch %s must have a remote upstream; push it before releasing.\n' "$branch" >&2
    exit 1
fi

remote="${upstream%%/*}"
ahead_behind="$(git rev-list --left-right --count "HEAD...$upstream")"
if [[ "$ahead_behind" != $'0\t0' ]]; then
    printf 'The current branch must be fully pushed and up to date with %s.\n' "$upstream" >&2
    exit 1
fi

commit="$(git rev-parse HEAD)"
if git show-ref --verify --quiet "refs/tags/$tag"; then
    printf 'Tag already exists locally: %s\n' "$tag" >&2
    exit 1
fi
if [[ -n "$(git ls-remote --tags "$remote" "refs/tags/$tag" "refs/tags/$tag^{}")" ]]; then
    printf 'Tag already exists on remote %s: %s\n' "$remote" "$tag" >&2
    exit 1
fi

if ! $DRY_RUN; then
    gh auth status
fi

printf 'Release: %s\nCommit:  %s\n' "$tag" "$commit"
cmake -S "$ROOT_DIR" -B "$BUILD_DIR"
cmake --build "$BUILD_DIR"
ctest --test-dir "$BUILD_DIR" --output-on-failure

archive_name="SubSolarWorldMap-$version"
release_dir="$BUILD_DIR/releases"
archive_path="$release_dir/$archive_name.tar.gz"
checksum_path="$archive_path.sha256"
mkdir -p "$release_dir"
if [[ -e "$archive_path" || -e "$checksum_path" ]]; then
    printf 'Release artifact already exists; move it before retrying:\n%s\n' "$archive_path" >&2
    exit 1
fi

git archive --format=tar.gz --prefix="$archive_name/" --output="$archive_path" "$commit"
(
    cd "$release_dir"
    sha256sum "$archive_name.tar.gz" > "$archive_name.tar.gz.sha256"
)
printf 'Created source archive: %s\n' "$archive_path"
printf 'Created checksum:       %s\n' "$checksum_path"

if $DRY_RUN; then
    printf 'Dry run: not creating tag or GitHub Release.\n'
    exit 0
fi

release_title="SubSolar World Map $tag"
release_notes="$(cat <<'NOTES'
SubSolar World Map is a KDE Plasma 6 widget showing the current day and night
regions across Earth, with a live clock and configurable location pins.

Highlights:
- Follow the Sun's position and the moving day/night boundary.
- Use automatic location, choose a catalog city, or enter coordinates for Home.
- Search an alphabetized, deduplicated city catalog and add city pins.
- Customize pin colors, opacity, and city marker shape.
- Configure the clock display and formatting.

To install, download and extract the source archive, then run
`./deploy.sh --restart-shell` from the extracted project directory. This builds
the Qt plugin for your system and installs the widget for your Plasma user.
See the README for build dependencies and details.
NOTES
)"

printf '\nProposed release title: %s\n' "$release_title"
printf 'Enter a different title, or press Enter to keep it: '
IFS= read -r title_input
if [[ -n "$title_input" ]]; then
    release_title="$title_input"
fi

printf '\nProposed release description:\n\n%s\n\n' "$release_notes"
printf 'Use these notes [Y], edit them [e], or cancel [N]? '
IFS= read -r notes_choice
case "$notes_choice" in
    ""|[Yy])
        ;;
    [Ee])
        printf 'Enter replacement notes; finish with a single dot (.) on its own line:\n'
        release_notes=""
        while IFS= read -r line; do
            [[ "$line" == "." ]] && break
            release_notes+="$line"$'\n'
        done
        if [[ -z "${release_notes//[$'\n\r\t ']/}" ]]; then
            printf 'Release description cannot be empty.\n' >&2
            exit 1
        fi
        ;;
    *)
        printf 'Release cancelled.\n'
        exit 1
        ;;
esac

printf '\nReady to publish:\nTag:   %s\nTitle: %s\n\n%s\n\n' "$tag" "$release_title" "$release_notes"
printf 'Type "publish" to create the tag and GitHub Release: '
IFS= read -r confirmation
if [[ "$confirmation" != "publish" ]]; then
    printf 'Release cancelled. The local archive and checksum were kept.\n'
    exit 1
fi

gh release create "$tag" "$archive_path" "$checksum_path" \
    --target "$commit" \
    --title "$release_title" \
    --notes "$release_notes"

printf '\nPublished %s from commit %s.\n' "$tag" "$commit"
