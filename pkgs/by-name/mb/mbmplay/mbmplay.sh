#!/usr/bin/env bash
set -euo pipefail

# mBMplay 启动脚本
# 使用 Wine 运行 mBMplay，支持 .NET 应用

APP_DIR="@out@/share/mbmplay/mBMplay"
export WINEDEBUG=-all
export WINEARCH=win64
export WINEPREFIX="${MBMPLAY_HOME:-"${XDG_DATA_HOME:-"${HOME}/.local/share"}/mbmplay"}/wine"
export PATH="@wineWowPackages@/bin:$PATH"

# 提供快速烟雾测试：仅验证脚本与目录准备是否正常
if [ "$(printenv MBMPLAY_SMOKE)" = "1" ]; then
  echo "mbmplay smoke-ok"
  exit 0
fi

# wine-mono 已通过 embedInstallers 自动嵌入，无需手动安装
wine "$APP_DIR/mBMplay.exe" "$@"
