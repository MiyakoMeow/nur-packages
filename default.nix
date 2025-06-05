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

  # 导入单个包或包集合
  importPackage = path: let
    # 调用包目录的 default.nix
    result = pkgs.callPackage path {};

    # 检查是否是包集合（包含 packages 或 all 属性）
    isPackageSet = result ? packages || result ? all;
  in
    if isPackageSet
    then
      # 如果是包集合，展开所有包
      result.packages or result.all or {}
    else
      # 如果是单个包，保持原样
      result;

  # 为每个目录创建包或包集合
  autoPackages = builtins.listToAttrs (map (name: {
      name = name;
      value = importPackage (packagesDir + "/${name}");
    })
    packageNames);

  # 收集所有展开的包
  allPackages = lib.flattenAttrs autoPackages;

  # 辅助函数：展平属性集
  lib =
    pkgs.lib
    // {
      flattenAttrs = attrs: let
        # 递归展平嵌套属性集
        flatten = path: value:
          if lib.isDerivation value
          then [
            {
              name = lib.concatStringsSep "-" path;
              value = value;
            }
          ]
          else if lib.isAttrs value
          then
            lib.concatLists (lib.mapAttrsToList
              (name: value: flatten (path ++ [name]) value)
              value)
          else [];
      in
        builtins.listToAttrs (flatten [] attrs);
    };
in
  specialAttrs
  // autoPackages # 保留按目录组织的包集合
  // allPackages
# 添加所有包到顶层

