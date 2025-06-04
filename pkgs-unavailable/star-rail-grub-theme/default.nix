{
  lib,
  stdenv,
  fetchurl,
  writeShellScriptBin,
  python3,
  nix,
  runtimeShell,
}: let
  # 配置参数
  config = {
    owner = "voidlhf";
    repo = "StarRailGrubThemes";
    tag = "20250524-070052"; # 默认为 null 表示所有 Release
  };

  # Python 脚本用于生成包信息 JSON
  generator-script = writeShellScriptBin "generate-theme-info" ''
    ${python3}/bin/python ${./generate-theme-info.py} \
      --owner "${config.owner}" \
      --repo "${config.repo}" \
      ${lib.optionalString (config.tag != null) "--tag \"${config.tag}\""}
  '';

  # 运行 Python 脚本获取包信息
  theme-info-json = stdenv.mkDerivation {
    name =
      "honkai-star-rail-theme-info"
      + (
        if config.tag != null
        then "-${lib.replaceStrings ["/"] ["-"] config.tag}"
        else ""
      );

    nativeBuildInputs = [generator-script nix];

    buildCommand = ''
      # 设置 NIX_PATH 确保 nix-prefetch-url 正常工作
      export NIX_PATH=nixpkgs=${toString <nixpkgs>}

      # 运行生成脚本
      generate-theme-info > $out
    '';

    # 固定输出推导，允许网络访问
    outputHashMode = "flat";
    outputHashAlgo = "sha256";
    outputHash = lib.fakeSha256; # 首次构建时替换为实际哈希

    # 确保可以访问网络
    __noChroot = true;
    allowSubstitutes = false;
    preferLocalBuild = false;
  };

  # 从 JSON 文件读取包信息
  theme-info = lib.importJSON theme-info-json;

  # 单个主题包构建函数
  mkThemePackage = pname: {
    url,
    sha256,
    tag,
  }:
    stdenv.mkDerivation {
      inherit pname;
      version = tag;

      src = fetchurl {
        inherit url sha256;
      };

      # 处理压缩包内的目录结构
      installPhase = ''
        # 找到压缩包内的第一层目录
        themeDir=$(find . -maxdepth 1 -type d -name '*' | head -n1)

        if [ -z "$themeDir" ]; then
          echo "Error: No directory found in the archive"
          exit 1
        fi

        # 创建目标目录
        mkdir -p $out
        # 移动主题内容到目标目录
        cp -r $themeDir/* $out/
      '';

      meta = with lib; {
        description = "Honkai: Star Rail GRUB theme";
        homepage = "https://github.com/${config.owner}/${config.repo}";
        license = licenses.gpl3;
        platforms = platforms.all;
      };
    };

  # 为所有主题创建包
  theme-packages = lib.mapAttrs mkThemePackage theme-info;
in
  theme-packages
