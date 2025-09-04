#!/usr/bin/env nix-shell
#!nix-shell -i bash -p jq coreutils gnused git
# shellcheck shell=bash

set -euo pipefail

# 获取包目录路径 (nix文件所在位置)
PKG_DIR="$(dirname "${BASH_SOURCE[0]}")"
OUTPUT_FILE="$PKG_DIR/theme-list.json"

echo "正在更新GRUB主题列表..."
echo "输出位置: $OUTPUT_FILE"

# 处理仓库路径参数
REPO_PATH=""
CLEANUP_REPO=0

if [[ $# -gt 0 ]]; then
    REPO_PATH="$1"
    if [[ ! -d "$REPO_PATH" ]]; then
        echo "错误: 提供的仓库路径不存在或不是目录: $REPO_PATH" >&2
        exit 1
    fi
    echo "使用外部仓库路径: $REPO_PATH"
else
    # 没有提供参数，创建临时仓库
    echo "未提供仓库路径，将临时克隆仓库..."
    REPO_PATH=$(mktemp -d)
    trap 'rm -rf "$REPO_PATH"' EXIT
    CLEANUP_REPO=1

    git clone \
        --branch master \
        --depth 1 \
        https://github.com/13atm01/GRUB-Theme.git \
        "$REPO_PATH"
    echo "临时克隆完成: $REPO_PATH"
fi

# 名称清理函数：转换为小写，替换非字母数字字符为连字符
sanitize_name() {
    local name="$1"
    # 转换为小写
    name=$(tr '[:upper:]' '[:lower:]' <<<"$name")
    # 替换非字母数字字符为空格
    name=$(sed -e 's/[^a-z0-9]/ /g' <<<"$name")
    # 压缩连续空格为单个连字符
    name=$(sed -e 's/\s\+/-/g' <<<"$name")
    # 去除首尾连字符
    name=$(sed -e 's/^-\+//' -e 's/-\+$//' <<<"$name")
    echo "$name"
}

# 初始化JSON对象
echo '{}' >"$OUTPUT_FILE"
count=0

# 遍历主题目录
while IFS= read -r -d $'\0' theme_dir; do
    dir_name=$(basename "$theme_dir")

    # 获取内部子目录
    inner_dirs=()
    while IFS= read -r -d $'\0' inner_dir; do
        inner_dirs+=("$inner_dir")
    done < <(find "$theme_dir" -maxdepth 1 -mindepth 1 -type d -print0)

    # 检查子目录数量
    if [[ ${#inner_dirs[@]} -ne 1 ]]; then
        echo "警告: 主题 '$dir_name' 应包含且仅包含一个子目录 (找到 ${#inner_dirs[@]} 个)" >&2
        continue
    fi

    inner_path="${inner_dirs[0]}"
    inner_dir_name=$(basename "$inner_path")

    # 检查theme.txt文件
    if [[ ! -f "$inner_path/theme.txt" ]]; then
        echo "警告: 主题 '$dir_name' 缺少 theme.txt 文件" >&2
        continue
    fi

    # 生成包名
    package_name=$(sanitize_name "$dir_name")"-grub-theme"
    theme_path="$dir_name/$inner_dir_name"

    # 使用jq更新JSON对象
    jq --arg pkg "$package_name" --arg path "$theme_path" \
        '. + { ($pkg): $path }' "$OUTPUT_FILE" >"$OUTPUT_FILE.tmp"
    mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

    ((count++))
done < <(find "$REPO_PATH" -maxdepth 1 -mindepth 1 -type d -print0)

# 美化输出格式
jq -S . "$OUTPUT_FILE" >"$OUTPUT_FILE.tmp"
mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

echo "成功生成 $count 个主题到 $OUTPUT_FILE"

# 清理临时仓库（如果需要）
if [[ $CLEANUP_REPO -eq 1 ]]; then
    echo "清理临时仓库..."
    rm -rf "$REPO_PATH"
fi

# 如果没有找到主题则返回错误
if [[ $count -eq 0 ]]; then
    exit 1
fi
