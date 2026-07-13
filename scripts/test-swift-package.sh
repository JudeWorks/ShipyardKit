#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
package_dir="$script_dir/../swift"
temp_root=${TMPDIR:-/tmp}
scratch_dir=$(mktemp -d "${temp_root%/}/shipyardkit-swift-tests.XXXXXX")

cleanup() {
  rm -rf "$scratch_dir"
}

trap cleanup EXIT HUP INT TERM

swift test \
  --package-path "$package_dir" \
  --scratch-path "$scratch_dir" \
  "$@"
