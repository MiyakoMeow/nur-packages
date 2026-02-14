#!/usr/bin/env bash
# update-wechat-latest.sh
# 更新 wechat-latest 包到最新版本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_FILE="$SCRIPT_DIR/package.nix"

# 获取当前日期时间作为版本号
VERSION=$(date +%Y%m%d.%H%M%S)

# 获取最新的 .deb 包 URL
WECHAT_URL="https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb"

echo "正在获取 $WECHAT_URL 的 sha256..."

# 使用 nix-prefetch-url 获取 sha256
SHA256=$(nix-prefetch-url "$WECHAT_URL")

echo "最新版本: $VERSION"
echo "SHA256: $SHA256"

# 更新 package.nix 文件
tmpfile=$(mktemp)
trap "rm -f $tmpfile" EXIT

# 使用 sed 替换 version 和 sha256
sed -E \
  -e "s|(version = \")[0-9]+\.[0-9]+(\";)|\1$VERSION\2|" \
  -e "s|(sha256 = \")[^\"]+(\";)|\1$SHA256\2|" \
  "$PACKAGE_FILE" > "$tmpfile"

# 检查是否有变化
if diff -q "$PACKAGE_FILE" "$tmpfile" >/dev/null 2>&1; then
  echo "没有检测到新版本"
  rm -f "$tmpfile"
  exit 0
fi

# 替换原文件
mv "$tmpfile" "$PACKAGE_FILE"

echo "已更新 $PACKAGE_FILE:"
echo "  version: $VERSION"
echo "  sha256: $SHA256"
