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
  pname = "mbmconfig";
  version = "3.24.0824.0";

  src = fetchurl {
    url = "https://mistyblue.info/php/dl.php?file=mbmconfig_3240824_0_x64.zip";
    sha256 = "707b8f82433234d586114080a8f00ff9920f0bb885574b17f38e5ba05f4235a3";
  };

  dontUnpack = true;
  dontBuild = true;
  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
    p7zip
  ];

  installPhase = ''
    install -dm755 $out/share/mbmconfig
    7z x -y -o"$out/share/mbmconfig" "$src"
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
    done < <(find "$out/share/mbmconfig" -depth -print0)

    chmod -R u+rwX,go+rX $out/share/mbmconfig

    install -dm755 $out/bin

    install -Dm555 /dev/stdin $out/bin/mbmconfig <<'EOF'
    #!/usr/bin/env bash
    set -euo pipefail
    APP_ROOT="@out@/share/mbmconfig"
    APP_DIR="$APP_ROOT/mBMconfig"
    USER_DATA="''${XDG_DATA_HOME:-$HOME/.local/share}/mbmconfig"
    CONFIG="$USER_DATA/mBMconfig.exe.config"
    mkdir -p "$USER_DATA"
    if [ ! -e "$CONFIG" ]; then
      if [ -f "$APP_DIR/mBMconfig.exe.config" ]; then
        cp "$APP_DIR/mBMconfig.exe.config" "$CONFIG"
      else
        touch "$CONFIG"
      fi
    fi
    RUNTIME_DIR=$(mktemp -d -t mbmconfig-XXXXXX)
    cleanup() { rm -rf "$RUNTIME_DIR"; }
    trap cleanup EXIT
    cp -r "$APP_DIR"/. "$RUNTIME_DIR"/
    if [ -d "$APP_ROOT/mbmconfig_files" ]; then
      cp -r "$APP_ROOT/mbmconfig_files"/* "$RUNTIME_DIR"/
    fi
    chmod -R u+rwX "$RUNTIME_DIR"
    rm -f "$RUNTIME_DIR/mBMconfig.exe.config"
    ln -s "$CONFIG" "$RUNTIME_DIR/mBMconfig.exe.config"
    if [ -d "$RUNTIME_DIR/mbmconfig_files/dll" ]; then
      cp -n "$RUNTIME_DIR/mbmconfig_files/dll"/*.dll "$RUNTIME_DIR"/ || true
    fi
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
    exec "${wineWowPackages.full}/bin/wine" "mBMconfig.exe" "$@"
    EOF
    substituteInPlace $out/bin/mbmconfig --replace "@out@" "$out"
  '';

  # Desktop item will be connected by consumer overlay; define here
  desktopItems = [
    (makeDesktopItem {
      name = pname;
      desktopName = "mBMconfig";
      exec = pname;
      comment = "mBMplay GUI configuration tool (runs via Wine)";
      categories = [
        "AudioVideo"
        "Audio"
        "Settings"
      ];
      terminal = false;
      keywords = [
        "BMS"
        "mBMplay"
        "Configuration"
        "Settings"
      ];
      startupWMClass = "mBMconfig";
      icon = "wine";
    })
  ];

  propagatedBuildInputs = [ wineWowPackages.full ];

  meta = with lib; {
    description = "mBMconfig - GUI configuration tool for mBMplay (runs via Wine)";
    homepage = "https://mistyblue.info";
    license = licenses.mit;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
