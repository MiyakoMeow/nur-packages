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
  pname = "mbmplayer";
  version = "3.24.0824.1";

  src = fetchurl {
    url = "https://mistyblue.info/php/dl.php?file=mbmplay_3240824_1_x64.zip";
    sha256 = "0xingp3xpkb0wdsn2iwphskgg179vi45a8cr7yl3dznp3vxklxmz";
  };

  dontUnpack = true;
  dontBuild = true;
  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
    p7zip
  ];

  installPhase = ''
    install -dm755 $out/share/mbmplayer
    7z x -y -o"$out/share/mbmplayer" "$src"
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
    done < <(find "$out/share/mbmplayer" -depth -print0)

    chmod -R u+rwX,go+rX $out/share/mbmplayer

    install -dm755 $out/bin

    install -Dm555 /dev/stdin $out/bin/mbmplayer <<'EOF'
    #!/usr/bin/env bash
    set -euo pipefail
    APP_ROOT="@out@/share/mbmplayer"
    APP_DIR="$APP_ROOT/mBMplay"
    USER_DATA="''${XDG_DATA_HOME:-$HOME/.local/share}/mbmplay"
    mkdir -p "$USER_DATA"

    RUNTIME_DIR=$(mktemp -d -t mbmplay-XXXXXX)
    cleanup() { rm -rf "$RUNTIME_DIR"; }
    trap cleanup EXIT

    cp -r "$APP_DIR"/. "$RUNTIME_DIR"/
    if [ -d "$APP_ROOT/mbmconfig_files" ]; then
      cp -r "$APP_ROOT/mbmconfig_files"/* "$RUNTIME_DIR"/ || true
    fi
    chmod -R u+rwX "$RUNTIME_DIR"

    cd "$RUNTIME_DIR"
    export WINEDEBUG=-all
    export WINEARCH=win64
    export WINEPREFIX="$RUNTIME_DIR/wineprefix"

    # 提供快速烟雾测试：仅验证脚本与目录准备是否正常
    if [ "''${MBMPLAYER_SMOKE:-}" = "1" ]; then
      echo "mbmplayer smoke-ok"
      exit 0
    fi

    # 先禁用内置 mscoree/mshtml 以便安装 wine-mono
    export WINEDLLOVERRIDES="mscoree,mshtml=d"

    # 初始化前缀并安装 wine-mono（每次启动确保存在）
    MONO_DIR="${wineWowPackages.full}/share/wine/mono"
    MONO_MSI=$(ls "$MONO_DIR"/wine-mono-*.msi 2>/dev/null | head -n1 || true)
    if [ -n "$MONO_MSI" ]; then
      "${wineWowPackages.full}/bin/wine" msiexec /i "$MONO_MSI" /qn || true
    fi

    # 允许 mshtml，避免影响程序内嵌浏览器行为
    export WINEDLLOVERRIDES="mshtml="

    exec "${wineWowPackages.full}/bin/wine" "mBMplay.exe" "$@"
    EOF
    substituteInPlace $out/bin/mbmplayer --replace "@out@" "$out"
  '';

  desktopItems = [
    (makeDesktopItem {
      name = pname;
      desktopName = "mBMplay";
      exec = pname;
      comment = "mBMplay - BMS 播放器 (Wine)";
      categories = [
        "Game"
        "AudioVideo"
        "Audio"
      ];
      terminal = false;
      keywords = [
        "BMS"
        "mBMplay"
        "Player"
      ];
      startupWMClass = "mBMplay";
      icon = "wine";
    })
  ];

  propagatedBuildInputs = [ wineWowPackages.full ];

  meta = with lib; {
    description = "mBMplay - BMS 播放器 (通过 Wine 运行)";
    homepage = "https://mistyblue.info";
    license = licenses.mit;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
