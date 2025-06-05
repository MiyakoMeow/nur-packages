#!/usr/bin/env python3
"""
生成主题包信息的 JSON 文件并保存到 themes.json
"""

import json
import os
import sys
import argparse
import subprocess
import requests
import re
import logging

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    stream=sys.stderr,
)
logger = logging.getLogger()


def calculate_sha256(url):
    """使用 nix-prefetch-url 获取文件的 SHA256 哈希"""
    try:
        result = subprocess.run(
            ["nix-prefetch-url", "--type", "sha256", url],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error prefetching {url}: {e.stderr}", file=sys.stderr)
        raise
    except FileNotFoundError:
        print(
            "Error: nix-prefetch-url not found. Make sure Nix is installed.",
            file=sys.stderr,
        )
        raise


def get_release_assets(owner, repo, tag=None):
    """获取仓库的 Release 资源"""
    try:
        token = os.environ.get("GITHUB_TOKEN")
        headers = {"Accept": "application/vnd.github.v3+json"}
        if token:
            headers["Authorization"] = f"token {token}"

        if tag:
            release_url = (
                f"https://api.github.com/repos/{owner}/{repo}/releases/tags/{tag}"
            )
            response = requests.get(release_url, headers=headers, timeout=15)
            response.raise_for_status()
            releases = [response.json()]
        else:
            releases_url = f"https://api.github.com/repos/{owner}/{repo}/releases"
            response = requests.get(releases_url, headers=headers, timeout=15)
            response.raise_for_status()
            releases = response.json()

        assets = []
        for release in releases:
            for asset in release.get("assets", []):
                if asset["name"].lower().endswith((".tar.gz", ".gz")):
                    assets.append(
                        {
                            "name": asset["name"],
                            "url": asset["browser_download_url"],
                            "release_tag": release["tag_name"],
                        }
                    )
        return assets
    except Exception as e:
        logger.error(f"Error fetching releases: {str(e)}")
        return []


def generate_package_name(asset_name, release_tag=None):
    """生成 Nix 包名"""
    base = re.sub(r"\.(tar\.gz|gz)$", "", asset_name, flags=re.IGNORECASE)
    clean = base.replace(".", "")
    name = f"grub-theme-honkai-star-rail-{clean.lower()}"

    if release_tag:
        clean_tag = re.sub(r"[^a-zA-Z0-9_-]", "", release_tag.replace("/", "-"))
        name += f"-{clean_tag}"

    return name


def main():
    parser = argparse.ArgumentParser(description="Generate theme package info JSON")
    parser.add_argument("--owner", default="voidlhf", help="GitHub repository owner")
    parser.add_argument(
        "--repo", default="StarRailGrubThemes", help="GitHub repository name"
    )
    parser.add_argument("--tag", help="Specific release tag to process")
    parser.add_argument("--output", default="themes.json", help="Output JSON file path")

    args = parser.parse_args()

    logger.info(f"Fetching releases for {args.owner}/{args.repo}")
    assets = get_release_assets(args.owner, args.repo, args.tag)
    logger.info(f"Found {len(assets)} .gz assets")

    theme_info = {}
    for asset in assets:
        pname = generate_package_name(asset["name"], asset.get("release_tag"))
        logger.info(f"Processing: {pname}")

        sha256 = calculate_sha256(asset["url"])
        if not sha256:
            continue

        theme_info[pname] = {
            "url": asset["url"],
            "sha256": sha256,
            "tag": asset.get("release_tag"),
        }
        # Debug
        print(theme_info)

    # 保存到文件
    with open(args.output, "w") as f:
        json.dump(theme_info, f, indent=2)

    logger.info(f"Saved theme info to {args.output}")


if __name__ == "__main__":
    main()
