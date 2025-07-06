{
  lib,
  pkgs,
  stdenvNoCC,
  fetchFromGitHub,
  writeScript,
  ...
}: let
  # 仓库信息
  owner = "13atm01";
  repo = "GRUB-Theme";
  rev = "master"; # 替换为实际commit
  hash = "sha256-yceSIVxVpUNUDFjMXGYGkD4qyMRajU7TyDg/gl2NmAs="; # 替换为实际SHA256

  # 获取仓库源码
  src = fetchFromGitHub {
    inherit owner repo rev hash;
  };

  # 读取主题列表
  themeList = lib.importJSON ./theme-list.json;

  # 为每个主题创建包的函数
  mkThemePackage = packageName: themePath:
    stdenvNoCC.mkDerivation {
      name = packageName;
      pname = packageName;
      inherit src;

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

      passthru.updateScript = let
        pyScript = pkgs.writeText "update-grub-themes.py" ''
          #!/usr/bin/env python3
          import os
          import json
          import re
          import sys
          import subprocess
          import tempfile
          from pathlib import Path

          # 仓库配置信息
          REPO_OWNER = "13atm01"
          REPO_NAME = "GRUB-Theme"
          REPO_BRANCH = "master"
          REPO_URL = f"https://github.com/{REPO_OWNER}/{REPO_NAME}.git"

          def sanitize_name(name):
              """将主题名转换为包名格式"""
              name = name.lower()
              name = re.sub(r"[^a-z0-9]", " ", name)
              name = re.sub(r"\s+", "-", name).strip("-")
              return name.rstrip("-")

          def generate_theme_list(cache_path, output_file):
              """生成主题列表JSON文件"""
              theme_data = {}
              for theme_dir in os.listdir(cache_path):
                  theme_path = os.path.join(cache_path, theme_dir)
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
              return len(theme_data)

          def main(output_dir):
              """主处理函数"""
              with tempfile.TemporaryDirectory() as tmpdir:
                  repo_path = os.path.join(tmpdir, REPO_NAME)
                  # 克隆仓库
                  subprocess.run([
                      "git", "clone", "--branch", REPO_BRANCH,
                      "--depth", "1", REPO_URL, repo_path
                  ], check=True)

                  # 生成主题列表
                  output_file = os.path.join(output_dir, "themes.json")
                  count = generate_theme_list(repo_path, output_file)
                  print(f"生成 {count} 个主题到 {output_file}")
                  return 0 if count > 0 else 1

          if __name__ == "__main__":
              if len(sys.argv) != 2:
                  print("用法: python update_script.py <output_directory>")
                  sys.exit(1)
              sys.exit(main(sys.argv[1]))
        '';
      in
        writeScript "update-13atm01-grub-themes" ''
          set -euo pipefail
          export PATH="${pkgs.git}/bin:${pkgs.python3}/bin:$PATH"

          # 获取包目录路径
          PKG_DIR="$(dirname "$0")"

          # 执行Python脚本
          exec python3 ${pyScript} "$PKG_DIR"
        '';

      meta = with lib; {
        description = "GRUB2 theme '${packageName}' from ${owner}/${repo}";
        homepage = "https://github.com/${owner}/${repo}";
        license = licenses.gpl3;
        platforms = platforms.all;
      };
    };
in {
  # 所有主题包的集合
  packagesInSet = lib.mapAttrs mkThemePackage themeList;
}
