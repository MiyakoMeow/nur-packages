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
      hash = "sha256-0g5fISqjOnKbAkCBCb3YuQTstV4ZQGC2+9vYjBYRbmc=";
    };

    installPhase = ''
      cp -r $src/* $out
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
