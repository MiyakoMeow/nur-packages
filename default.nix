# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage
{
  pkgs ? import <nixpkgs> { },
}:
let
  # 特殊属性（需保留）
  specialAttrs = {
    # The `lib`, `modules`, and `overlays` names are special
    lib = import ./lib { inherit pkgs; }; # functions
    modules = import ./modules; # NixOS modules
    overlays = import ./overlays; # nixpkgs overlays
  };

  # 导入单个包或包集合（返回原始结果）
  importPackage =
    path:
    pkgs.callPackage path {
    };

  # 安全导入：失败时仅告警并返回 null，不中断其它包解析
  safeImportPackage =
    path:
    let
      attempt = builtins.tryEval (importPackage path);
    in
    if attempt.success then
      attempt.value
    else
      builtins.trace "WARNING: Failed to import package at ${toString path}; skipping." null;

  # 辅助函数：递归收集所有 derivations 并保留原始名称
  lib = pkgs.lib // {
    # 收集所有包到平面属性集（保留原始名称）
    collectPackages =
      attrs:
      let
        # 递归收集函数
        collector =
          acc: path: value:
          if lib.isDerivation value then
            # 遇到 derivation，使用其名称（pname 或 name）作为键
            let
              pkgName = value.pname or (lib.getName value);
            in
            if acc ? ${pkgName} then
              builtins.trace "WARNING: Duplicate package name '${pkgName}' detected. Replacing old derivation." (
                acc // { ${pkgName} = value; }
              )
            else
              acc // { ${pkgName} = value; }
          else if value ? packagesInSet then
            # 处理包集合：递归处理 packagesInSet
            collector acc path value.packagesInSet
          else if lib.isAttrs value then
            # 递归处理普通属性集
            lib.foldl' (acc: key: collector acc (path ++ [ key ]) value.${key}) acc (lib.attrNames value)
          else
            acc; # 忽略非属性/非 derivation
      in
      # 从根属性集开始收集
      collector { } [ ] attrs;
  };
  # === 统一的包发现逻辑 ===
  # 判断目录是否包含直接包文件
  hasDirectPackage =
    dirPath:
    let
      pkg = dirPath + "/package.nix";
      def = dirPath + "/default.nix";
    in
    (builtins.pathExists pkg) || (builtins.pathExists def);

  # 获取目录下的直接包文件路径（优先 package.nix）
  getDirectPackageFile =
    dirPath:
    let
      pkg = dirPath + "/package.nix";
      def = dirPath + "/default.nix";
    in
    if builtins.pathExists pkg then
      pkg
    else if builtins.pathExists def then
      def
    else
      null;

  # 递归发现：
  # - depth = 0 仅检查直接包
  # - depth > 0 若无直接包则在子目录中继续查找
  discoverAt =
    dirPath: depth:
    let
      directFile = getDirectPackageFile dirPath;
    in
    if directFile != null then
      safeImportPackage directFile
    else if depth > 0 then
      let
        contents = builtins.readDir dirPath;
        subDirs = lib.filterAttrs (name: type: type == "directory") contents;
        subNames = builtins.attrNames subDirs;
        discovered = builtins.listToAttrs (
          lib.filter (a: a.value != null) (
            map (
              n:
              let
                subPath = dirPath + "/${n}";
                result = discoverAt subPath (depth - 1);
              in
              {
                name = n;
                value = result;
              }
            ) subNames
          )
        );
      in
      if discovered != { } then discovered else null
    else
      null;

  # 发现 by-name 下的包树（两层：字母/组 -> 包）并扁平化为顶层属性
  byNameTree = discoverAt ./pkgs/by-name 2;
  allOutsidePackages = lib.collectPackages (if byNameTree == null then { } else byNameTree);

  # 发现其它分组（排除 by-name），保留分组层级
  nestedPackages =
    let
      pkgsDir = ./pkgs;
    in
    if builtins.pathExists pkgsDir then
      let
        contents = builtins.readDir pkgsDir;
        groupDirs = lib.filterAttrs (name: type: type == "directory" && name != "by-name") contents;
        groupNames = builtins.attrNames groupDirs;
        groups = map (
          groupName:
          let
            groupPath = pkgsDir + "/${groupName}";
            result = discoverAt groupPath 1;
          in
          if result != null then { ${groupName} = result; } else { }
        ) groupNames;
      in
      lib.foldl' (acc: s: acc // s) { } groups
    else
      { };
in
specialAttrs // allOutsidePackages // nestedPackages
# 按组名组织的包组（每个组是平面属性集）
