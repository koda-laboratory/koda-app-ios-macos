#!/bin/sh

set -eu

script_directory=$(CDPATH= cd "$(dirname "$0")" && pwd)
version_path="$script_directory/../Configuration/version.xcconfig"

marketing_version=$(awk -F '=' '
    /^[[:space:]]*MARKETING_VERSION[[:space:]]*=/ {
        value = $2
        gsub(/[[:space:]]/, "", value)
        print value
        exit
    }
' "$version_path")

if [ -z "$marketing_version" ]; then
    echo "MARKETING_VERSION is missing from $version_path" >&2
    exit 1
fi

printf '%s\n' "$marketing_version"
