{
  lib,
  pkgs,
  stdenvNoCC,
  fetchFromGitHub,
  writeScript,
  nix-update-script,
  ...
}: let
  # 仓库信息
  owner = "13atm01";
  repo = "GRUB-Theme";
  rev = "f4d764cab6bed5ab29e31965cca59420cc84ee0a"; # 替换为实际commit
  hash = "sha256-yceSIVxVpUNUDFjMXGYGkD4qyMRajU7TyDg/gl2NmAs="; # 替换为实际SHA256
  version = "Lyco-v1.0-unstable-2025-06-15";
  # 获取仓库源码
  src = fetchFromGitHub {
    inherit owner repo rev hash;
  };

  metaPkg = stdenvNoCC.mkDerivation rec {
    pname = "13atm01-grub-themes-meta";
    inherit src version;

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    dontInstall = true;

    passthru.updateScript = nix-update-script {
      attrPath = pname;
      extraArgs = [
        "--flake"
        "--version=branch"
      ];
    };
    meta = with lib; {
      description = "GRUB2 theme metaPack from ${owner}/${repo}";
      homepage = "https://github.com/${owner}/${repo}";
      license = licenses.gpl3;
      platforms = platforms.all;
    };
  };

  # 读取主题列表
  themeList = lib.importJSON ./theme-list.json;

  # 为每个主题创建包的函数
  mkThemePackage = packageName: themePath:
    stdenvNoCC.mkDerivation {
      name = packageName;
      pname = packageName;
      inherit src version;

      dontUnpack = true;
      dontConfigure = true;
      dontBuild = true;

      installPhase = ''
        # 创建输出目录
        mkdir -p "$out"

        # 复制主题内容
        cp -rT "${src}/${themePath}" "$out"

        # 验证必要文件存在
        if [ ! -f "$out/theme.txt" ]; then
          echo "错误：未找到 theme.txt 文件"
          exit 1
        fi
      '';

      passthru.updateScript = pkgs.writeShellApplication {
        name = "update-13atm01-grub-themes";
        runtimeInputs = [pkgs.git pkgs.python3];
        text = ''
          set -euo pipefail

          # 获取包目录路径 (nix文件所在位置)
          PKG_DIR="$(dirname "$0")"
          OUTPUT_FILE="$PKG_DIR/themes.json"

          echo "正在更新GRUB主题列表..."
          echo "输出位置: $OUTPUT_FILE"

          # 使用临时目录处理
          TEMP_DIR=$(mktemp -d)
          trap 'rm -rf "$TEMP_DIR"' EXIT

          # 克隆仓库
          git clone \
            --branch master \
            --depth 1 \
            https://github.com/13atm01/GRUB-Theme.git \
            "$TEMP_DIR/repo"

          # 处理主题并生成JSON
          python3 <<EOF
          import os
          import json
          import re
          import sys

          def sanitize_name(name):
              name = name.lower()
              name = re.sub(r"[^a-z0-9]", " ", name)
              name = re.sub(r"\s+", "-", name).strip("-")
              return name.rstrip("-")

          repo_path = "$TEMP_DIR/repo"
          output_file = "$OUTPUT_FILE"

          theme_data = {}
          for theme_dir in os.listdir(repo_path):
              theme_path = os.path.join(repo_path, theme_dir)
              if not os.path.isdir(theme_path):
                  continue

              inner_dirs = [d for d in os.listdir(theme_path)
                           if os.path.isdir(os.path.join(theme_path, d))]

              if len(inner_dirs) != 1:
                  print(f"警告: 主题 '{theme_dir}' 应包含且仅包含一个子目录 (找到 {len(inner_dirs)} 个)")
                  continue

              inner_dir = inner_dirs[0]
              package_name = sanitize_name(theme_dir) + "-grub-theme"
              theme_txt_path = os.path.join(theme_path, inner_dir, "theme.txt")

              if not os.path.exists(theme_txt_path):
                  print(f"警告: 主题 '{theme_dir}' 缺少 theme.txt 文件")
                  continue

              theme_data[package_name] = os.path.join(theme_dir, inner_dir)

          with open(output_file, "w") as f:
              json.dump(theme_data, f, indent=2, sort_keys=True)

          count = len(theme_data)
          print(f"成功生成 {count} 个主题到 {output_file}")
          sys.exit(0 if count > 0 else 1)
          EOF
        '';
      };
      meta = with lib; {
        description = "GRUB2 theme '${packageName}' from ${owner}/${repo}";
        homepage = "https://github.com/${owner}/${repo}";
        license = licenses.gpl3;
        platforms = platforms.all;
      };
    };
in {
  # 所有主题包的集合
  packagesInSet = lib.mapAttrs mkThemePackage themeList // {meta = metaPkg;};
}
