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

  # 导入单个包或包集合（返回原始结果）
  importPackage = path: pkgs.callPackage path {};

  # 辅助函数：递归收集所有 derivations
  lib =
    pkgs.lib
    // {
      # 展平属性集并收集所有 derivations
      flattenAttrs = attrs: let
        # 递归收集函数
        collect = path: value:
          if lib.isDerivation value
          then [
            {
              name = lib.concatStringsSep "-" path;
              value = value;
            }
          ]
          else if lib.isAttrs value
          then
            # 优先处理 packagesInSet 集合
            if value ? packagesInSet
            then collect path value.packagesInSet
            else
              # 递归处理普通属性集
              lib.concatLists (lib.mapAttrsToList
                (name: val: collect (path ++ [name]) val)
                value)
          else [];
      in
        builtins.listToAttrs (collect [] attrs);
    };

  # 为每个目录创建包或包集合
  autoPackages = builtins.listToAttrs (map (name: {
      name = name;
      value = importPackage (packagesDir + "/${name}");
    })
    packageNames);

  # 收集所有展开的包（包括单个包和集合中的包）
  allPackages = lib.flattenAttrs autoPackages;
in
  specialAttrs
  // autoPackages # 保留按目录组织的包集合
  // allPackages
# 添加所有包到顶层

