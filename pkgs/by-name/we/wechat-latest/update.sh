#!/usr/bin/env bash
# update-wechat-latest.sh
# 更新 wechat-latest 包到最新版本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_FILE="$SCRIPT_DIR/package.nix"

WECHAT_URL="https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb"

echo "正在获取 $WECHAT_URL 的 sha256..."

NEW_SHA256=$(nix-prefetch-url "$WECHAT_URL")

OLD_SHA256=$(grep -oP 'sha256 = "\K[^"]+' "$PACKAGE_FILE" || echo "")

echo "当前 SHA256: $OLD_SHA256"
echo "最新 SHA256: $NEW_SHA256"

if [ "$NEW_SHA256" = "$OLD_SHA256" ]; then
  echo "SHA256 未变化，无需更新"
  exit 0
fi

VERSION=$(date +%Y%m%d.%H%M%S)

echo "检测到新版本: $VERSION"

tmpfile=$(mktemp)
trap "rm -f $tmpfile" EXIT

sed -E \
  -e "s|(version = \")[0-9]+\.[0-9]+(\";)|\1$VERSION\2|" \
  -e "s|(sha256 = \")[^\"]+(\";)|\1$NEW_SHA256\2|" \
  "$PACKAGE_FILE" > "$tmpfile"

mv "$tmpfile" "$PACKAGE_FILE"

echo "已更新 $PACKAGE_FILE:"
echo "  version: $VERSION"
echo "  sha256: $NEW_SHA256"
