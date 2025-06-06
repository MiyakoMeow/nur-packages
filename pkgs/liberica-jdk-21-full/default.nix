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
  choice = "full";

  # 平台映射表 (Nix系统类型 -> 下载包架构)
  platformMap = {
    "x86_64-linux" = "linux-amd64";
    "aarch64-linux" = "linux-aarch64";
    "x86_64-darwin" = "macos-amd64";
    "aarch64-darwin" = "macos-aarch64";
  };

  # 获取当前平台的架构标识
  platform = platformMap.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  # 构建下载URL
  srcUrl = "https://download.bell-sw.com/java/${version}/bellsoft-jdk${version}-${platform}-${choice}.tar.gz";

  # 各平台预计算SHA256哈希 (需根据实际下载更新)
  sha1s = {
    "linux-amd64" = "2c7466a90a261dc20ea8922d16a63ed84e304a44";
    "linux-aarch64" = "5f9fcb4c42e2861638d94c06e9f59d1291471947";
    "macos-amd64" = "0817a12fad1aeaccdbf7498126e03e450bdbeb47";
    "macos-aarch64" = "57bd67723c0afbe0ac08f9c189951ff1bf5eb011";
  };
in
  stdenv.mkDerivation rec {
    pname = "liberica-jdk-21-${choice}";
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
      alsa-lib
      xorg.libX11
      xorg.libXext
      libXrender
      libXi
      libXtst
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

    passthru = {
      home = builtins.placeholder "out"; # 指向输出路径占位符
    };

    meta = with lib; {
      description = "Libreica JDK, a certified build of OpenJDK by BellSoft";
      homepage = "https://bell-sw.com/";
      license = licenses.gpl2Classpath; # GPLv2 with Classpath exception
      platforms = attrNames platformMap;
      maintainers = [];
    };
  }
