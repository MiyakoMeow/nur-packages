{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  addToPath ? true, # 是否注册命令行可执行文件
}: let
  # 版本标识符（从URL中提取）
  pkgId = "64ac0526-0589-4ec9-9142-06db38ef3da2";
  version = "V2-64"; # 根据文件名自定义版本号

  # 下载URL
  srcUrl = "http://222.246.130.17:37209/DownloadXml/ClientPkgs/${pkgId}/HN-linux-client${version}.tar.gz";

  # 预计算SHA256哈希（需要替换为实际值）
  sha256 = "0nfalc60n5ksvyd59xrzcya5xim9aa979zyq3p25gxdzyn2ccn4w";
in
  stdenv.mkDerivation {
    pname = "hn-linux-client";
    inherit version;

    src = fetchurl {
      url = srcUrl;
      inherit sha256;
    };

    # 自动修补二进制文件
    nativeBuildInputs =
      [
        autoPatchelfHook
      ]
      ++ lib.optionals addToPath [
        makeWrapper
      ];

    # 添加运行时依赖
    buildInputs = [
    ];

    # 无需配置和构建步骤
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      # 创建输出目录
      mkdir -p $out

      # 解压客户端到输出目录
      tar xf $src -C $out --strip-components=1

      # 注册命令行工具 (可选)
      ${lib.optionalString addToPath ''
        # 确保bin目录存在
        if [ -d "$out/bin" ]; then
          mkdir -p $out/nix-support/bin

          # 为所有可执行文件创建包装器
          for binfile in $out/bin/*; do
            if [ -f "$binfile" ] && [ -x "$binfile" ]; then
              # 创建包装脚本
              makeWrapper "$binfile" "$out/nix-support/bin/$(basename $binfile)"
            fi
          done

          # 将bin目录添加到PATH
          echo "export PATH=$out/nix-support/bin:\$PATH" >> $out/nix-support/setup-hook
        fi
      ''}
    '';

    # 设置环境钩子
    setupHook = ./setup-hook.sh;

    meta = with lib; {
      description = "HN Linux Client, for net interface of China Telecom in HUNAN University";
      homepage = "http://222.246.130.17:37209/";
      license = licenses.unfree; # 根据实际许可证调整
      platforms = ["x86_64-linux"]; # 仅支持64位Linux
      maintainers = [];
    };
  }
