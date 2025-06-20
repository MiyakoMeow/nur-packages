{
  lib,
  stdenvNoCC,
  sources,
  nix-update-script,
}: let
  version = "dev";
in
  stdenvNoCC.mkDerivation {
    inherit version;
    inherit (sources.suisei-grub-theme) pname src;

    installPhase = ''
      mkdir $out
      cp -r $src/* $out

      # 验证主题文件
      if [ ! -e "$out/theme.txt" ]; then
        echo "ERROR: theme.txt not found in output directory"
        exit 1
      fi
    '';

    # 禁用自动解压步骤
    dontUnpack = true;
    dontBuild = true;

    passthru = {
      updateScript =
        nix-update-script {
        };
    };

    meta = with lib; {
      description = "suiGRUB";
      homepage = "https://github.com/kirakiraAZK/suiGRUB";
      license = licenses.unlicense;
    };
  }
