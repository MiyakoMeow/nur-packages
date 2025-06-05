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
import hashlib

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    stream=sys.stderr,
)
logger = logging.getLogger()


def calculate_sha256_nix(url):
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


def calculate_sha256_request(url):
    """计算远程文件的 SHA256 哈希值"""
    try:
        headers = {"Accept-Encoding": "identity"}
        response = requests.get(url, stream=True, headers=headers, timeout=30)
        response.raise_for_status()

        hasher = hashlib.sha256()
        for chunk in response.iter_content(chunk_size=8192):
            if chunk:
                hasher.update(chunk)

        return hasher.hexdigest()
    except Exception as e:
        logger.error(f"Error downloading {url}: {str(e)}")
        return None


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


def generate_package_name(asset_name):
    """生成 Nix 包名"""
    base = re.sub(r"\.(tar\.gz|gz)$", "", asset_name, flags=re.IGNORECASE)
    clean = base.replace(".", "")
    name = f"star-rail-grub-theme-{clean.lower()}"

    return name


def main():
    parser = argparse.ArgumentParser(description="Generate theme package info JSON")
    parser.add_argument("--owner", default="voidlhf", help="GitHub repository owner")
    parser.add_argument(
        "--repo", default="StarRailGrubThemes", help="GitHub repository name"
    )
    parser.add_argument("--tag", help="Specific release tag to process")
    parser.add_argument(
        "--output",
        default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "themes.json"),
        help="Output JSON file path",
    )

    args = parser.parse_args()

    logger.info(f"Fetching releases for {args.owner}/{args.repo}")
    assets = get_release_assets(args.owner, args.repo, args.tag)
    logger.info(f"Found {len(assets)} .gz assets")

    theme_info = {}
    for asset in assets:
        pname = generate_package_name(asset["name"])
        logger.info(f"Processing: {pname}")

        sha256 = calculate_sha256_request(asset["url"])
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
