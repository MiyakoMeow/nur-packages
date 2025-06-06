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

  # 辅助函数：递归收集所有 derivations 并保留原始名称
  lib =
    pkgs.lib
    // {
      # 收集所有包到平面属性集（保留原始名称）
      collectPackages = attrs: let
        # 递归收集函数
        collector = acc: path: value:
          if lib.isDerivation value
          then
            # 遇到 derivation，使用其名称（pname 或 name）作为键
            let
              pkgName = value.pname or (lib.getName value);
            in
              if acc ? ${pkgName}
              then
                builtins.trace "WARNING: Duplicate package name '${pkgName}' detected. Replacing old derivation."
                (acc // {${pkgName} = value;})
              else acc // {${pkgName} = value;}
          else if value ? packagesInSet
          then
            # 处理包集合：递归处理 packagesInSet
            collector acc path value.packagesInSet
          else if lib.isAttrs value
          then
            # 递归处理普通属性集
            lib.foldl' (
              acc: key:
                collector acc (path ++ [key]) value.${key}
            )
            acc (lib.attrNames value)
          else acc; # 忽略非属性/非 derivation
      in
        # 从根属性集开始收集
        collector {} [] attrs;
    };

  # 为每个目录创建包或包集合
  autoPackages = builtins.listToAttrs (map (name: {
      name = name;
      value = importPackage (packagesDir + "/${name}");
    })
    packageNames);

  # 收集所有展开的包（包括单个包和集合中的包）
  allPackages = lib.collectPackages autoPackages;
in
  specialAttrs
  // autoPackages # 保留按目录组织的包集合
  // allPackages
# 添加所有包到顶层

