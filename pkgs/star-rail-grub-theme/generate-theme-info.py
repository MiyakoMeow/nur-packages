#!/usr/bin/env python3
"""
自动生成 GitHub Release 主题包信息 JSON
支持指定 Release Tag
使用 nix-prefetch-url 获取 SHA256 哈希
"""

import requests
import json
import re
import os
import sys
import subprocess
import argparse


def nix_prefetch_url(url):
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
    """获取仓库的 Release 资源，支持指定 Tag"""
    # 使用 GitHub Token 提高 API 限制
    token = os.environ.get("GITHUB_TOKEN")
    headers = {"Accept": "application/vnd.github.v3+json"}
    if token:
        headers["Authorization"] = f"token {token}"

    if tag:
        # 获取特定 Tag 的 Release
        release_url = f"https://api.github.com/repos/{owner}/{repo}/releases/tags/{tag}"
        response = requests.get(release_url, headers=headers)
        if response.status_code == 404:
            raise ValueError(f"Release tag '{tag}' not found")
        response.raise_for_status()
        releases = [response.json()]
    else:
        # 获取所有 Release
        releases_url = f"https://api.github.com/repos/{owner}/{repo}/releases"
        releases = []
        page = 1
        while True:
            response = requests.get(f"{releases_url}?page={page}", headers=headers)
            response.raise_for_status()
            page_releases = response.json()
            if not page_releases:
                break
            releases.extend(page_releases)
            page += 1

    assets = []
    for release in releases:
        for asset in release.get("assets", []):
            if asset["name"].endswith((".tar.gz", ".gz")):
                assets.append(
                    {
                        "name": asset["name"],
                        "url": asset["browser_download_url"],
                        "release_tag": release["tag_name"],
                    }
                )
    return assets


def generate_package_name(asset_name, release_tag=None):
    """生成 Nix 包名"""
    # 移除文件扩展名
    base = re.sub(r"\.(tar\.gz|gz)$", "", asset_name, flags=re.IGNORECASE)
    # 移除所有点号
    clean = base.replace(".", "")
    # 转换为小写
    name = f"grub-theme-honkai-star-rail-{clean.lower()}"

    # 如果指定了 Tag，添加到包名
    if release_tag:
        # 清理 Tag 名称
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

    args = parser.parse_args()

    print(f"Fetching releases for {args.owner}/{args.repo}", file=sys.stderr)
    if args.tag:
        print(f"Processing specific tag: {args.tag}", file=sys.stderr)

    try:
        assets = get_release_assets(args.owner, args.repo, args.tag)
        print(f"Found {len(assets)} .gz assets", file=sys.stderr)

        # 生成包信息字典
        theme_info = {}
        for i, asset in enumerate(assets):
            print(f"Processing {i + 1}/{len(assets)}: {asset['name']}", file=sys.stderr)
            try:
                # 包名先不加tag
                # pname = generate_package_name(asset["name"], asset.get("release_tag"))
                pname = generate_package_name(asset["name"], None)
                sha256 = nix_prefetch_url(asset["url"])

                theme_info[pname] = {
                    "url": asset["url"],
                    "sha256": sha256,
                    "tag": asset.get("release_tag"),
                }

                print(f"  Package: {pname}", file=sys.stderr)
                print(f"  SHA256: {sha256}", file=sys.stderr)
            except Exception as e:
                print(f"  Error processing {asset['name']}: {str(e)}", file=sys.stderr)

        # 输出 JSON
        print(json.dumps(theme_info, indent=2))

    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
