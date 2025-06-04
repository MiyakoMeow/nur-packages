{
  lib,
  pkgs,
  fetchurl,
  nix-update-script,
}: let
  version = "v2.0.4";
in
  # --strip-components=1：解除一层嵌套
  # 如果压缩包内直接包含 theme.txt 和资源文件（无子目录），则无需 --strip-components=1。
  # 如果压缩包内有嵌套目录（如 grub-theme/theme.txt），需调整 --strip-components 的值。
  pkgs.stdenv.mkDerivation {
    name = "grub-theme-suisei";
    version = version;
    src = fetchurl {
      # 根据参数选择下载源（需确保两个源的哈希一致）
      url = "https://github.com/kirakiraAZK/suiGRUB/releases/download/${version}/Suisei.tar.gz";
      hash = "sha256-+86bOkJhTtUCZoKoUbdZERJ3+JYW/XcuSqo657JGHqc="; # TODO: Fix
    };

    # 动态解压逻辑
    # 核心修正：明确安装到$out
    installPhase = ''
      mkdir -p $out
      tar -xzf $src -C $out --strip-components=2
      # 验证关键文件存在
      if [ ! -f "$out/theme.txt" ]; then
        echo "ERROR: theme.txt not found in $out!"
        exit 1
      fi
    '';

    # 禁用自动解压步骤
    dontUnpack = true;
    dontBuild = true;

    passthru = {
      updateScript =
        nix-update-script {
        };
    };

    meta = with lib; {
      description = "suiGRUB";
      homepage = "https://github.com/kirakiraAZK/suiGRUB";
      license = licenses.unlicense;
    };
  }
