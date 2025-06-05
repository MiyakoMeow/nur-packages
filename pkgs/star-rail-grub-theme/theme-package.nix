# theme-package.nix
{
  lib,
  stdenv,
  fetchurl,
  # Args
  pname,
  url,
  sha256,
}:
stdenv.mkDerivation {
  inherit pname;
  version = "unstable";

  src = fetchurl {
    inherit url sha256;
  };

  installPhase = ''
    # 查找可能的主题目录
    dirs=($(find . -maxdepth 1 -type d ! -name '.'))

    if [ ''${#dirs[@]} -eq 0 ]; then
      echo "ERROR: No directories found in the archive"
      exit 1
    fi

    # 使用第一个找到的目录
    themeDir="''${dirs[0]}"
    echo "Using theme directory: $themeDir"

    # 创建目标目录并复制内容
    mkdir -p $out
    cp -r "$themeDir"/* $out/

    # 验证安装
    if [ ! -d "$out/theme.txt" ] && [ ! -f "$out/theme.txt" ]; then
      echo "ERROR: theme.txt not found in output directory"
      exit 1
    fi
  '';

  meta = with lib; {
    description = "Honkai: Star Rail GRUB theme";
    homepage = "https://github.com/voidlhf/StarRailGrubThemes";
    license = licenses.gpl3;
    platforms = platforms.all;
  };
}
