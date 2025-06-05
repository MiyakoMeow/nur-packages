# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage
{pkgs ? import <nixpkgs> {}}: let
  # 特殊属性（需保留）
  specialAttrs = {
    # The `lib`, `modules`, and `overlays` names are special
    lib = import ./lib {inherit pkgs;}; # functions
    modules = import ./modules; # NixOS modules
    overlays = import ./overlays; # nixpkgs overlays
  };

  # 自动发现所有包目录
  packagesDir = ./pkgs;
  packageNames = builtins.attrNames (builtins.readDir packagesDir);

  # 为每个目录创建包
  autoPackages = builtins.listToAttrs (map (name: {
      inherit name;
      value = pkgs.callPackage (packagesDir + "/${name}") {};
    })
    packageNames);
in
  specialAttrs
  // autoPackages
  // {
    star-rail-grub-theme-json = pkgs.callPackage ./pkgs-unavailable/star-rail-grub-theme/generate-theme-info.nix;
  }
