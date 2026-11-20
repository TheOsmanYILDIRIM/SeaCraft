#!/usr/bin/env bash
set -euo pipefail

# GUT 9.7.1 official tag v9.7.1 points at this immutable commit and targets Godot 4.7.
GUT_COMMIT="aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605"
ARCHIVE_URL="https://github.com/bitwes/Gut/archive/${GUT_COMMIT}.tar.gz"

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

curl --fail --location --retry 3 --output "$work_dir/gut.tar.gz" "$ARCHIVE_URL"
tar -xzf "$work_dir/gut.tar.gz" -C "$work_dir"
mkdir -p addons
rm -rf addons/gut
cp -R "$work_dir/Gut-${GUT_COMMIT}/addons/gut" addons/gut

printf 'Installed GUT at commit %s\n' "$GUT_COMMIT"
