{
  stdenv,
  lib,
  pkgs,
  fetchurl,
  makeDesktopItem,
  copyDesktopItems,
  # Deps
  unzip,
  # Args
  javaPackageWithJavaFX ?
    pkgs.jdk.override {
      headless = false;
      enableJavaFX = true;
    },
  useOBSVkCapture ? false,
  portaudioJava ? pkgs.callPackage ../portaudio-java/default.nix {},
}: let
  pname = "lr2oraja-endlessdream";
  version = "0.2.1";
  beatorajaVersion = "0.8.7"; # 原始 beatoraja 的版本

  # 原始 beatoraja 的 zip 文件
  beatorajaArchive = fetchurl {
    url = "https://www.mocha-repository.info/download/beatoraja${beatorajaVersion}-modernchic.zip";
    hash = "sha256-rkM8z9Oyqy3dS9zWgTQyjeEQg7Nax1V5hohL/neCNr8=";
  };

  # lr2oraja-endlessdream 的 jar 文件
  lr2orajaJar = fetchurl {
    url = "https://github.com/seraxis/lr2oraja-endlessdream/releases/download/v${version}/lr2oraja-${beatorajaVersion}-endlessdream-linux-${version}.jar";
    hash = "sha256-czkFZP3gn9ieq5w6NLCvvSTufgesFhtD7YGEwyD3HYs=";
  };

  # 设置可选的 portaudio 路径
  portaudioClasspath =
    if portaudioJava != null
    then ":${portaudioJava}/share/java/*"
    else "";

  portaudioLibpath =
    if portaudioJava != null
    then "-Djava.library.path=${portaudioJava}/lib"
    else "";
in
  stdenv.mkDerivation {
    inherit pname version;

    srcs = [
      beatorajaArchive # 原始 beatoraja 的 zip 文件
      lr2orajaJar # 替换用的 jar 文件
    ];

    sourceRoot = ".";

    nativeBuildInputs = [
      unzip
      copyDesktopItems
    ];

    buildInputs =
      [
        javaPackageWithJavaFX
        # 基础 GTK 库
        pkgs.gtk3
        # 常见 GTK 模块和主题
        pkgs.gnome-themes-extra
        pkgs.colord-gtk
        # Xrandr
        pkgs.xorg.xrandr
        pkgs.xorg.libXrandr
        # For video play
        pkgs.ffmpeg
      ]
      ++ lib.optional useOBSVkCapture pkgs.obs-studio-plugins.obs-vkcapture
      ++ lib.optional (portaudioJava != null) portaudioJava;

    JAVA_HOME = javaPackageWithJavaFX.home;

    unpackPhase = ''
      runHook preUnpack

      # 解压原始 beatoraja zip
      unzip -qq -o "${beatorajaArchive}"
      mv beatoraja${beatorajaVersion}-modernchic/* .
      rmdir beatoraja${beatorajaVersion}-modernchic

      # 验证解压结果
      if [ ! -f beatoraja.jar ]; then
        echo "ERROR: beatoraja.jar not found after unpacking!"
        find . -type f
        exit 1
      fi

      # 替换为 lr2oraja-endlessdream 的 jar
      cp "${lr2orajaJar}" beatoraja.jar

      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      # 创建标准目录结构
      mkdir -p $out/{bin,share/beatoraja}

      # 安全复制文件
      find . -maxdepth 1 -type f -print0 | xargs -0 -I{} cp -- {} $out/bin/
      rm $out/bin/*.bat
      rm $out/bin/*.dll
      find . -mindepth 1 -maxdepth 1 -type d -print0 | xargs -0 -I{} cp -r -- {} $out/share/beatoraja/

      # 创建启动脚本
      cat > $out/bin/beatoraja <<EOF
      #!${stdenv.shell}
      export JAVA_HOME="${javaPackageWithJavaFX.home}"
      export _JAVA_OPTIONS='-Dsun.java2d.opengl=true -Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel'

      # 用户数据目录配置
      USER_DATA_DIR="\$HOME/.local/share/lr2oraja-endlessdream"
      mkdir -p "\$USER_DATA_DIR"

      # 初始化用户目录结构
      for dir in $out/share/beatoraja/*/; do
        dir_name=\$(basename "\$dir")
        target_dir="\$USER_DATA_DIR/\$dir_name"

        if [ ! -d "\$target_dir" ]; then
          echo "Initializing directory: \$dir_name"
          cp -r --no-preserve=all "\$dir" "\$target_dir"
        fi
      done

      # 创建临时运行环境
      RUNTIME_DIR=\$(mktemp -d -t beatoraja.XXX)

      # 文件同步逻辑
      config_files=(
        "beatoraja_log.xml"
        "config_sys.json"
        "songdata.db"
        "songinfo.db"
      )

      # 启动时：用户目录 -> 临时目录
      for cfg in "\''${config_files[@]}"; do
        user_cfg="\$USER_DATA_DIR/\$cfg"
        if [ -f "\$user_cfg" ]; then
          cp -f "\$user_cfg" "\$RUNTIME_DIR/"
        fi
      done

      # 退出时：临时目录 -> 用户目录
      cleanup() {
        echo "Syncing config files back to user directory..."

        # 1. 同步配置文件
        for cfg in "\''${config_files[@]}"; do
          runtime_cfg="\$RUNTIME_DIR/\$cfg"
          if [ -f "\$runtime_cfg" ]; then
            cp -f "\$runtime_cfg" "\$USER_DATA_DIR/"
          fi
        done

        # 2. 同步新目录
        find "\$RUNTIME_DIR" -mindepth 1 -maxdepth 1 -type d | while read dir; do
          dir_name=\$(basename "\$dir")
          user_dir="\$USER_DATA_DIR/\$dir_name"

          # 如果用户目录不存在该目录，则复制
          if [ ! -d "\$user_dir" ]; then
            echo "Copying new directory: \$dir_name to user data"
            cp -r --no-preserve=all "\$dir" "\$user_dir"
          fi
        done
        rm -rf "\$RUNTIME_DIR"
      }
      trap cleanup EXIT

      # 链接必要文件
      ln -sf $out/bin/beatoraja.jar "\$RUNTIME_DIR/"

      # 创建符号链接到用户目录
      for dir in "\$USER_DATA_DIR"/*/; do
        dir_name=\$(basename "\$dir")
        ln -sfT "\$dir" "\$RUNTIME_DIR/\$dir_name"
      done

      # 运行游戏
      cd "\$RUNTIME_DIR"
      ${lib.optionalString useOBSVkCapture "${pkgs.obs-studio-plugins.obs-vkcapture}/bin/obs-gamecapture"} \\
      "${javaPackageWithJavaFX}/bin/java" -Xms1g -Xmx4g \\
      -XX:+UseShenandoahGC -XX:+ExplicitGCInvokesConcurrent -XX:+TieredCompilation -XX:+UseNUMA -XX:+AlwaysPreTouch \\
      -XX:-UsePerfData -XX:+UseThreadPriorities -XX:+ShowCodeDetailsInExceptionMessages \\
      ${portaudioLibpath} \\
      -cp beatoraja.jar${portaudioClasspath}:ir/* \\
      bms.player.beatoraja.MainLoader "\$@"
      EOF

      # 设置脚本执行权限
      chmod +x $out/bin/beatoraja

      # 安装桌面文件
      copyDesktopItems

      runHook postInstall
    '';

    desktopItems = [
      (makeDesktopItem {
        name = pname;
        desktopName = pname;
        exec = pname;
        comment = "A fork of beatoraja with enhanced features";
        mimeTypes = ["application/java"];
        categories = ["Game"];
        terminal = false;
      })
    ];

    meta = with lib; {
      description = "A fork of beatoraja with enhanced features";
      homepage = "https://github.com/seraxis/lr2oraja-endlessdream";
      license = licenses.gpl3;
      mainProgram = "beatoraja";
    };
  }
