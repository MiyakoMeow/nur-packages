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

  # 导入 nvfetcher 生成的源
  sources = import ./_sources/generated.nix {
    inherit (pkgs) fetchurl fetchgit fetchFromGitHub dockerTools;
  };

  # 导入单个包或包集合（返回原始结果）
  importPackage = path:
    pkgs.callPackage path {
      # 显式传递 sources 参数
      inherit sources;
    };

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

  # 自动发现所有包目录
  packagesDir = ./pkgs;
  packageNames = builtins.attrNames (builtins.readDir packagesDir);

  # 为每个目录创建包或包集合，并展开所有的包
  allOutsidePackages = lib.collectPackages (builtins.listToAttrs (map (name: {
      name = name;
      value = importPackage (packagesDir + "/${name}");
    })
    packageNames));

  # === 处理 pkg-groups 目录 ===
  pkgGroupsDir = ./pkg-groups;
  # 获取所有组名（目录需存在）
  groupNames =
    if builtins.pathExists pkgGroupsDir
    then builtins.attrNames (builtins.readDir pkgGroupsDir)
    else [];

  # 导入组内所有包，并收集为平面属性集
  importGroup = groupName: let
    groupDir = pkgGroupsDir + "/${groupName}";
    pkgNames = builtins.attrNames (builtins.readDir groupDir);

    # 创建组内包的原始属性集
    rawGroup = builtins.listToAttrs (map (pkgName: {
        name = pkgName;
        value = importPackage (groupDir + "/${pkgName}");
      })
      pkgNames);
  in
    # 关键修改：对每个组应用 collectPackages
    lib.collectPackages rawGroup;

  # 构建组属性集 { 组名 = 平面包集合; ... }
  groupedPackages = builtins.listToAttrs (map (groupName: {
      name = groupName;
      value = importGroup groupName;
    })
    groupNames);
in
  specialAttrs
  // allOutsidePackages
  // groupedPackages
# 按组名组织的包组（每个组是平面属性集）

