{
  lib,
  stdenv,
  nodejs,
  fetchNpmDeps,
  fetchFromGitHub,
  npmHooks,
  buildGoModule,
  autoPatchelfHook,
  makeDesktopItem,
  copyDesktopItems,
  nix-update-script,
  wails,
  webkitgtk_4_1,
  pkg-config,
  libsoup_3,
  tree,
  jq,
  glib, # 添加 glib 用于编译模式
  gsettings-desktop-schemas, # 添加 GSettings 模式
  wrapGAppsHook, # 添加包装钩子
  ...
}:
let
  pname = "lampghost";
  version = "0.3.0";
  src = fetchFromGitHub {
    owner = "Catizard";
    repo = "lampghost";
    rev = "v${version}";
    sha256 = "sha256-PM6+QG9pBBDqaK60i4IXZ56UgXJ+DoOZqKJ/+HjdMjo=";
  };

  # 元信息
  metaCommon = with lib; {
    description = "Offline & Cross-platform beatoraja lamp viewer and more";
    homepage = "https://github.com/Catizard/lampghost";
    changelog = "https://github.com/Catizard/lampghost/releases/tag/v${version}";
    license = licenses.asl20;
    maintainers = [ ];
    platforms = platforms.linux;
  };

  # 预先下载 npm 依赖
  frontend = stdenv.mkDerivation (finalAttrs: {
    inherit version src;
    pname = "${pname}-frontend";

    nativeBuildInputs = [
      nodejs
      npmHooks.npmConfigHook
    ];

    sourceRoot = "${finalAttrs.src.name}/frontend";

    # 关键配置：完全离线构建
    npmDeps = fetchNpmDeps {
      src = "${src.outPath}/frontend";
      hash = "sha256-YYF6RfA3uE65QdwuJMV+NSvGYtmZRxwrVbQtijNyHRE="; # 首次构建后替换
    };

    # 配置离线环境
    npmFlags = "--offline --no-audit --no-fund --ignore-scripts";
    npmRoot = "."; # 相对sourceRoot

    buildPhase = ''
      runHook preBuild

      # 设置环境变量
      export HOME=$(mktemp -d)
      export PATH="${nodejs}/bin:$PATH"

      echo "=== 离线安装依赖 ==="
      npm install $npmFlags

      echo "=== 构建前端资源 ==="
      npm run build  # 生成 dist 目录

      # 确认资源已生成 (调试用)
      if [ ! -f "dist/index.html" ]; then
        echo "错误：前端构建失败，未生成 dist/index.html"
        exit 1
      fi

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      cp -r dist $out

      runHook postInstall
    '';

    meta = metaCommon;
  });
in
buildGoModule {
  inherit pname version src;

  vendorHash = "sha256-EefHPirHEaKCTt+BPyr9Ac+bETI/omCuQNX5bP7y9Ec=";

  nativeBuildInputs = [
    wails
    pkg-config
    autoPatchelfHook
    copyDesktopItems
    tree
    jq
    glib # 添加 glib 用于编译模式
    wrapGAppsHook # 添加 GTK 应用包装钩子
    webkitgtk_4_1 # 添加到 nativeBuildInputs 以确保 pkg-config 能找到 .pc 文件
  ];

  buildInputs = [
    webkitgtk_4_1
    libsoup_3
    gsettings-desktop-schemas # 添加 GSettings 模式
  ];

  preBuild = ''
    # 设置隔离的 HOME 目录，避免污染系统 HOME
    export HOME=$(mktemp -d)

    # 创建目标目录并直接复制资源内容
    mkdir -p frontend/dist
    cp -r ${frontend}/* frontend/dist

    # 调试：验证资源文件存在
    echo "=== 前端资源验证 ==="
    ls -l frontend/dist
    [ -f "frontend/dist/index.html" ] || { echo "错误：index.html缺失"; exit 1; }

    # 创建 WebKitGTK 版本兼容性符号链接
    # Wails 内部查找 webkit2gtk-4.0，但我们使用 webkitgtk_4_1
    echo "=== 创建 WebKitGTK 兼容性符号链接 ==="

    # 调试：显示 webkitgtk_4_1 包的实际路径
    echo "=== 调试信息：WebKitGTK 包路径 ==="
    echo "webkitgtk_4_1 路径: ${webkitgtk_4_1}"
    echo "webkitgtk_4_1.dev 路径: ${webkitgtk_4_1.dev}"

    # 如果是符号链接，显示实际目标
    if [ -L "${webkitgtk_4_1.dev}" ]; then
      echo "webkitgtk_4_1.dev 是符号链接，指向: $(readlink -f "${webkitgtk_4_1.dev}")"
    fi

    # 显示 pkgconfig 目录的内容
    if [ -d "${webkitgtk_4_1.dev}/lib/pkgconfig" ]; then
      echo "pkgconfig 目录内容:"
      ls -la "${webkitgtk_4_1.dev}/lib/pkgconfig/" | head -10
    else
      echo "警告: ${webkitgtk_4_1.dev}/lib/pkgconfig 目录不存在"
    fi

    mkdir -p $HOME/.pkgconfig
    export PKG_CONFIG_PATH="$HOME/.pkgconfig:$PKG_CONFIG_PATH"

    # 动态查找 webkitgtk_4_1 的 pc 文件
    echo "=== 查找 WebKitGTK pc 文件 ==="

    # 首先设置正确的环境变量
    export PKG_CONFIG_PATH="${webkitgtk_4_1.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"
    echo "设置 PKG_CONFIG_PATH: $PKG_CONFIG_PATH"

    WEBKIT_PC_FILE=""

    # 方法1: 直接查找正确的文件名（基于实际 nix store 路径）
    # webkitgtk_4_1 对应的文件名应该是 webkitgtk-4.1.pc 或 webkit2gtk-4.1.pc
    CORRECT_PC_FILE="${webkitgtk_4_1.dev}/lib/pkgconfig/webkitgtk-4.1.pc"
    if [ ! -f "$CORRECT_PC_FILE" ]; then
      CORRECT_PC_FILE="${webkitgtk_4_1.dev}/lib/pkgconfig/webkit2gtk-4.1.pc"
    fi
    if [ -f "$CORRECT_PC_FILE" ]; then
      WEBKIT_PC_FILE="$CORRECT_PC_FILE"
      echo "在正确位置找到: $WEBKIT_PC_FILE"
    else
      echo "正确位置未找到 pc 文件: $CORRECT_PC_FILE"
    fi

    # 方法2: 在 webkitgtk_4_1.dev 目录中查找所有 webkitgtk*.pc 文件
    if [ -z "$WEBKIT_PC_FILE" ]; then
      echo "在 webkitgtk_4_1.dev 目录中搜索 webkitgtk*.pc..."
      WEBKIT_PC_FILES=$(find "${webkitgtk_4_1.dev}" -name "webkitgtk*.pc" 2>/dev/null)
      if [ -n "$WEBKIT_PC_FILES" ]; then
        echo "找到的 webkitgtk pc 文件:"
        echo "$WEBKIT_PC_FILES"
        # 优先选择版本号最大的文件
        WEBKIT_PC_FILE=$(echo "$WEBKIT_PC_FILES" | sort -V | tail -1)
        echo "选择文件: $WEBKIT_PC_FILE"
      else
        echo "webkitgtk_4_1.dev 目录中未找到 webkitgtk pc 文件"
      fi
    fi

    # 方法3: 查找 webkit2gtk*.pc 文件（兼容旧版）
    if [ -z "$WEBKIT_PC_FILE" ]; then
      echo "查找 webkit2gtk*.pc 文件（兼容模式）..."
      WEBKIT_PC_FILES=$(find "${webkitgtk_4_1.dev}" -name "webkit2gtk*.pc" 2>/dev/null)
      if [ -n "$WEBKIT_PC_FILES" ]; then
        echo "找到的 webkit2gtk pc 文件:"
        echo "$WEBKIT_PC_FILES"
        WEBKIT_PC_FILE=$(echo "$WEBKIT_PC_FILES" | sort -V | tail -1)
        echo "选择文件: $WEBKIT_PC_FILE"
      fi
    fi

    # 方法4: 在完整 webkitgtk_4_1 包中查找所有可能的 pc 文件
    if [ -z "$WEBKIT_PC_FILE" ]; then
      echo "在完整 webkitgtk_4_1 包中搜索所有 webkit*.pc 文件..."
      WEBKIT_PC_FILES=$(find "${webkitgtk_4_1}" -name "webkit*.pc" 2>/dev/null)
      if [ -n "$WEBKIT_PC_FILES" ]; then
        echo "在完整包中找到的 pc 文件:"
        echo "$WEBKIT_PC_FILES"
        WEBKIT_PC_FILE=$(echo "$WEBKIT_PC_FILES" | sort -V | tail -1)
        echo "选择文件: $WEBKIT_PC_FILE"
      else
        echo "webkitgtk_4_1 包中未找到任何 webkit pc 文件"
      fi
    fi

    # 方法5: 使用 pkg-config 查找（支持多种包名）
    if [ -z "$WEBKIT_PC_FILE" ]; then
      echo "最后尝试使用 pkg-config 查找..."
      if command -v pkg-config >/dev/null 2>&1; then
        # 尝试多种可能的包名，按优先级排序
        for PKG_NAME in "webkitgtk-4.1" "webkit2gtk-4.1" "webkitgtk-6.0" "webkit2gtk-6.0" "webkitgtk" "webkit2gtk"; do
          if pkg-config --exists "$PKG_NAME" 2>/dev/null; then
            WEBKIT_PC_PATH=$(pkg-config --variable=pcfiledir "$PKG_NAME" 2>/dev/null)
            if [ -n "$WEBKIT_PC_PATH" ]; then
              # 尝试多种可能的文件名，按优先级排序
              for PC_FILE in "webkitgtk-4.1.pc" "webkit2gtk-4.1.pc" "webkitgtk-6.0.pc" "webkit2gtk-6.0.pc" "webkitgtk.pc" "webkit2gtk.pc"; do
                CANDIDATE_FILE="$WEBKIT_PC_PATH/$PC_FILE"
                if [ -f "$CANDIDATE_FILE" ]; then
                  WEBKIT_PC_FILE="$CANDIDATE_FILE"
                  echo "pkg-config 找到 ($PKG_NAME): $WEBKIT_PC_FILE"
                  break 2
                fi
              done
            fi
          fi
        done
        if [ -z "$WEBKIT_PC_FILE" ]; then
          echo "pkg-config 无法找到任何兼容的 webkit 包"
        fi
      else
        echo "系统中未安装 pkg-config"
      fi
    fi

    # 创建符号链接
    if [ -n "$WEBKIT_PC_FILE" ] && [ -f "$WEBKIT_PC_FILE" ]; then
      ln -sf "$WEBKIT_PC_FILE" "$HOME/.pkgconfig/webkit2gtk-4.0.pc"
      echo "已创建符号链接: webkit2gtk-4.0.pc -> $(basename "$WEBKIT_PC_FILE")"
    else
      echo "警告: 未找到 webkit2gtk pc 文件，将继续构建..."
    fi

    # 验证符号链接
    echo "=== 验证符号链接 ==="
    ls -la "$HOME/.pkgconfig/" || true

    # 检查符号链接是否正确指向
    if [ -L "$HOME/.pkgconfig/webkit2gtk-4.0.pc" ]; then
      echo "符号链接目标: $(readlink -f "$HOME/.pkgconfig/webkit2gtk-4.0.pc")"
      echo "目标文件是否存在: $([ -f "$(readlink -f "$HOME/.pkgconfig/webkit2gtk-4.0.pc")" ] && echo "是" || echo "否")"
    fi

    # 显示当前 PKG_CONFIG_PATH
    echo "当前 PKG_CONFIG_PATH: $PKG_CONFIG_PATH"

    # 测试 pkg-config 是否能找到我们的符号链接
    echo "测试 pkg-config 查找 webkit2gtk-4.0:"
    if command -v pkg-config >/dev/null 2>&1; then
      pkg-config --exists webkit2gtk-4.0 && echo "pkg-config 成功找到 webkit2gtk-4.0" || echo "pkg-config 无法找到 webkit2gtk-4.0"
    else
      echo "系统中未安装 pkg-config"
    fi
  '';

  buildPhase = ''
    runHook preBuild

    # ===== 构建 =====
    # 注意：HOME 和 PKG_CONFIG_PATH 已在 preBuild 中设置（隔离目录）
    # 使用 webkit2_41 标签来指定 WebKitGTK 4.1 版本

    # 确保 Wails 构建时能找到我们的符号链接
    export PKG_CONFIG_PATH="$HOME/.pkgconfig:$PKG_CONFIG_PATH"
    echo "构建时的 PKG_CONFIG_PATH: $PKG_CONFIG_PATH"

    # 使用正确的 Wails 构建标签来指定 WebKitGTK 4.1
    wails build -m -s -trimpath -skipbindings -devtools -tags webkit2_41 -o $pname

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # 安装主程序
    install -Dm755 build/bin/$pname -t $out/bin
    chmod +x $out/bin/$pname
    cp -r frontend $out/bin

    # 安装GSettings模式（移动到安装阶段）
    echo "=== 安装GSettings模式 ==="
    mkdir -p $out/share/gsettings-schemas/${pname}-${version}
    cp -r ${gsettings-desktop-schemas}/share/gsettings-schemas/* $out/share/gsettings-schemas/${pname}-${version}/
    glib-compile-schemas $out/share/gsettings-schemas/${pname}-${version}

    # 安装桌面文件
    copyDesktopItems

    runHook postInstall
  '';

  # 桌面条目配置
  desktopItems = [
    (makeDesktopItem {
      name = pname;
      desktopName = "LampGhost";
      comment = "Offline & Cross-platform beatoraja lamp viewer and more";
      exec = pname;
      categories = [ "Game" ];
      startupNotify = true;
      keywords = [ "beatoraja" ];
    })
  ];

  # See https://github.com/Mic92/nix-update?tab=readme-ov-file#subpackages
  inherit frontend;
  passthru = {
    updateScript = nix-update-script {
      attrPath = pname;
      extraArgs = [
        "--flake"
        "--subpackage"
        "frontend"
      ];
    };
  };

  meta = metaCommon // {
    mainProgram = pname;
  };
}
