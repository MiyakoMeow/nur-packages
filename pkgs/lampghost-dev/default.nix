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
  webkitgtk_4_0,
  pkg-config,
  libsoup_2_4,
  tree,
  jq,
  glib, # 添加 glib 用于编译模式
  gsettings-desktop-schemas, # 添加 GSettings 模式
  wrapGAppsHook, # 添加包装钩子
  ...
}: let
  pname = "lampghost-dev";
  version = "0.2.4.1";
  src = fetchFromGitHub {
    owner = "Catizard";
    repo = "lampghost";
    rev = "46d839a3bcd9f80682cd4df71359e804a709efa7";
    sha256 = "sha256-v5LNtzRSFj2Kxbj9qAnegRSusgSB9NZH6lXnON83PpI=";
  };

  # 元信息
  metaCommon = with lib; {
    description = "Offline & Cross-platform beatoraja lamp viewer and more";
    homepage = "https://github.com/Catizard/lampghost";
    changelog = "https://github.com/Catizard/lampghost/releases/tag/v${version}";
    license = licenses.asl20;
    maintainers = [];
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
      hash = "sha256-euYZfQ2MpiwACECzRdwx7RVp4cGdpa4wpcd/phkARIU="; # 首次构建后替换
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

    vendorHash = "sha256-ViR7FfEPjQEMfcHcAVg3Ru3VwbbrE+X22nWG/x2OKlQ=";

    nativeBuildInputs = [
      wails
      pkg-config
      autoPatchelfHook
      copyDesktopItems
      tree
      jq
      glib # 添加 glib 用于编译模式
      wrapGAppsHook # 添加 GTK 应用包装钩子
    ];

    buildInputs = [
      webkitgtk_4_0
      libsoup_2_4
      gsettings-desktop-schemas # 添加 GSettings 模式
    ];

    preBuild = ''
      # 创建目标目录并直接复制资源内容
      mkdir -p frontend/dist
      cp -r ${frontend}/* frontend/dist

      # 调试：验证资源文件存在
      echo "=== 前端资源验证 ==="
      ls -l frontend/dist
      [ -f "frontend/dist/index.html" ] || { echo "错误：index.html缺失"; exit 1; }
    '';

    buildPhase = ''
      runHook preBuild

      # ===== 构建 =====
      export HOME=$(mktemp -d)
      wails build -m -s -trimpath -skipbindings -devtools -tags webkit2_40 -o $pname

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
        desktopName = "LampGhost (Dev Version)";
        comment = "Offline & Cross-platform beatoraja lamp viewer and more";
        exec = pname;
        categories = ["Game"];
        startupNotify = true;
        keywords = ["beatoraja"];
      })
    ];

    passthru = {
      inherit frontend;
      updateScript = nix-update-script {
        extraArgs = [
          "--subpackage"
          "frontend"
          "--version"
          "branch"
        ];
      };
    };

    meta =
      metaCommon
      // {
        mainProgram = pname;
      };
  }
