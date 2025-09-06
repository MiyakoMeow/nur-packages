#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get the latest version using the Python script
latest_version=$(python3 "$SCRIPT_DIR/update_version.py")

echo "Latest version found: $latest_version"

# Update the package using nix-update
# We need to be in the nur-packages directory for nix-update to work properly
cd "$SCRIPT_DIR/../../../../"

# Run nix-update with the new version using nix run
nix run nixpkgs#nix-update -- free-download-manager --version "$latest_version"

echo "Package updated to version $latest_version"
