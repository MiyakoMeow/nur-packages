{
  lib,
  stdenv,
  sources,
  makeWrapper,
  docker,
  bash,
  coreutils,
  ...
}:
stdenv.mkDerivation rec {
  inherit (sources.ros-dev-tools) pname src;

  # 动态版本格式：日期-短提交哈希 (兼容 nix-update)
  version = "${sources.ros-dev-tools.date}-${lib.strings.substring 0 7 src.rev}";

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [
    docker
    bash
    coreutils
  ];

  # 无实际构建步骤 (仅脚本工具)
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/${pname}
    cp -R . $out/share/${pname}

    # 修复Makefile中的/bin/bash引用
    substituteInPlace $out/share/${pname}/Makefile \
      --replace '/bin/bash' '${bash}/bin/bash'

    # 创建独立的启动脚本（解决参数传递问题）
    mkdir -p $out/bin
    cat > $out/bin/ros-dev-tools <<EOF
    #!${bash}/bin/bash
    set -euo pipefail
    cd "$out/share/${pname}"
    exec make "\$@"
    EOF
    chmod +x $out/bin/ros-dev-tools

    # 确保PATH中有docker和coreutils
    wrapProgram $out/bin/ros-dev-tools \
      --prefix PATH : ${
        lib.makeBinPath [
          docker
          coreutils
        ]
      }

    runHook postInstall
  '';

  meta = with lib; {
    description = "ROS development tools with Docker integration";
    homepage = "https://github.com/DSPEngineer/ros-dev-tools";
    license = licenses.unlicense; # 根据实际仓库许可证调整
    maintainers = [ ];
    platforms = platforms.all;
    # 标记为不稳定版本 (无正式 release)
    broken = false;
    hydraPlatforms = [ ];
  };
}
