{
  lib,
  pkgs,
  stdenvNoCC,
  fetchFromGitHub,
  nix-update-script,
  ...
}: let
  # 仓库信息
  owner = "13atm01";
  repo = "GRUB-Theme";
  rev = "f4d764cab6bed5ab29e31965cca59420cc84ee0a"; # 替换为实际commit
  hash = "sha256-yceSIVxVpUNUDFjMXGYGkD4qyMRajU7TyDg/gl2NmAs="; # 替换为实际SHA256
  version = "Lyco-v1.0-unstable-2025-06-15";
  # 获取仓库源码
  src = fetchFromGitHub {
    inherit owner repo rev hash;
  };

  metaPkg = stdenvNoCC.mkDerivation rec {
    pname = "13atm01-grub-themes-meta";
    inherit src version;

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    dontInstall = true;

    passthru.updateScript = nix-update-script {
      attrPath = pname;
      extraArgs = [
        "--flake"
        "--version=branch"
      ];
    };
    meta = with lib; {
      description = "GRUB2 theme metaPack from ${owner}/${repo}";
      homepage = "https://github.com/${owner}/${repo}";
      license = licenses.gpl3;
      platforms = platforms.all;
    };
  };

  # 读取主题列表
  themeList = lib.importJSON ./theme-list.json;

  # 为每个主题创建包的函数
  mkThemePackage = packageName: themePath:
    stdenvNoCC.mkDerivation {
      name = packageName;
      pname = packageName;
      inherit src version;

      dontUnpack = true;
      dontConfigure = true;
      dontBuild = true;

      installPhase = ''
        # 创建输出目录
        mkdir -p "$out"

        # 复制主题内容
        cp -rT "${src}/${themePath}" "$out"

        # 验证必要文件存在
        if [ ! -f "$out/theme.txt" ]; then
          echo "错误：未找到 theme.txt 文件"
          exit 1
        fi
      '';

      # Self updateScript
      passthru.updateScript = [./update.sh];

      meta = with lib; {
        description = "GRUB2 theme '${packageName}' from ${owner}/${repo}";
        homepage = "https://github.com/${owner}/${repo}";
        license = licenses.gpl3;
        platforms = platforms.all;
      };
    };
in {
  # 所有主题包的集合
  packagesInSet = lib.mapAttrs mkThemePackage themeList // {meta = metaPkg;};
}
