#!/bin/sh

# Resumable wrapper around `fastlane ios pipeline_build_upload` and `fastlane mac pipeline_build_upload`.
# It bumps the build number in Configuration/version.xcconfig once, uploads the iOS and macOS builds to
# TestFlight with that same number (retrying with --resume keeps it and skips the platform that already
# succeeded), and commits the version file only after both uploads were accepted.

set -eu

script_directory=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "$script_directory/.." && pwd)
state_directory="$repo_root/.build/fastlane"
state_file="$state_directory/testflight-release.state"
version_file="Configuration/version.xcconfig"

usage() {
  printf 'Usage: %s [--resume]\n' "$0"
  printf '  Build Koda for iOS and macOS and distribute both to the TestFlight internal group.\n'
  printf '  A normal run bumps the build number and supersedes any pending local release state.\n'
  printf '  Use --resume only to retry the pending upload for the same build number.\n'
}

resume=0
case "${1:-}" in
  "") ;;
  --resume)
    [ "$#" -eq 1 ] || {
      usage >&2
      exit 2
    }
    resume=1
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

write_state() {
  state_temporary_file=$(mktemp "$state_file.tmp.XXXXXX")
  {
    printf 'build_number=%s\n' "$build_number"
    printf 'ios_uploaded=%s\n' "$ios_uploaded"
    printf 'mac_uploaded=%s\n' "$mac_uploaded"
  } > "$state_temporary_file"
  mv "$state_temporary_file" "$state_file"
}

read_state() {
  build_number=
  ios_uploaded=0
  mac_uploaded=0
  while IFS='=' read -r key value; do
    case "$key" in
      build_number) build_number=$value ;;
      ios_uploaded) ios_uploaded=$value ;;
      mac_uploaded) mac_uploaded=$value ;;
      "") ;;
      *) fail "Unexpected entry in $state_file: $key" ;;
    esac
  done < "$state_file"

  case "$build_number" in
    ""|*[!0-9]*) fail "Invalid build number in $state_file" ;;
  esac
}

commit_and_push_version() {
  case "${FASTLANE_COMMIT_AND_PUSH:-false}" in
    [Tt][Rr][Uu][Ee]) ;;
    *)
      printf 'FASTLANE_COMMIT_AND_PUSH is not true; skipping commit and push.\n'
      return
      ;;
  esac

  branch_name=$(git -C "$repo_root" branch --show-current)
  [ -n "$branch_name" ] || fail "Cannot commit the build number from a detached HEAD"

  if ! git -C "$repo_root" diff --quiet HEAD -- "$version_file"; then
    git -C "$repo_root" commit --only \
      -m "chore: bump build to $build_number [skip ci]" \
      -- "$version_file"
  fi

  git -C "$repo_root" push origin "HEAD:$branch_name"
}

run_lane() {
  platform=$1
  printf '\n--- Uploading Koda %s to TestFlight (build %s) ---\n' "$platform" "$build_number"
  (cd "$repo_root" && bundle exec fastlane "$platform" pipeline_build_upload bump_version:false commit_version:false)
}

mkdir -p "$state_directory"

if [ "$resume" -eq 1 ]; then
  [ -f "$state_file" ] || fail "No pending TestFlight release was found to resume"
  read_state
  current_build_number=$("$script_directory/get_build_version.sh")
  [ "$current_build_number" = "$build_number" ] || fail \
    "$version_file is at build $current_build_number but the pending release uses $build_number; restore it before resuming"
else
  if [ -e "$state_file" ]; then
    [ -f "$state_file" ] || fail "Pending release state is not a regular file: $state_file"
    read_state
    printf 'Superseding pending release build %s with a fresh release.\n' "$build_number"
  fi
  "$script_directory/bump_build_version.sh"
  build_number=$("$script_directory/get_build_version.sh")
  ios_uploaded=0
  mac_uploaded=0
  write_state
fi

if [ "$ios_uploaded" != "1" ]; then
  run_lane ios || {
    printf '\niOS pipeline failed. The release state is preserved; rerun with --resume.\n' >&2
    exit 1
  }
  ios_uploaded=1
  write_state
fi

if [ "$mac_uploaded" != "1" ]; then
  run_lane mac || {
    printf '\nmacOS pipeline failed. The release state is preserved; rerun with --resume.\n' >&2
    exit 1
  }
  mac_uploaded=1
  write_state
fi

commit_and_push_version
rm -f "$state_file"
printf '\nKoda build %s was uploaded to TestFlight for iOS and macOS.\n' "$build_number"
