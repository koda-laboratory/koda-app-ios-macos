#!/bin/sh

# Lints Koda/, KodaWidgets/ and KodaTests/ with .swiftlint.yml. Also run by the Koda target's "SwiftLint" build phase
# ("${SRCROOT}/scripts/swiftlint.sh", SRCROOT being the repository root).

set -eu

SCRIPT_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(dirname "$SCRIPT_DIRECTORY")

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

if ! command -v swiftlint >/dev/null 2>&1; then
    echo "error: SwiftLint is not installed. Run 'brew bundle' from $REPOSITORY_ROOT." >&2
    exit 1
fi

cd "$REPOSITORY_ROOT"
exec swiftlint lint --no-cache --config "$REPOSITORY_ROOT/.swiftlint.yml"
