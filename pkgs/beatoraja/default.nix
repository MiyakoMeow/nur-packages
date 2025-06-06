{
  stdenv,
  lib,
  pkgs,
  fetchurl,
  fetchzip,
  callPackage,
  makeDesktopItem,
  copyDesktopItems,
  unzip,
}: let
  # 公共配置函数
  commonAttrs = {
    pname,
    version,
    beatorajaVersion,
    beatorajaArchive,
    meta,
    jarSource ? null,
    javaPackageWithJavaFX ? (pkgs.jdk.override {
      headless = false;
      enableJavaFX = true;
    }),
    portaudioJava ? pkgs.callPackage ../portaudio-java {},
    useOBSVkCapture ? false,
  }: let
    # 根据 portaudioJava 是否存在设置类路径和库路径
    portaudioClasspath =
      if portaudioJava != null
      then ":${portaudioJava}/share/java/*"
      else "";

    portaudioLibpath =
      if portaudioJava != null
      then "-Djava.library.path=${portaudioJava}/lib"
      else "";
  in
    stdenv.mkDerivation rec {
      inherit pname version meta;

      srcs =
        [beatorajaArchive]
        ++ lib.optional (jarSource != null) jarSource;
      sourceRoot = ".";

      nativeBuildInputs = [unzip copyDesktopItems];
      buildInputs =
        [
          javaPackageWithJavaFX
          pkgs.gtk3
          pkgs.gnome-themes-extra
          pkgs.colord-gtk
          pkgs.xorg.xrandr
          pkgs.xorg.libXrandr
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

        # 替换为指定的 jar 文件
        ${lib.optionalString (jarSource != null) ''
          rm beatoraja.jar
          cp ${jarSource} ${pname}.jar
        ''}

        # 验证解压结果
        if [ ! -f ${pname}.jar ]; then
          echo "ERROR: ${pname}.jar not found after unpacking!"
          find . -type f
          exit 1
        fi

        runHook postUnpack
      '';

      installPhase = ''
        runHook preInstall

        # 创建标准目录结构
        mkdir -p $out/{bin,${pname}-ori,share/beatoraja}

        # 安全复制文件
        find . -maxdepth 1 -type f -print0 | xargs -0 -I{} cp -- {} $out/${pname}-ori/
        rm $out/${pname}-ori/*.bat
        rm $out/${pname}-ori/*.command
        rm $out/${pname}-ori/*.dll
        find . -mindepth 1 -maxdepth 1 -type d -print0 | xargs -0 -I{} cp -r -- {} $out/share/${pname}/

        # 创建启动脚本
        cat > $out/bin/${pname} <<EOF
        #!${stdenv.shell}
        export JAVA_HOME="${javaPackageWithJavaFX.home}"
        export _JAVA_OPTIONS='-Dsun.java2d.opengl=true -Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel'

        # 用户数据目录配置
        USER_DATA_DIR="\$HOME/.local/share/${pname}"
        mkdir -p "\$USER_DATA_DIR"

        # 初始化用户目录结构
        for dir in $out/share/${pname}/*/; do
          dir_name=\$(basename "\$dir")
          target_dir="\$USER_DATA_DIR/\$dir_name"

          if [ ! -d "\$target_dir" ]; then
            echo "Initializing directory: \$dir_name"
            cp -r --no-preserve=all "\$dir" "\$target_dir"
          fi
        done

        # 创建临时运行环境
        RUNTIME_DIR=\$(mktemp -d -t ${pname}.XXX)

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
        ln -sf $out/${pname}-ori/${pname}.jar "\$RUNTIME_DIR/"

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
        -cp ${pname}.jar${portaudioClasspath}:ir/* \\
        bms.player.beatoraja.MainLoader "\$@"
        EOF

        # 设置脚本执行权限
        chmod +x $out/bin/${pname}

        # 安装桌面文件
        copyDesktopItems

        runHook postInstall
      '';

      desktopItems = [
        (makeDesktopItem {
          name = pname;
          desktopName = pname;
          exec = pname;
          comment = meta.description;
          mimeTypes = ["application/java"];
          categories = ["Game"];
          terminal = false;
        })
      ];
    };
in rec {
  # beatoraja 包定义
  beatoraja = {
    portaudioJava ? pkgs.callPackage ../portaudio-java/default.nix {},
    useOBSVkCapture ? false,
  }: let
    pname = "beatoraja";
    version = "0.8.8";
    beatorajaVersion = version;
    beatorajaArchive = fetchurl {
      url = "https://www.mocha-repository.info/download/beatoraja${beatorajaVersion}-modernchic.zip";
      sha256 = "1rzp15ravq5vm14vb4y99hx7qlvvvbfrhkcrfhm26irc7rdv29h9";
    };
  in
    commonAttrs {
      inherit pname version;
      meta = with lib; {
        description = "A modern BMS Player";
        homepage = "https://www.mocha-repository.info/download.php";
        license = licenses.gpl3;
        mainProgram = pname;
      };
      inherit portaudioJava useOBSVkCapture beatorajaVersion beatorajaArchive;
    };

  # lr2oraja 包定义
  lr2oraja = {
    portaudioJava ? pkgs.callPackage ../portaudio-java/default.nix {},
    useOBSVkCapture ? false,
  }: let
    pname = "lr2oraja";
    version = "build11611350155";
    beatorajaVersion = "0.8.8";
    beatorajaArchive = fetchurl {
      url = "https://www.mocha-repository.info/download/beatoraja${beatorajaVersion}-modernchic.zip";
      sha256 = "1rzp15ravq5vm14vb4y99hx7qlvvvbfrhkcrfhm26irc7rdv29h9";
    };
    lr2orajaJar =
      (fetchzip {
        url = "https://github.com/wcko87/lr2oraja/releases/download/${version}/LR2oraja.zip";
        hash = "sha256-fjhvJRjpSUEAwPmxgoyKvEFWzb4ZOiUASUhFjG9CPTg=";
      })
      + "/beatoraja.jar";
  in
    commonAttrs {
      inherit pname version;
      jarSource = lr2orajaJar;
      meta = with lib; {
        description = "A fork of beatoraja with enhanced features";
        homepage = "https://github.com/seraxis/lr2oraja-endlessdream";
        license = licenses.gpl3;
        mainProgram = pname;
      };
      inherit portaudioJava useOBSVkCapture beatorajaVersion beatorajaArchive;
    };

  # lr2oraja-endlessdream 包定义
  lr2oraja-endlessdream = {
    portaudioJava ? pkgs.callPackage ../portaudio-java/default.nix {},
    useOBSVkCapture ? false,
  }: let
    pname = "lr2oraja-endlessdream";
    version = "0.2.1";
    beatorajaVersion = "0.8.7";
    beatorajaArchive = fetchurl {
      url = "https://www.mocha-repository.info/download/beatoraja${beatorajaVersion}-modernchic.zip";
      hash = "sha256-rkM8z9Oyqy3dS9zWgTQyjeEQg7Nax1V5hohL/neCNr8=";
    };
    lr2orajaJar = fetchurl {
      url = "https://github.com/seraxis/lr2oraja-endlessdream/releases/download/v${version}/lr2oraja-${beatorajaVersion}-endlessdream-linux-${version}.jar";
      hash = "sha256-czkFZP3gn9ieq5w6NLCvvSTufgesFhtD7YGEwyD3HYs=";
    };
  in
    commonAttrs {
      inherit pname version;
      jarSource = lr2orajaJar;
      meta = with lib; {
        description = "A fork of beatoraja with enhanced features";
        homepage = "https://github.com/seraxis/lr2oraja-endlessdream";
        license = licenses.gpl3;
        mainProgram = pname;
      };
      inherit portaudioJava useOBSVkCapture beatorajaVersion beatorajaArchive;
    };
  packagesInSet = {
    beatoraja = callPackage beatoraja {};
    lr2oraja = callPackage lr2oraja {};
    lr2oraja-endlessdream = callPackage lr2oraja-endlessdream {};
  };
}
