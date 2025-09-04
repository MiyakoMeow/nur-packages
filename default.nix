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
  # 自动检测所有嵌套包目录（除了by-name）
  nestedPackages =
    let
      pkgsDir = ./pkgs;
    in
    if builtins.pathExists pkgsDir then
      let
        allContents = builtins.readDir pkgsDir;
        # 过滤出目录，排除by-name目录
        nestedDirs = lib.filterAttrs (name: type: type == "directory" && name != "by-name") allContents;
        nestedDirNames = builtins.attrNames nestedDirs;

        # 处理每个嵌套目录
        nestedPackageSets = map (
          dirName:
          let
            dirPath = pkgsDir + "/${dirName}";
            dirContents = builtins.readDir dirPath;
            packageDirs = lib.filterAttrs (name: type: type == "directory") dirContents;
            packageNames = builtins.attrNames packageDirs;

            # 为每个包目录创建包
            packageAttrs = builtins.listToAttrs (
              map (
                pkgName:
                let
                  pkgDir = dirPath + "/${pkgName}";
                  pkgFile = pkgDir + "/package.nix";
                in
                if builtins.pathExists pkgFile then
                  {
                    name = pkgName;
                    value = importPackage pkgFile;
                  }
                else
                  null
              ) packageNames
            );

            # 过滤掉null值
            validPackages = lib.filterAttrs (name: value: value != null) packageAttrs;
          in
          if validPackages != { } then { ${dirName} = validPackages; } else { }
        ) nestedDirNames;

        # 合并所有嵌套包集合
        mergedNestedPackages = lib.foldl' (acc: pkgSet: acc // pkgSet) { } nestedPackageSets;
      in
      mergedNestedPackages
    else
      { };

  # 自动发现所有包目录
  packagesDir = ./pkgs/by-name;
  # 获取所有by-name目录
  byNameDirs = builtins.attrNames (builtins.readDir packagesDir);

  # 为每个目录收集所有的package.nix文件（递归查找子目录）
  allPackageFiles = lib.concatLists (
    map (
      dirName:
      let
        dirPath = packagesDir + "/${dirName}";
        dirContents = builtins.readDir dirPath;
        # 获取所有子目录
        subDirs = lib.filterAttrs (name: type: type == "directory") dirContents;
        subDirNames = builtins.attrNames subDirs;

        # 为每个子目录查找package.nix
        packageFiles = map (
          subDirName:
          let
            subDirPath = dirPath + "/${subDirName}";
            packageFile = subDirPath + "/package.nix";
          in
          if builtins.pathExists packageFile then
            {
              name = subDirName;
              path = packageFile;
            }
          else
            null
        ) subDirNames;

        # 过滤掉null值
        validPackageFiles = lib.filter (file: file != null) packageFiles;
      in
      validPackageFiles
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
in
specialAttrs // allOutsidePackages // nestedPackages
# 按组名组织的包组（每个组是平面属性集）
