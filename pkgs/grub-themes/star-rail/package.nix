{
  lib,
  stdenvNoCC,
  fetchurl,
  ...
}:
let
  # 从本地文件读取主题信息
  theme-info = lib.importJSON ./themes.json;

  # 单个主题包构建函数 (原 theme-package.nix 内容内联)
  mkThemePackage =
    pname:
    {
      url,
      sha256,
      tag,
    }:
    stdenvNoCC.mkDerivation {
      inherit pname;
      version = tag;

      src = fetchurl {
        inherit url sha256;
      };

      # 禁用自动解压步骤
      dontUnpack = true;
      dontBuild = true;

      installPhase = ''
        # 解压并解除一层嵌套
        mkdir -p $out
        tar -xzf $src -C $out --strip-components=1

        # 验证主题文件是否存在
        if [ ! -e "$out/theme.txt" ]; then
          echo "ERROR: theme.txt not found in output directory"
          exit 1
        fi
      '';

      meta = with lib; {
        description = "Honkai: Star Rail GRUB theme (${pname})";
        homepage = "https://github.com/voidlhf/StarRailGrubThemes";
        license = licenses.gpl3;
        platforms = platforms.all;
      };
    };

  # 创建所有主题包集合
  theme-packages = lib.mapAttrs mkThemePackage theme-info;
in
# 直接暴露所有主题包，使其可以直接通过 grub-themes.star-rail.acheron 访问
theme-packages
// {
  # 保留集合的元信息
  meta = with lib; {
    description = "Honkai: Star Rail GRUB themes collection";
    homepage = "https://github.com/voidlhf/StarRailGrubThemes";
    license = licenses.gpl3;
    platforms = platforms.all;
  };
}
