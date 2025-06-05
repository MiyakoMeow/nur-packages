{
  lib,
  pkgs,
  fetchFromGitHub,
  nix-update-script,
}: let
  version = "dev";
in
  pkgs.stdenv.mkDerivation {
    name = "grub-theme-suisei";
    inherit version;

    src = fetchFromGitHub {
      owner = "kirakiraAZK";
      repo = "suiGRUB";
      rev = "main";
      hash = "sha256-besErd3N+iVGiReYGzo6H3JKsgQOyRaRbe6E0wKKW54=";
    };

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
