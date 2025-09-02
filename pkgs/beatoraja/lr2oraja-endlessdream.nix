{
  stdenv,
  lib,
  pkgs,

  fetchurl,
  fetchzip,
  callPackage,
  makeDesktopItem,
  copyDesktopItems,
  unzip,
  ...
}:

let
  commonAttrs = import ./lib/common.nix {
    inherit
      stdenv
      lib
      pkgs
      fetchurl
      fetchzip
      callPackage
      makeDesktopItem
      copyDesktopItems
      unzip
      ;
  };

  pname = "lr2oraja-endlessdream";
  version = "0.2.1";
  beatorajaVersion = "0.8.7";
  beatorajaArchive = fetchurl {
    url = "https://www.mocha-repository.info/download/beatoraja${beatorajaVersion}-modernchic.zip";
    hash = "sha256-rkM8z9Oyqy3dS9zWgTQyjeEQg7Nax1V5hohL/neCNr8=";
  };
  lr2orajaJar = fetchurl {
    url = "https://github.com/seraxis/lr2oraja-endlessdream/releases/download/v${version}/lr2oraja-${beatorajaVersion}-endlessdream-linux-${version}.jar";
    hash = "sha256-czkFZP3gn9ieq5w6NLCvvSTufgesFhtD7YGEwyD3HYs=";
  };
in
commonAttrs {
  inherit pname version;
  ReplacingJarSource = lr2orajaJar;
  meta = with lib; {
    description = "A fork of beatoraja with enhanced features";
    homepage = "https://github.com/seraxis/lr2oraja-endlessdream";
    license = licenses.gpl3;
    mainProgram = pname;
  };
  inherit beatorajaVersion beatorajaArchive;
}
