#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
package_dir="$script_dir/../swift"
release_dir="$script_dir/.."
temp_root=${TMPDIR:-/tmp}
scratch_dir=$(mktemp -d "${temp_root%/}/shipyardkit-swift-tests.XXXXXX")

cleanup() {
  rm -rf "$scratch_dir"
}

trap cleanup EXIT HUP INT TERM

release_version=$(tr -d '[:space:]' < "$release_dir/VERSION")
source_version=$(sed -n 's/.*public static let sdkVersion = "\([^"]*\)".*/\1/p' \
  "$package_dir/Sources/ShipyardKit/ShipyardClient.swift")

if [ -z "$release_version" ] || [ "$release_version" != "$source_version" ]; then
  echo "ShipyardKit VERSION ($release_version) does not match ShipyardClient.sdkVersion ($source_version)." >&2
  exit 1
fi

if grep -R -n -E '(^|[[:space:]])import[[:space:]]+Security([[:space:]]|$)|SecItem[A-Za-z]*' \
  "$package_dir/Sources"; then
  echo "ShipyardKit must not import Security or call SecItem APIs." >&2
  exit 1
fi

swift test \
  --package-path "$package_dir" \
  --scratch-path "$scratch_dir" \
  "$@"
