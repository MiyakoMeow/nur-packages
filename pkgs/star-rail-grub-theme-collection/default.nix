# default.nix
{
  lib,
  callPackage,
  ...
}: let
  # 从本地文件读取主题信息
  theme-info = lib.importJSON ./themes.json;

  # 单个包构建函数
  mkThemePackage = pname: attrs:
    callPackage ./theme-package.nix ({
        inherit pname;
      }
      // attrs);

  # 创建所有包集合
  theme-packages = lib.mapAttrs mkThemePackage theme-info;
in {
  # 新变量，暴露所有主题包
  packagesInSet = theme-packages;
}
