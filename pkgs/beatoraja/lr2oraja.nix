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

  pname = "lr2oraja";
  version = "build11611350155";
  lr2orajaJar =
    (fetchzip {
      url = "https://github.com/wcko87/lr2oraja/releases/download/${version}/LR2oraja.zip";
      hash = "sha256-fjhvJRjpSUEAwPmxgoyKvEFWzb4ZOiUASUhFjG9CPTg=";
    })
    + "/beatoraja.jar";
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
}
