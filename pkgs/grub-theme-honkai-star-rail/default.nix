# 定义带参数的软件包，参数通过调用者注入
{
  pkgs,
  fetchurl,
  nix-update-script,
  tag ? "20250524-070052",
  characterDiff ? "Firefly_cn", # 角色差分
  useGHProxy ? false, # 可选参数：是否使用镜像
}:
# Source: https://github.com/voidlhf/StarRailGrubThemes
let
  # 定义下载源
  urls = {
    original = "https://github.com/voidlhf/StarRailGrubThemes/releases/download/${tag}/${characterDiff}.tar.gz";
    mirror = "https://ghproxy.cn/${urls.original}";
  };
  hash = "sha256-+86bOkJhTtUCZoKoUbdZERJ3+JYW/XcuSqo657JGHqc=";

  # 下载文件
  src = fetchurl {
    # 根据参数选择下载源（需确保两个源的哈希一致）
    url =
      if useGHProxy
      then urls.mirror
      else urls.original;
    hash = hash;
  };
in
  # --strip-components=1：解除一层嵌套
  # 如果压缩包内直接包含 theme.txt 和资源文件（无子目录），则无需 --strip-components=1。
  # 如果压缩包内有嵌套目录（如 grub-theme/theme.txt），需调整 --strip-components 的值。
  pkgs.stdenv.mkDerivation {
    name = "grub-theme-honkai-star-rail";
    src = src;

    # 动态解压逻辑
    # 核心修正：明确安装到$out
    installPhase = ''
      mkdir -p $out/share/grub/themes
      tar -xzf ${src} -C $out --strip-components=1
      # 验证关键文件存在
      if [ ! -f "$out/theme.txt" ]; then
        echo "ERROR: theme.txt not found in $out!"
        exit 1
      fi
    '';

    # 禁用自动解压步骤
    dontUnpack = true;
    dontBuild = true;

    # 暴露路径给其他模块使用
    passthru = {
      themeRelPath = "share/grub/themes/${characterDiff}";

      updateScript =
        nix-update-script {
        };
    };
  }
