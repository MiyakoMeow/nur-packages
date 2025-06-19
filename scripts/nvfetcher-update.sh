#!/usr/bin/env bash
set -euo pipefail

# 安装 nvfetcher (来自 nixpkgs)
echo "🔧 安装 nvfetcher..."
nix-env -iA nixpkgs.nvfetcher

# 更新源文件
echo "🔄 运行 nvfetcher..."
nvfetcher -c ./nvfetcher.toml --build-dir ./pkgs/_sources

# 检查是否有更新
if [[ -n $(git status --porcelain ./pkgs/_sources) ]]; then
    echo "✅ 检测到更新!"
    git add ./pkgs/_sources
    git commit -m "chore: auto-update via nvfetcher"
    echo "::set-output name=has_updates::true" # 设置输出变量
    exit 0
else
    echo "ℹ️ 无可用更新"
    echo "::set-output name=has_updates::false" # 设置输出变量
    exit 0                                      # 正常退出避免工作流失败
fi
