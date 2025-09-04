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
  # === 处理特殊嵌套包结构 ===
  # 自动检测 ros2 目录下的包
  ros2Packages =
    let
      ros2Dir = ./pkgs/ros2;
    in
    if builtins.pathExists ros2Dir then
      let
        ros2Contents = builtins.readDir ros2Dir;
        packageDirs = lib.filterAttrs (name: type: type == "directory") ros2Contents;
        packageNames = builtins.attrNames packageDirs;
        
        # 为每个包目录创建包
        packageAttrs = builtins.listToAttrs (
          map (pkgName: 
            let
              pkgDir = ros2Dir + "/${pkgName}";
              pkgFile = pkgDir + "/package.nix";
            in
            if builtins.pathExists pkgFile then
              { name = pkgName; value = importPackage pkgFile; }
            else
              null
          ) packageNames
        );
        
        # 过滤掉null值
        validPackages = lib.filterAttrs (name: value: value != null) packageAttrs;
      in
      if validPackages != {} then
        { ros2 = validPackages; }
      else
        {}
    else
      {};
  # 自动发现所有包目录
  packagesDir = ./pkgs/by-name;
  # 获取所有by-name目录
  byNameDirs = builtins.attrNames (builtins.readDir packagesDir);

  # 为每个目录收集所有的.nix文件
  allPackageFiles = lib.concatLists (
    map (
      dirName:
      let
        dirPath = packagesDir + "/${dirName}";
        dirContents = builtins.readDir dirPath;
        nixFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) dirContents;
      in
      map (fileName: {
        name = fileName;
        path = dirPath + "/${fileName}";
      }) (builtins.attrNames nixFiles)
    ) byNameDirs
  );

  # 为每个包文件创建包，并展开所有的包
  allOutsidePackages = lib.collectPackages (
    builtins.listToAttrs (
      map (pkgFile: {
        name = toString pkgFile.path;
        value = importPackage pkgFile.path;
      }) allPackageFiles
    )
  );
  # === 处理 pkg-groups 目录 ===
  pkgGroupsDir = ./pkg-groups;
  # 获取所有组名（目录需存在）
  groupNames =
    if builtins.pathExists pkgGroupsDir then
      builtins.attrNames (builtins.readDir pkgGroupsDir)
    else
      [ ];

  # 导入组内所有包，并收集为平面属性集
  importGroup =
    groupName:
    let
      groupDir = pkgGroupsDir + "/${groupName}";
      pkgNames = builtins.attrNames (builtins.readDir groupDir);

      # 创建组内包的原始属性集
      rawGroup = builtins.listToAttrs (
        map (pkgName: {
          name = pkgName;
          value = importPackage (groupDir + "/${pkgName}");
        }) pkgNames
      );
    in
    # 关键修改：对每个组应用 collectPackages
    lib.collectPackages rawGroup;

  # 构建组属性集 { 组名 = 平面包集合; ... }
  groupedPackages = builtins.listToAttrs (
    map (groupName: {
      name = groupName;
      value = importGroup groupName;
    }) groupNames
  );
in
specialAttrs // allOutsidePackages // groupedPackages // ros2Packages
# 按组名组织的包组（每个组是平面属性集）
