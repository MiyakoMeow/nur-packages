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
    APP_DIR="@out@/share/pbmsc"
    USER_DATA="''${XDG_DATA_HOME:-$HOME/.local/share}/pbmsc"
    CONFIG="$USER_DATA/pBMSC.exe.config"
    mkdir -p "$USER_DATA"
    if [ ! -e "$CONFIG" ]; then
      if [ -f "$APP_DIR/pBMSC.exe.config" ]; then
        cp "$APP_DIR/pBMSC.exe.config" "$CONFIG"
      else
        touch "$CONFIG"
      fi
    fi
    RUNTIME_DIR=$(mktemp -d -t pbmsc-XXXXXX)
    cleanup() { rm -rf "$RUNTIME_DIR"; }
    trap cleanup EXIT
    cp -r "$APP_DIR"/. "$RUNTIME_DIR"/
    chmod -R u+rwX "$RUNTIME_DIR"
    rm -f "$RUNTIME_DIR/pBMSC.exe.config"
    ln -s "$CONFIG" "$RUNTIME_DIR/pBMSC.exe.config"
    cd "$RUNTIME_DIR"
    export WINEDEBUG=-all
    export WINEARCH=win64
    export WINEPREFIX="$RUNTIME_DIR/wineprefix"
    export WINEDLLOVERRIDES="mscoree,mshtml=d"
    # 初始化前缀并安装 wine-mono（每次启动确保存在）
    MONO_DIR="${wineWowPackages.full}/share/wine/mono"
    MONO_MSI=$(ls "$MONO_DIR"/wine-mono-*.msi 2>/dev/null | head -n1 || true)
    if [ -n "$MONO_MSI" ]; then
      "${wineWowPackages.full}/bin/wine" msiexec /i "$MONO_MSI" /qn || true
    fi
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
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
