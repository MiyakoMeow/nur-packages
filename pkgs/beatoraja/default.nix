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
}: let
  pname = "beatoraja";
  version = "0.8.8";
  portaudio-java = pkgs.callPackage ../portaudio-java/default.nix {};
in
  stdenv.mkDerivation {
    pname = pname;
    version = version;

    src = fetchurl {
      url = "https://www.mocha-repository.info/download/beatoraja${version}-modernchic.zip";
      sha256 = "1rzp15ravq5vm14vb4y99hx7qlvvvbfrhkcrfhm26irc7rdv29h9";
    };

    nativeBuildInputs = [
      unzip
      copyDesktopItems
    ];
    buildInputs =
      [
        javaPackageWithJavaFX
        portaudio-java
        # 基础 GTK 库
        pkgs.gtk3
        # 常见 GTK 模块和主题
        pkgs.gnome-themes-extra
        pkgs.colord-gtk
        # Xrandr
        # See https://aur.archlinux.org/packages/beatoraja-modernchic#comment-994604
        pkgs.xorg.xrandr
        pkgs.xorg.libXrandr
        # For video play
        pkgs.ffmpeg
      ]
      ++ lib.optional useOBSVkCapture pkgs.obs-studio-plugins.obs-vkcapture;

    JAVA_HOME = javaPackageWithJavaFX.home;

    unpackPhase = ''
      runHook preUnpack

      echo $src

      unzip -qq -o "$src"
      mv beatoraja${version}-modernchic/* .
      rmdir beatoraja${version}-modernchic

      # 验证解压结果
      if [ ! -f beatoraja.jar ]; then
        echo "ERROR: beatoraja.jar not found after unpacking!"
        find . -type f
        exit 1
      fi
      runHook postUnpack
    '';
    sourceRoot = "."; # 显式设置解压后的根目录

    # USER_DATA_DIR="\$HOME/.local/share/beatoraja"
    installPhase = ''
      runHook preInstall

      # 创建标准目录结构
      mkdir -p $out/{bin,share/beatoraja}

      # 安全复制文件（处理特殊字符）
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
      USER_DATA_DIR="\$HOME/.local/share/beatoraja"
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

      # 文件同步逻辑（新增部分）
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

      # 退出时：临时目录 -> 用户目录（使用trap确保执行）
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
      -Djava.library.path=${portaudio-java}/lib \\
      -cp beatoraja.jar:${portaudio-java}/share/java/*:ir/* \\
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
        comment = "A modern BMS player";
        mimeTypes = [
          "application/java"
        ];
        categories = ["Game"];
        terminal = false;
      })
    ];

    meta = with lib; {
      description = "A modern BMS Player";
      homepage = "https://www.mocha-repository.info/download.php";
      license = licenses.gpl3;
      mainProgram = "beatoraja";
    };
  }
