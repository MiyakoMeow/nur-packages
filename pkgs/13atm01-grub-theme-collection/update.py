#!/usr/bin/env python3
"""
GRUB Theme Repository Processor

该脚本负责：
1. 克隆指定GitHub仓库到本地cache目录
2. 调用generate-theme-list.py生成主题列表JSON

使用示例:
    python repo-processor.py
"""

import subprocess
import argparse
from pathlib import Path

# 仓库配置信息
REPO_OWNER = "13atm01"
REPO_NAME = "GRUB-Theme"
REPO_BRANCH = "master"
REPO_URL = f"https://github.com/{REPO_OWNER}/{REPO_NAME}.git"


def setup_arguments():
    """配置命令行参数解析器"""
    parser = argparse.ArgumentParser(description="处理GRUB主题仓库并生成主题列表JSON")
    parser.add_argument(
        "--force", action="store_true", help="强制重新克隆仓库（覆盖现有内容）"
    )
    return parser.parse_args()


def ensure_cache_dir(script_dir: Path) -> Path:
    """确保cache目录存在"""
    cache_dir = script_dir / "cache"
    cache_dir.mkdir(exist_ok=True)
    return cache_dir


def clone_repository(repo_path: Path, force: bool = False):
    """克隆或更新Git仓库"""
    if force and repo_path.exists():
        print(f"强制删除现有仓库: {repo_path}")
        subprocess.run(["rm", "-rf", str(repo_path)], check=True)

    if not repo_path.exists():
        print(f"正在克隆仓库: {REPO_URL}")
        subprocess.run(
            [
                "git",
                "clone",
                "--branch",
                REPO_BRANCH,
                "--depth",
                "1",
                REPO_URL,
                str(repo_path),
            ],
            check=True,
        )
        print("仓库克隆完成")
    else:
        print(f"使用现有仓库: {repo_path}")
        print("拉取最新更改...")
        subprocess.run(
            ["git", "-C", str(repo_path), "pull", "origin", REPO_BRANCH], check=True
        )


def generate_theme_list(script_dir: Path, repo_path: Path):
    """调用生成脚本创建主题列表JSON"""
    generator_script = script_dir / "generate-theme-list.py"
    output_file = script_dir / "theme-list.json"

    if not generator_script.exists():
        raise FileNotFoundError(f"生成脚本未找到: {generator_script}")

    print("正在生成主题列表...")
    subprocess.run(
        [
            "python3",
            str(generator_script),
            str(repo_path),  # 仓库路径参数
            str(output_file),  # 输出文件路径
        ],
        check=True,
    )

    print(f"主题列表已生成: {output_file}")


def main():
    """主处理流程"""
    args = setup_arguments()

    # 获取当前脚本所在目录
    script_dir = Path(__file__).parent.resolve()

    try:
        # 准备缓存目录
        cache_dir = ensure_cache_dir(script_dir)
        repo_path = cache_dir / REPO_NAME

        # 克隆/更新仓库
        clone_repository(repo_path, args.force)

        # 生成主题列表
        generate_theme_list(script_dir, repo_path)

        print("处理完成")
    except subprocess.CalledProcessError as e:
        print(f"命令执行失败: {e}")
        exit(1)
    except Exception as e:
        print(f"处理出错: {e}")
        exit(1)


if __name__ == "__main__":
    main()
