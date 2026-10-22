#!/bin/sh

set -eu

script_directory=$(CDPATH= cd "$(dirname "$0")" && pwd)
version_path="$script_directory/../Configuration/version.xcconfig"

build_version=$(awk -F '=' '
    /^[[:space:]]*CURRENT_PROJECT_VERSION[[:space:]]*=/ {
        value = $2
        gsub(/[[:space:]]/, "", value)
        print value
        exit
    }
' "$version_path")

if [ -z "$build_version" ]; then
    echo "CURRENT_PROJECT_VERSION is missing from $version_path" >&2
    exit 1
fi

printf '%s\n' "$build_version"
