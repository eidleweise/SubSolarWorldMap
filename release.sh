#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
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

for command in cmake ctest git jq sha256sum; do
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

printf '\nThis will create remote tag %s and publish a GitHub Release. Continue? [y/N] ' "$tag"
read -r confirmation
if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
    printf 'Release cancelled. The local archive and checksum were kept.\n'
    exit 1
fi

gh release create "$tag" "$archive_path" "$checksum_path" \
    --target "$commit" \
    --title "$tag" \
    --generate-notes

printf '\nPublished %s from commit %s.\n' "$tag" "$commit"
