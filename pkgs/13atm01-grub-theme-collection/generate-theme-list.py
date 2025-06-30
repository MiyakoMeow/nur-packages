#!/usr/bin/env python3
import os
import json
import re
import sys


def sanitize_name(name):
    """将主题名转换为包名格式"""
    # 转换为小写
    name = name.lower()
    # 替换非字母数字字符为空格
    name = re.sub(r"[^a-z0-9]", " ", name)
    # 合并连续空格为单个破折号
    name = re.sub(r"\s+", "-", name).strip("-")
    if name.endswith("-"):
        name = name[:-1]
    return name


def generate_theme_list(cache_path, output_file):
    """生成主题列表JSON文件"""
    theme_data = {}

    for theme_dir in os.listdir(cache_path):
        theme_path = os.path.join(cache_path, theme_dir)

        if not os.path.isdir(theme_path):
            continue

        # 获取内层目录
        inner_dirs = [
            d
            for d in os.listdir(theme_path)
            if os.path.isdir(os.path.join(theme_path, d))
        ]

        if len(inner_dirs) != 1:
            print(
                f"警告: 主题 '{theme_dir}' 应包含且仅包含一个子目录 (找到 {len(inner_dirs)} 个)"
            )
            continue

        inner_dir = inner_dirs[0]
        package_name = sanitize_name(theme_dir) + "-grub-theme"

        # 验证themes.txt存在
        theme_txt_path = os.path.join(theme_path, inner_dir, "theme.txt")
        if not os.path.exists(theme_txt_path):
            print(f"警告: 主题 '{theme_dir}' 缺少 theme.txt 文件")
            continue

        # 存储相对路径
        theme_data[package_name] = os.path.join(theme_dir, inner_dir)

    # 写入JSON文件
    with open(output_file, "w") as f:
        json.dump(theme_data, f, indent=2, sort_keys=True)

    print(f"生成主题列表: 共找到 {len(theme_data)} 个有效主题")
    return len(theme_data)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("用法: generate-theme-list.py <仓库路径> <输出JSON文件>")
        sys.exit(1)

    cache_path = sys.argv[1]
    output_file = sys.argv[2]

    if not os.path.isdir(cache_path):
        os.mkdir(cache_path)

    count = generate_theme_list(cache_path, output_file)
    sys.exit(0 if count > 0 else 1)
