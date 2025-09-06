#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get the latest version using the Python script with required dependencies
latest_version=$(nix shell nixpkgs#python312Packages.requests nixpkgs#python312Packages.beautifulsoup4 --command python3 "$SCRIPT_DIR/update_version.py")

echo "Latest version found: $latest_version"

# Update the package using nix-update
# We need to be in the nur-packages directory for nix-update to work properly
cd "$SCRIPT_DIR/../../../../"

# Run nix-update with the new version using nix run
nix run nixpkgs#nix-update -- free-download-manager --version "$latest_version"

echo "Package updated to version $latest_version"
