{ 
  stdenv,
  lib,
  pkgs,
  sources,
  fetchurl,
  fetchzip,
  callPackage,
  makeDesktopItem,
  copyDesktopItems,
  unzip,
  ...
}:

rec {
  # beatoraja 包定义
  beatoraja = callPackage ./beatoraja.nix { };

  # lr2oraja 包定义
  lr2oraja = callPackage ./lr2oraja.nix { };

  # lr2oraja-endlessdream 包定义
  lr2oraja-endlessdream = callPackage ./lr2oraja-endlessdream.nix { };

  packagesInSet = {
    beatoraja = beatoraja;
    lr2oraja = lr2oraja;
    lr2oraja-endlessdream = lr2oraja-endlessdream;
  };
}
