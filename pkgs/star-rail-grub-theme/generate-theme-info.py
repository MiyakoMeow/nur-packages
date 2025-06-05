#!/usr/bin/env python3
"""
生成主题包信息的JSON文件
支持指定Release Tag
"""

import requests
import json
import re
import os
import sys
import argparse
import hashlib
import time
import logging

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    stream=sys.stderr,
)
logger = logging.getLogger()


def calculate_sha256(url, max_retries=3, backoff_factor=2):
    """计算远程文件的SHA256哈希值"""
    retries = 0
    while retries <= max_retries:
        try:
            # 设置请求头，防止自动解压
            headers = {"Accept-Encoding": "identity"}
            response = requests.get(url, stream=True, headers=headers, timeout=30)
            response.raise_for_status()

            hasher = hashlib.sha256()
            total_size = 0
            start_time = time.time()

            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    hasher.update(chunk)
                    total_size += len(chunk)

            elapsed = time.time() - start_time
            speed = total_size / (1024 * 1024 * elapsed) if elapsed > 0 else 0
            logger.info(
                f"Downloaded {total_size / 1024 / 1024:.2f} MB in {elapsed:.2f}s ({speed:.2f} MB/s)"
            )

            return hasher.hexdigest()

        except (requests.exceptions.RequestException, IOError) as e:
            retries += 1
            if retries > max_retries:
                logger.error(f"Failed to download {url} after {max_retries} attempts")
                raise

            wait_time = backoff_factor**retries
            logger.warning(
                f"Retry {retries}/{max_retries} for {url} after {wait_time}s: {str(e)}"
            )
            time.sleep(wait_time)


def get_release_assets(owner, repo, tag=None, max_retries=3):
    """获取仓库的Release资源"""
    retries = 0
    while retries <= max_retries:
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
                if response.status_code == 404:
                    raise ValueError(
                        f"Release tag '{tag}' not found for {owner}/{repo}"
                    )
                response.raise_for_status()
                releases = [response.json()]
            else:
                releases_url = f"https://api.github.com/repos/{owner}/{repo}/releases"
                releases = []
                page = 1
                while True:
                    response = requests.get(
                        f"{releases_url}?page={page}", headers=headers, timeout=15
                    )
                    response.raise_for_status()
                    page_releases = response.json()
                    if not page_releases:
                        break
                    releases.extend(page_releases)
                    page += 1

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

        except (requests.exceptions.RequestException, ValueError) as e:
            retries += 1
            if retries > max_retries:
                logger.error(f"Failed to fetch releases after {max_retries} attempts")
                raise

            wait_time = 2**retries
            logger.warning(f"Retry {retries}/{max_retries} for releases: {str(e)}")
            time.sleep(wait_time)


def generate_package_name(asset_name, release_tag=None):
    """生成Nix包名"""
    # 移除文件扩展名
    base = re.sub(r"\.(tar\.gz|gz)$", "", asset_name, flags=re.IGNORECASE)
    # 移除所有点号
    clean = base.replace(".", "")
    # 转换为小写
    name = f"star-rail-grub-theme-{clean.lower()}"

    # 添加Tag后缀
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

    args = parser.parse_args()

    logger.info(f"Fetching releases for {args.owner}/{args.repo}")
    if args.tag:
        logger.info(f"Processing specific tag: {args.tag}")

    try:
        assets = get_release_assets(args.owner, args.repo, args.tag)
        if assets is None:
            raise Exception("Assets is None!")
        logger.info(f"Found {len(assets)} .gz assets")

        # 生成包信息字典
        theme_info = {}
        for i, asset in enumerate(assets):
            logger.info(f"Processing {i + 1}/{len(assets)}: {asset['name']}")
            try:
                pname = generate_package_name(asset["name"], asset.get("release_tag"))
                logger.info(f"Calculating SHA256 for {asset['url']}")

                sha256 = calculate_sha256(asset["url"])

                theme_info[pname] = {
                    "url": asset["url"],
                    "sha256": sha256,
                    "tag": args.tag,
                }

                logger.info(f"Created package: {pname}")
                logger.info(f"SHA256: {sha256}")
            except Exception as e:
                logger.error(
                    f"Error processing {asset['name']}: {str(e)}", exc_info=True
                )

        # 输出JSON
        print(json.dumps(theme_info, indent=2))
        logger.info("JSON generation completed successfully")

    except Exception as e:
        logger.error(f"Critical error: {str(e)}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
