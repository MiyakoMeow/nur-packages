{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}: let
  # 从GitHub获取整个主题仓库
  src = fetchFromGitHub {
    owner = "13atm01";
    repo = "GRUB-Theme";
    rev = "master";
    hash = "sha256-ezNxeaiRCGEp5lsHph9lwQ4OEVUHHGssDeCIbDF7X6w=";
  };

  # 包名转换函数：小写化 + 替换非字母数字字符为-
  sanitizeName = name: let
    lower = lib.toLower name;
    replaced = lib.replaceStrings [" " "_" "." "," "!" "@" "#" "$" "%" "^" "&" "*" "(" ")" "+" "=" "{" "}" "[" "]" "|" "\\" "/" ":" ";" "'" "<" ">" "?" "`" "~"] (lib.genList (_: "-") 31) lower;
    normalized = lib.replaceStrings ["--"] ["-"] replaced; # 替换连续--
  in
    lib.removeSuffix "-" normalized; # 移除末尾多余的-

  # 获取所有主题文件夹
  themeDirs = lib.attrNames (lib.filterAttrs (name: type: type == "directory") (builtins.readDir src));

  # 为每个主题创建包的函数
  mkThemePackage = themeDir: let
    packageName = sanitizeName themeDir + "-grub-theme";
    # 获取内层目录（处理空格问题）
    innerDirPath = "${src}/${themeDir}";
    innerDirs = lib.attrNames (lib.filterAttrs
      (n: t: t == "directory")
      (builtins.readDir innerDirPath));

    # 验证只有一个内层目录
    innerDir =
      if lib.length innerDirs != 1
      then throw "主题'${themeDir}'应包含且仅包含一个子目录"
      else builtins.head innerDirs;
  in
    stdenvNoCC.mkDerivation {
      name = packageName;
      src = src;

      # 不需要解压和配置步骤
      dontUnpack = true;
      dontConfigure = true;
      dontBuild = true;

      installPhase = ''
        # 创建输出目录
        mkdir -p $out

        # 复制主题内容（跳过外层两层目录）
        cp -rT '${innerDirPath}/${innerDir}' "$out"

        # 验证themes.txt存在
        if [ ! -f "$out/theme.txt" ]; then
          echo "ERROR: theme.txt missing in output!"
          exit 1
        fi
      '';

      meta = with lib; {
        description = "GRUB2 theme '${themeDir}' from 13atm01/GRUB-Theme";
        homepage = "https://github.com/13atm01/GRUB-Theme";
        license = licenses.gpl3;
        maintainers = [];
        platforms = platforms.all;
      };
    };
in
  # 为每个主题目录生成包
  builtins.listToAttrs (map
    (dir: {
      name = sanitizeName dir;
      value = mkThemePackage dir;
    })
    themeDirs)
