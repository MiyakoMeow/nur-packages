# generate-info.nix
{
  lib,
  stdenv,
  python3,
}:
stdenv.mkDerivation {
  pname = "generate-honkai-theme-info";
  version = "1.0";

  src = ./.;

  nativeBuildInputs = [python3];

  buildPhase = ''
    # 创建输出目录
    mkdir -p $out/bin
    cp ${./generate-theme-info.py} $out/bin/generate-theme-info
    chmod +x $out/bin/generate-theme-info
  '';

  installPhase = ":";

  meta = with lib; {
    description = "Generator for Honkai Star Rail GRUB theme package info";
    homepage = "https://github.com/voidlhf/StarRailGrubThemes";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
