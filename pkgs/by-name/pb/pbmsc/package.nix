{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  p7zip,
  wineWowPackages,
}:

stdenvNoCC.mkDerivation rec {
  pname = "pbmsc";
  version = "3.5.5.16";

  src = fetchurl {
    url = "https://github.com/psyk2642/iBMSC/releases/download/pBMSC-3.5.5.16/pBMSC.3.5.5.16.zip";
    sha256 = "1b1y123kqr60x7xs6g8bc1c3xp1hsdjdji8hxfac7qjm8rn0andf";
  };

  dontUnpack = true;
  dontBuild = true;
  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
    p7zip
  ];

  installPhase = ''
    install -dm755 $out/share/pbmsc
    7z x -y -o"$out/share/pbmsc" "$src"
    # 修正反斜杠为目录分隔符
    while IFS= read -r -d $'\0' p; do
      case "$p" in
        *\\*)
          target="''${p//\\\\//}"
          if [ "$p" != "$target" ]; then
            mkdir -p "$(dirname "$target")"
            mv -f "$p" "$target"
          fi
        ;;
      esac
    done < <(find "$out/share/pbmsc" -depth -print0)

    chmod -R u+rwX,go+rX $out/share/pbmsc

    install -dm755 $out/bin

    install -Dm555 /dev/stdin $out/bin/pbmsc <<'EOF'
    #!/usr/bin/env bash
    set -euo pipefail

    APP_ROOT="@out@/share/pbmsc"
    APP_DIR="$APP_ROOT"
    BASE_DATA_DIR="$(printenv XDG_DATA_HOME)"
    [ -n "$BASE_DATA_DIR" ] || BASE_DATA_DIR="$HOME/.local/share"
    USER_DATA="$BASE_DATA_DIR/pbmsc"

    mkdir -p "$USER_DATA"

    # Initialize user data directories from app content if missing
    for dir in "$APP_DIR"/*/; do
      [ -d "$dir" ] || continue
      name="$(basename "$dir")"
      if [ ! -d "$USER_DATA/$name" ]; then
        cp -r --no-preserve=all "$dir" "$USER_DATA/$name"
      fi
    done

    # Ensure base config file exists if provided by app
    if [ -f "$APP_DIR/pBMSC.exe.config" ] && [ ! -f "$USER_DATA/pBMSC.exe.config" ]; then
      cp "$APP_DIR/pBMSC.exe.config" "$USER_DATA/pBMSC.exe.config"
    fi

    RUNTIME_DIR=$(mktemp -d -t pbmsc.XXXXXX)

    cleanup() {
      # Sync new top-level directories back to user data
      find "$RUNTIME_DIR" -mindepth 1 -maxdepth 1 -type d ! -name wineprefix | while read -r d; do
        name="$(basename "$d")"
        if [ ! -e "$USER_DATA/$name" ]; then
          cp -r --no-preserve=all "$d" "$USER_DATA/$name"
        fi
      done
      # Sync top-level files back to user data
      find "$RUNTIME_DIR" -mindepth 1 -maxdepth 1 -type f -print0 | xargs -0 -I{} cp -f "{}" "$USER_DATA/" 2>/dev/null || true
      rm -rf "$RUNTIME_DIR"
    }
    trap cleanup EXIT

    # Prepare runtime with app files
    cp -r "$APP_DIR"/. "$RUNTIME_DIR"/
    chmod -R u+rwX "$RUNTIME_DIR"

    # Link user data into runtime (files and directories)
    while IFS= read -r -d $'\0' f; do
      base="$(basename "$f")"
      [ -d "$RUNTIME_DIR/$base" ] && rm -rf "$RUNTIME_DIR/$base"
      ln -sf "$f" "$RUNTIME_DIR/$base"
    done < <(find "$USER_DATA" -mindepth 1 -maxdepth 1 -type f -print0)
    while IFS= read -r -d $'\0' d; do
      name="$(basename "$d")"
      [ -e "$RUNTIME_DIR/$name" ] && rm -rf "$RUNTIME_DIR/$name"
      ln -sfT "$d" "$RUNTIME_DIR/$name"
    done < <(find "$USER_DATA" -mindepth 1 -maxdepth 1 -type d -print0)

    cd "$RUNTIME_DIR"
    export WINEDEBUG=-all
    export WINEARCH=win64
    export WINEPREFIX="$RUNTIME_DIR/wineprefix"

    # Disable builtin mscoree/mshtml to allow Wine Mono installation
    export WINEDLLOVERRIDES="mscoree,mshtml=d"
    MONO_DIR="${wineWowPackages.full}/share/wine/mono"
    MONO_MSI=$(ls "$MONO_DIR"/wine-mono-*.msi 2>/dev/null | head -n1 || true)
    if [ -n "$MONO_MSI" ]; then
      "${wineWowPackages.full}/bin/wine" msiexec /i "$MONO_MSI" /qn || true
    fi
    # Re-enable mshtml
    export WINEDLLOVERRIDES="mshtml="

    exec "${wineWowPackages.full}/bin/wine" "pBMSC.exe" "$@"
    EOF
    substituteInPlace $out/bin/pbmsc --replace "@out@" "$out"
  '';

  # Desktop item will be connected by consumer overlay; define here
  desktopItems = [
    (makeDesktopItem {
      name = pname;
      desktopName = "pBMSC";
      exec = pname;
      comment = "iBMSC/pBMSC chart editor (runs via Wine)";
      categories = [
        "AudioVideo"
        "Audio"
      ];
      terminal = false;
      keywords = [
        "BMS"
        "Chart"
        "Editor"
      ];
      startupWMClass = "pBMSC";
      icon = "wine";
    })
  ];

  propagatedBuildInputs = [ wineWowPackages.full ];

  meta = with lib; {
    description = "pBMSC (iBMSC Windows build) packaged to run with Wine";
    homepage = "https://github.com/psyk2642/iBMSC";
    license = licenses.unfreeRedistributable;
    maintainers = [ ];
    platforms = with lib.platforms; x86_64;
    mainProgram = pname;
  };
}
