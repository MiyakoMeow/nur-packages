{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeDesktopItem,
  copyDesktopItems,
  # Dep
  wine,
  unzip,
}: let
  version = "0.2.2.1";

  # 平台特定的源码定义
  srcs = {
    "x86_64-linux" = {
      url = "https://github.com/Catizard/lampghost/releases/download/v${version}/lampghost_linux";
      sha256 = "1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b";
      type = "file";
      executable = true;
    };

    "x86_64-darwin" = {
      url = "https://github.com/Catizard/lampghost/releases/download/v${version}/lampghost.app.zip";
      sha256 = "2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3";
      type = "zip";
    };

    "x86_64-windows" = {
      url = "https://github.com/Catizard/lampghost/releases/download/v${version}/lampghost_windows.exe";
      sha256 = "3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d";
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
    comment = "Lampghost application";
    desktopName = "Lampghost";
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
      ++ lib.optionals stdenv.isDarwin [unzip];

    desktopItems = lib.optionals stdenv.isLinux [desktopItem];

    # 所有平台通用设置
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
    buildInputs =
      lib.optionals stdenv.isLinux [
      ];

    meta = with lib; {
      description = "Offline & Cross-platform beatoraja lamp viewer and more";
      homepage = "https://github.com/Catizard/lampghost";
      changelog = "https://github.com/Catizard/lampghost/releases/tag/v${version}";
      license = licenses.asl20;
      platforms = builtins.attrNames srcs;
      maintainers = [];
    };
  }
