# theme-package.nix
{
  lib,
  stdenv,
  fetchurl,
  pname,
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

  installPhase = ''
    # 查找主题目录
    dirs=($(find . -maxdepth 1 -type d ! -name '.'))

    if [ ''${#dirs[@]} -eq 0 ]; then
      echo "ERROR: No directories found in the archive"
      exit 1
    fi

    themeDir="''${dirs[0]}"
    echo "Using theme directory: $themeDir"

    mkdir -p $out
    cp -r "$themeDir"/* $out/

    # 验证主题文件
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
}
