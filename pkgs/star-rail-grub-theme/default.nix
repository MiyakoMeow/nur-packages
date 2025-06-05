# default.nix
{
  lib,
  callPackage,
  recurseIntoAttrs,
}: let
  # 从本地文件读取主题信息
  theme-info = let
    jsonFile = ./themes.json;
    jsonData = builtins.readFile jsonFile;
  in
    lib.importJSON (builtins.toFile "themes.json" jsonData);

  # 单个包构建函数
  mkThemePackage = pname: attrs:
    callPackage ./theme-package.nix ({
        inherit pname;
      }
      // attrs);

  # 创建所有包集合
  theme-packages = lib.mapAttrs mkThemePackage theme-info;
in
  recurseIntoAttrs {
    # 暴露所有主题包
    packages = theme-packages;

    # 暴露单个包（可选）
    # grub-theme-honkai-star-rail-example = theme-packages."grub-theme-honkai-star-rail-example";

    # 暴露完整集合
    all = theme-packages;
  }
