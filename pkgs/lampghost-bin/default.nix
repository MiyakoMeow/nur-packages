{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeDesktopItem,
  copyDesktopItems,
  nix-update-script,
  # Dep
  wine,
  zlib,
  unzip,
  gtk3,
  webkitgtk_4_1,
  glib,
  gdk-pixbuf,
  libsoup_3,
  cairo,
  pango,
  atk,
}: let
  version = "0.2.2.1";

  # 平台特定的源码定义
  srcs = {
    "x86_64-linux" = {
      url = "https://github.com/Catizard/lampghost/releases/download/v${version}/lampghost_linux";
      sha256 = "763e3aa4827df09981b2e071876269015ee21b6e1e46c2166b14a58074bd380c";
      type = "file";
      executable = true;
    };

    "x86_64-darwin" = {
      url = "https://github.com/Catizard/lampghost/releases/download/v${version}/lampghost.app.zip";
      sha256 = "e6a30967be0b334f3dbdd4f8ed9f8250614922d590759d8c176104e48d9c75aa";
      type = "zip";
    };

    "x86_64-windows" = {
      url = "https://github.com/Catizard/lampghost/releases/download/v${version}/lampghost_windows.exe";
      sha256 = "6ea8528bd324d0d2147d8f0f0012a1aa66553f8193cc8adbfeb668b71ab2cd2a";
      type = "file";
    };
  };

  # 获取当前平台配置
  platform = stdenv.hostPlatform.system;
  srcInfo = srcs.${platform} or (throw "Unsupported platform: ${platform}");

  # 桌面图标配置
  desktopItem = makeDesktopItem {
    name = "lampghost";
    exec = "lampghost";
    icon = "lampghost";
    comment = "Offline & Cross-platform beatoraja lamp viewer and more";
    desktopName = "lampghost";
    categories = ["Utility"];
    startupNotify = false;
  };
in
  stdenv.mkDerivation {
    pname = "lampghost-bin";
    inherit version;

    src = fetchurl {
      url = srcInfo.url;
      sha256 = srcInfo.sha256;
    };

    nativeBuildInputs =
      []
      ++ lib.optionals stdenv.isLinux [autoPatchelfHook copyDesktopItems]
      ++ lib.optionals stdenv.isDarwin [unzip]
      ++ lib.optionals (platform == "x86_64-windows") [wine];

    desktopItems = lib.optionals stdenv.isLinux [desktopItem];

    # 所有平台通用设置
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out

      # 平台特定安装逻辑
      ${lib.optionalString stdenv.isLinux ''
        # Linux 安装
        mkdir -p $out/bin
        install -Dm755 $src $out/bin/lampghost
      ''}

      ${lib.optionalString stdenv.isDarwin ''
          # macOS 安装
          unzip $src
          mkdir -p $out/Applications
          cp -R lampghost.app $out/Applications/

          # 创建启动包装器
          mkdir -p $out/bin
          cat > $out/bin/lampghost <<EOF
        #!/bin/sh
        open -n $out/Applications/lampghost.app
        EOF
          chmod +x $out/bin/lampghost
      ''}

      ${lib.optionalString (stdenv.hostPlatform.system == "x86_64-windows") ''
          # Windows 安装 (通过Wine运行)
          mkdir -p $out/bin $out/windows
          install -Dm644 $src $out/windows/lampghost.exe

          # 创建Wine启动脚本
          cat > $out/bin/lampghost <<EOF
        #!/bin/sh
        ${wine}/bin/wine $out/windows/lampghost.exe "\$@"
        EOF
          chmod +x $out/bin/lampghost
      ''}

      runHook postInstall
    '';

    # Linux 二进制可能需要修复
    buildInputs = lib.optionals stdenv.isLinux [
      # 基础依赖
      stdenv.cc.cc.lib
      zlib
      # GTK 相关依赖
      gtk3
      glib
      gdk-pixbuf
      cairo
      pango
      atk
      # WebKitGTK 相关依赖
      webkitgtk_4_1
      libsoup_3
    ];

    passthru = {
      updateScript =
        nix-update-script {
        };
    };

    meta = with lib; {
      description = "Offline & Cross-platform beatoraja lamp viewer and more";
      homepage = "https://github.com/Catizard/lampghost";
      changelog = "https://github.com/Catizard/lampghost/releases/tag/v${version}";
      license = licenses.asl20;
      platforms = builtins.attrNames srcs;
      maintainers = [];
    };
  }
