#!/usr/bin/env bash
set -euo pipefail

# execute-update-script.sh
#
# Usage:
#   execute-update-script.sh <package-attr-path> [-- <command> [args...]]
#
# If a command is provided after "--", the script will execute that command.
# Otherwise it will attempt to fetch the package's `updateScript` via `nix eval`
# and execute it. Supports updateScript forms:
#   - string
#   - array
#   - object with "command" (string or array)
#
# Special handling for `nix-update`:
#   - Normalize store-path nix-update (/nix/store/.../bin/nix-update) to "nix-update"
#   - Preserve flag-like args (starting with '-' or containing '=')
#   - Ensure `--flake` is present (add if missing)
#   - Append the package attribute path as the last positional argument
#
# Dependencies: `nix`, `jq` present in PATH (workflow installs these before calling).
#
# Exit codes:
#   0 - executed command finished successfully
#   2 - usage / missing args / invalid updateScript format
#   3 - nix eval failed to fetch updateScript

usage() {
  cat <<EOF >&2
Usage: $0 <package-attr-path> [-- <command> [args...]]
Examples:
  $0 mypkg
  $0 mypkg -- nix-update --no-edit
EOF
  exit 2
}

if [ "$#" -lt 1 ]; then
  usage
fi

PACKAGE="$1"
shift || true

# If caller provided "-- <command...>" then we use explicit command
if [ "$#" -ge 1 ]; then
  if [ "$1" != "--" ]; then
    usage
  fi
  shift
  if [ "$#" -lt 1 ]; then
    echo "No command specified after --" >&2
    usage
  fi

  # Build command array from remaining args
  declare -a script_array=()
  while [ "$#" -gt 0 ]; do
    script_array+=("$1")
    shift
  done

else
  # No explicit command provided: fetch updateScript via nix
  # Ensure FLAKE_REF fallback
  : "${FLAKE_REF:=path:${GITHUB_WORKSPACE:-$PWD}}"

  # Attempt to read updateScript from the flake's legacyPackages
  set +e
  script_json=$(nix eval --impure --json --expr "
    let
      f = builtins.getFlake (builtins.getEnv \"FLAKE_REF\");
      sys = \"x86_64-linux\";
      lp = builtins.getAttr sys f.legacyPackages;
      pkgsN = import <nixpkgs> {};
      lib = pkgsN.lib;
      path = lib.strings.splitString \".\" \"${PACKAGE}\";
      pkg = lib.attrsets.attrByPath path null lp;
    in
      if pkg == null then throw \"no pkg\"
      else if (pkg ? passthru && pkg.passthru ? updateScript) then pkg.passthru.updateScript
      else if (pkg ? updateScript) then pkg.updateScript
      else throw \"no updateScript\"
  " 2>&1)
  ret=$?
  set -e

  if [ $ret -ne 0 ]; then
    echo "Failed to fetch updateScript for ${PACKAGE} (nix eval exit ${ret})" >&2
    echo "nix eval output:" >&2
    echo "$script_json" >&2
    exit 3
  fi

  # Determine type
  script_type=$(echo "$script_json" | jq -r 'type' 2>/dev/null || echo "null")

  # Convert script_json to bash array in script_array
  case "$script_type" in
    array)
      # each element is a string element of command
      mapfile -t script_array < <(echo "$script_json" | jq -r '.[]')
      ;;
    string)
      # split string into words (like original behavior)
      command_str=$(echo "$script_json" | jq -r '.')
      # shell-splitting: preserve sane splitting; avoid word-splitting surprises by using read -a
      read -r -a script_array <<< "$command_str"
      ;;
    object)
      # require "command" field
      if echo "$script_json" | jq -e 'has("command")' >/dev/null 2>&1; then
        cmdtype=$(echo "$script_json" | jq -r '.command | type')
        if [ "$cmdtype" = "array" ]; then
          mapfile -t script_array < <(echo "$script_json" | jq -r '.command[]')
        elif [ "$cmdtype" = "string" ]; then
          command_str=$(echo "$script_json" | jq -r '.command')
          read -r -a script_array <<< "$command_str"
        else
          echo "Unsupported command type in updateScript object: $cmdtype" >&2
          exit 2
        fi
      else
        echo "updateScript object for ${PACKAGE} does not contain a 'command' field" >&2
        exit 2
      fi
      ;;
    *)
      echo "Unsupported updateScript type: ${script_type}" >&2
      echo "Raw updateScript JSON: $script_json" >&2
      exit 2
      ;;
  esac
fi

# At this point we must have script_array assembled
if [ "${#script_array[@]}" -eq 0 ]; then
  echo "No command to execute for package ${PACKAGE}" >&2
  exit 2
fi

# Normalize store-path nix-update (/nix/store/.../bin/nix-update) to "nix-update"
cmd="${script_array[0]}"
if [[ "$cmd" =~ ^/nix/store/.*/bin/nix-update$ ]]; then
  script_array[0]="nix-update"
  cmd="nix-update"
fi

if [ "$cmd" = "nix-update" ]; then
  # Rebuild nix-update invocation:
  new_command=( "nix-update" )
  has_flake=0

  for ((i=1;i<${#script_array[@]};i++)); do
    arg="${script_array[$i]}"
    if [ "$arg" = "--flake" ]; then
      has_flake=1
    fi
    if [[ "$arg" == -* || "$arg" == *=* ]]; then
      new_command+=("$arg")
    fi
  done

  if [ "$has_flake" -eq 0 ]; then
    new_command+=( "--flake" )
  fi

  # append full package attribute path
  new_command+=( "$PACKAGE" )

  echo "Normalized nix-update invocation: ${new_command[*]}"
  exec "${new_command[@]}"
else
  # Execute the command as-is
  echo "Executing command: ${script_array[*]}"
  exec "${script_array[@]}"
fi
