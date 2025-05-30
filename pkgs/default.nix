{
  callPackage,
  loadPackages,
  ...
}: let
  packages = loadPackages ./. {};
in
  packages
