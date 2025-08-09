#!/bin/bash
set -euo pipefail

# Usage: ./notarize_plugin.sh /absolute/path/to/Your.plugin

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") /path/to/Your.plugin" >&2
  exit 1
fi

input_path="$1"

if [[ ! -d "$input_path" || "${input_path##*.}" != "plugin" ]]; then
  echo "Error: argument must be a .plugin directory" >&2
  exit 1
fi

# Resolve absolute paths for reliability without relying on realpath
input_dir_abs="$(cd "$(dirname "$input_path")" && pwd)/$(basename "$input_path")"
parent_dir="$(cd "$(dirname "$input_dir_abs")" && pwd)"

# Extract base name (with extension) from the plugin directory
base_name="$(basename "$input_dir_abs")"
zip_path="$parent_dir/${base_name}.zip"

echo "Removing existing zip (if any): $zip_path ..."
rm -f "$zip_path"

# Zip the plugin bundle from its parent directory so the zip root is the bundle itself
echo "Compressing $base_name into $zip_path ..."
(
  cd "$parent_dir"
  zip -r "$zip_path" "$base_name"
)

echo "Submitting $zip_path for notarization ..."
xcrun notarytool submit "$zip_path" --keychain-profile gabgren --wait

echo "Stapling notarization to $input_dir_abs ..."
xcrun stapler staple "$input_dir_abs"

echo "Cleaning up zip ..."
rm -f "$zip_path"

echo "Notarization complete. Stapled plugin is at: $input_dir_abs"