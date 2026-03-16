#!/usr/bin/env bash
# update-wechat-latest.sh
# 更新 wechat-latest 包到最新版本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_FILE="$SCRIPT_DIR/package.nix"

WECHAT_URL="https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb"

echo "正在获取 $WECHAT_URL 的 sha256..." >&2

NEW_SHA256=$(nix-prefetch-url "$WECHAT_URL")

OLD_SHA256=$(grep -oP 'sha256 = "\K[^"]+' "$PACKAGE_FILE" || echo "")

echo "当前 SHA256: $OLD_SHA256" >&2
echo "最新 SHA256: $NEW_SHA256" >&2

if [ "$NEW_SHA256" = "$OLD_SHA256" ]; then
  echo "SHA256 未变化，无需更新" >&2
  exit 0
fi

VERSION=$(date +%Y%m%d.%H%M%S)

echo "检测到新版本: $VERSION" >&2

ATTR_PATH="${UPDATE_NIX_ATTR_PATH:-we.wechat-latest}"
OLD_VERSION=$(grep -oP 'version = "\K[^"]+' "$PACKAGE_FILE" || echo "")

OUTPUT_JSON="[{\"attrPath\":\"$ATTR_PATH\",\"oldVersion\":\"$OLD_VERSION\",\"newVersion\":\"$VERSION\",\"newSha256\":\"$NEW_SHA256\",\"files\":[\"$PACKAGE_FILE\"]}]"
echo "$OUTPUT_JSON"
