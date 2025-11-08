#!/usr/bin/env bash
set -euo pipefail

# execute-update-command.sh
#
# Extracted from the `update-package` workflow step.
#
# Purpose:
#   Normalize and execute an update command that was originally provided
#   by a package's `updateScript` (from nixpkgs). The original logic
#   special-cased `nix-update` invocations so we replicate that behavior:
#     - Normalize store-path nix-update to plain "nix-update"
#     - Preserve flag-style arguments (starting with '-' or containing '=')
#     - Ensure a `--flake` flag is present (add it if missing)
#     - Append the full attribute path (package) as the last positional argument
#
# Usage:
#   execute-update-command.sh <package-attr-path> -- <command> [args...]
#
# Examples:
#   execute-update-command.sh nixpkgs.foo.bar -- nix-update --some-flag
#   execute-update-command.sh mypkg -- /nix/store/abcd.../bin/nix-update --foo=bar
#   execute-update-command.sh mypkg -- python3 update.py arg1 arg2
#
# Notes:
#  - The script expects the caller to split a command string into argv; it
#    does not parse JSON. This matches how the original function received
#    the command array in the workflow (via Bash arrays).
#  - The environment should already have any required tools installed
#    (e.g. nix-update, python, etc.). The workflow installs dependencies earlier.
#  - If the command is `nix-update` (or a store path ending in /bin/nix-update),
#    the script will rebuild the invocation as described above.
#
# Exit codes:
#  - Exit status is the same as the executed command.
#  - The script exits with non-zero for usage errors.

if [ "$#" -lt 3 ]; then
  cat >&2 <<EOF
Usage: $0 <package-attr-path> -- <command> [args...]
Example: $0 mypkg -- nix-update --flake --no-edit
EOF
  exit 2
fi

PACKAGE="$1"
shift

# Expect a literal separator "--"
if [ "$1" != "--" ]; then
  echo "Missing '--' separator before command arguments" >&2
  echo "Usage: $0 <package-attr-path> -- <command> [args...]" >&2
  exit 2
fi
shift

# Remaining args form the command array
if [ "$#" -lt 1 ]; then
  echo "No command specified" >&2
  exit 2
fi

# Convert remaining positional args into an array
declare -a script_array=()
while [ "$#" -gt 0 ]; do
  script_array+=("$1")
  shift
done

cmd="${script_array[0]}"

# Detect store-path nix-update: "/nix/store/.../bin/nix-update"
if [[ "$cmd" =~ ^/nix/store/.*/bin/nix-update$ ]]; then
  # Normalize to "nix-update"
  script_array[0]="nix-update"
  cmd="nix-update"
fi

# If the command is nix-update, rewrite invocation
if [ "$cmd" = "nix-update" ]; then
  new_command=("nix-update")
  has_flake=0

  # Preserve flags (starting with '-' or containing '='); drop positional args.
  # Also detect explicit --flake presence.
  for ((i=1; i<${#script_array[@]}; i++)); do
    arg="${script_array[$i]}"
    if [ "$arg" = "--flake" ]; then
      has_flake=1
    fi
    if [[ "$arg" == -* || "$arg" == *=* ]]; then
      new_command+=("$arg")
    fi
  done

  if [ "$has_flake" -eq 0 ]; then
    new_command+=("--flake")
  fi

  new_command+=("$PACKAGE")

  echo "Normalized nix-update invocation: ${new_command[*]}"
  exec "${new_command[@]}"
else
  # Non-nix-update command: execute as-is
  echo "Executing command: ${script_array[*]}"
  exec "${script_array[@]}"
fi
