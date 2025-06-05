# generate-info.nix
{
  lib,
  stdenv,
  python3,
  autoPatchelfHook,
}:
stdenv.mkDerivation {
  pname = "star-rail-grub-theme-generate-info";
  version = "1.0";

  src = ./.;

  nativeBuildInputs = [python3 autoPatchelfHook];

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    # 创建输出目录
    mkdir -p $out/bin
    cp ${./generate-theme-info.py} $out/bin/generate-theme-info
    chmod +x $out/bin/generate-theme-info
  '';

  meta = with lib; {
    description = "Generator for Honkai Star Rail GRUB theme package info";
    homepage = "https://github.com/voidlhf/StarRailGrubThemes";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
