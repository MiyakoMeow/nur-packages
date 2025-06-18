{
  stdenvNoCC,
  fetchFromGitHub,
  autoPatchelfHook,
  python3,
}: let
  # 仓库信息
  owner = "13atm01";
  repo = "GRUB-Theme";
  rev = "master"; # 替换为实际commit
  hash = "sha256-yceSIVxVpUNUDFjMXGYGkD4qyMRajU7TyDg/gl2NmAs="; # 替换为实际SHA256

  # 获取仓库源码
  src = fetchFromGitHub {
    inherit owner repo rev hash;
  };
in
  # 生成主题列表JSON
  stdenvNoCC.mkDerivation {
    name = "13atm01-grub-theme-list";
    inherit src;

    nativeBuildInputs = [python3 autoPatchelfHook];

    buildPhase = ''
      # 复制Python脚本
      cp ${./generate-theme-list.py} generate-theme-list.py
      chmod +x generate-theme-list.py

      # 运行脚本生成JSON
      python3 ./generate-theme-list.py "$src" theme-list.json
    '';

    installPhase = ''
      mkdir -p $out
      cp theme-list.json $out/
    '';
  }
