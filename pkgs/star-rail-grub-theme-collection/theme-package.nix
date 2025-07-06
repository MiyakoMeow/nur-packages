# theme-package.nix
{
  lib,
  stdenvNoCC,
  fetchurl,
  python3,
  # Manual Input
  pname,
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
    # 解压
    # --strip-components=1：解除一层嵌套
    mkdir -p $out
    tar -xzf $src -C $out --strip-components=1

    # 验证主题文件
    if [ ! -e "$out/theme.txt" ]; then
      echo "ERROR: theme.txt not found in output directory"
      exit 1
    fi
  '';

  passthru.updateScript = {
    command = [
      "${python3.withPackages (ps:
        with ps; [
          requests
        ])}/bin/python3"
      "./update.py"
    ];
  };

  meta = with lib; {
    description = "Honkai: Star Rail GRUB theme (${pname})";
    homepage = "https://github.com/voidlhf/StarRailGrubThemes";
    license = licenses.gpl3;
    platforms = platforms.all;
  };
}
