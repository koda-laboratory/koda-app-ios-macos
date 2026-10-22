#!/bin/sh

set -eu

SCRIPT_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(dirname "$SCRIPT_DIRECTORY")

git -C "$REPOSITORY_ROOT" config --local core.hooksPath .githooks
echo "Git hooks enabled from .githooks."
