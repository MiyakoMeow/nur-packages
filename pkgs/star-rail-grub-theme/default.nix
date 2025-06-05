# default.nix
{
  lib,
  callPackage,
  recurseIntoAttrs,
}: let
  # 配置参数
  config = {
    owner = "voidlhf";
    repo = "StarRailGrubThemes";
    tag = "20250524-070052"; # 默认为所有Release
  };

  # 导入生成的包信息
  theme-info-drv = callPackage ./generate-theme-info.nix {inherit config;};
  theme-info = lib.importJSON (theme-info-drv + "/${theme-info-drv.name}");

  # 创建单个包的函数
  mkThemePackage = pname: attrs:
    callPackage ./theme-package.nix ({
        inherit pname;
      }
      // attrs);

  # 创建所有包的集合
  theme-packages = lib.mapAttrs mkThemePackage theme-info;
in
  recurseIntoAttrs {
    # 导出所有主题包
    packages = theme-packages;

    # 导出包信息生成器（用于调试）
    theme-info = theme-info-drv;

    # 导出所有包作为属性集
    all = theme-packages;
  }
