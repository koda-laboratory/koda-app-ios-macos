#!/bin/sh

set -eu

script_directory=$(CDPATH= cd "$(dirname "$0")" && pwd)
version_path="$script_directory/../Configuration/version.xcconfig"

current_build=$("$script_directory/get_build_version.sh")

case "$current_build" in
    ""|*[!0-9]*)
        echo "CURRENT_PROJECT_VERSION must be a positive integer in $version_path" >&2
        exit 1
        ;;
esac

next_build=$((current_build + 1))
temporary_path=$(mktemp "$version_path.tmp.XXXXXX")
trap 'rm -f "$temporary_path"' EXIT HUP INT TERM

awk -v next_build="$next_build" '
    BEGIN { updated = 0 }
    {
        if (!updated && $0 ~ /^[[:space:]]*CURRENT_PROJECT_VERSION[[:space:]]*=/) {
            line = $0
            if (match(line, /[0-9]+[[:space:]]*$/)) {
                line = substr(line, 1, RSTART - 1) next_build substr(line, RSTART + RLENGTH)
                print line
                updated = 1
                next
            }
        }
        print
    }
    END {
        if (!updated) {
            exit 2
        }
    }
' "$version_path" > "$temporary_path"

mv "$temporary_path" "$version_path"
chmod 0644 "$version_path"
trap - EXIT HUP INT TERM

printf 'Bumped CURRENT_PROJECT_VERSION to %s\n' "$next_build"
