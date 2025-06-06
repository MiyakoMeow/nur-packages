{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  addToPath ? false, # 是否注册命令行可执行文件
  # 导入依赖
  libz,
  xorg,
  alsa-lib,
  libXrender,
  libXi,
  libXtst,
}: let
  # JDK 版本配置
  version = "21.0.7+9";

  # 平台映射表 (Nix系统类型 -> 下载包架构)
  platformMap = {
    "x86_64-linux" = "linux-amd64";
    "aarch64-linux" = "linux-aarch64";
    "riscv64-linux" = "linux-riscv64";
    "ppc64le-linux" = "linux-ppc64le";
    "x86_64-darwin" = "macos-amd64";
    "aarch64-darwin" = "macos-aarch64";
  };

  # 获取当前平台的架构标识
  platform = platformMap.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  # 构建下载URL
  srcUrl = "https://download.bell-sw.com/java/${version}/bellsoft-jdk${version}-${platform}.tar.gz";

  # 各平台预计算SHA256哈希 (需根据实际下载更新)
  sha1s = {
    "linux-amd64" = "634febadb04485a271fe8307bb4675bd6e67ac3e";
    "linux-aarch64" = "cd9f6b75ee8f5183a37f9a2c0dc6059fae5f720c";
    "linux-riscv64" = "a84484bc62e0c388b1e6dc1bb85261472ccc3fc0";
    "linux-ppc64le" = "1a17fd39e9d55b4f2e3b66bcf2c06db822f612d5";
    "macos-amd64" = "b04ff105eab2805a4c3b0c3c1e07e50ee20f755d";
    "macos-aarch64" = "f95b40ecffec05c548f2bb69bc0ae6050162a073";
  };
in
  stdenv.mkDerivation rec {
    pname = "liberica-jdk-21";
    inherit version;

    src = fetchurl {
      url = srcUrl;
      sha1 = sha1s.${platform};
    };

    # 仅Linux需要自动修补二进制文件
    nativeBuildInputs =
      lib.optionals stdenv.isLinux [
        autoPatchelfHook
      ]
      ++ lib.optionals addToPath [
        makeWrapper
      ];

    buildInputs = lib.optionals stdenv.isLinux [
      libz
      alsa-lib # 解决 libasound.so.2 依赖
      xorg.libX11 # 解决 libX11.so.6 依赖
      xorg.libXext # 解决 libXext.so.6 依赖
      libXrender # 解决 libXrender.so.1 依赖
      libXi # 解决 libXi.so.6 依赖
      libXtst # 解决 libXtst.so.6 依赖
    ];

    # 无需配置和构建步骤
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      # 创建输出目录
      mkdir -p $out

      # 解压JDK到输出目录 (--strip-components=1 移除顶层目录)
      tar xf $src -C $out --strip-components=1

      # 注册命令行工具 (可选)
      ${lib.optionalString addToPath ''
        mkdir -p $out/bin
        for binfile in $out/jdk-${version}/bin/*; do
          # 创建包装脚本处理环境变量
          makeWrapper "$binfile" "$out/bin/$(basename $binfile)" \
            --set JAVA_HOME "$out"
        done
      ''}
    '';

    # 设置环境钩子 (用于nix-shell)
    setupHook = ./setup-hook.sh;

    meta = with lib; {
      description = "Libreica JDK, a certified build of OpenJDK by BellSoft";
      homepage = "https://bell-sw.com/";
      license = licenses.gpl2Classpath; # GPLv2 with Classpath exception
      platforms = attrNames platformMap;
      maintainers = [];
    };
  }
