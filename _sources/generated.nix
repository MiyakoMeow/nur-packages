# This file was generated by nvfetcher, please do not modify it manually.
{ fetchgit, fetchurl, fetchFromGitHub, dockerTools }:
{
  "13atm01-grub-theme-collection" = {
    pname = "13atm01-grub-theme-collection";
    version = "f4d764cab6bed5ab29e31965cca59420cc84ee0a";
    src = fetchgit {
      url = "https://github.com/13atm01/GRUB-Theme.git";
      rev = "f4d764cab6bed5ab29e31965cca59420cc84ee0a";
      fetchSubmodules = false;
      deepClone = false;
      leaveDotGit = false;
      sparseCheckout = [ ];
      sha256 = "sha256-yceSIVxVpUNUDFjMXGYGkD4qyMRajU7TyDg/gl2NmAs=";
    };
    date = "2025-06-15";
  };
  beatoraja = {
    pname = "beatoraja";
    version = "0.8.8";
    src = fetchurl {
      url = "https://www.mocha-repository.info/download/beatoraja0.8.8-modernchic.zip";
      sha256 = "sha256-CSaxWz4sRyMqdJlNmN3ae1N8OkzJk7VJqLvgrXIJ9+c=";
    };
  };
  lampghost = {
    pname = "lampghost";
    version = "v0.2.3";
    src = fetchFromGitHub {
      owner = "Catizard";
      repo = "lampghost";
      rev = "v0.2.3";
      fetchSubmodules = false;
      sha256 = "sha256-BgqFe4nc5YgRMwJh2unEgePmXFAmUd7yKXFlWhrRklc=";
    };
  };
  lampghost-bin = {
    pname = "lampghost-bin";
    version = "v0.2.3";
    src = fetchurl {
      url = "https://github.com/Catizard/lampghost/releases/download/v0.2.3/lampghost_linux";
      sha256 = "sha256-Bx3BvFphbFVjXkZCCkQjtw5mUkW5XaoePzvrJ8CO2U8=";
    };
  };
  portaudio-java = {
    pname = "portaudio-java";
    version = "2ec5cc47d6f8abe85ddb09c34e69342bfe72c60b";
    src = fetchgit {
      url = "https://github.com/philburk/portaudio-java.git";
      rev = "2ec5cc47d6f8abe85ddb09c34e69342bfe72c60b";
      fetchSubmodules = false;
      deepClone = false;
      leaveDotGit = false;
      sparseCheckout = [ ];
      sha256 = "sha256-t+Pqtgstd1uJjvD4GKomZHMeSECNLeQJOrz97o+lV2Q=";
    };
    date = "2023-07-04";
  };
  suisei-grub-theme = {
    pname = "suisei-grub-theme";
    version = "2ea338454810e6fd3ad04166bc84c576e29a6bea";
    src = fetchgit {
      url = "https://github.com/kirakiraAZK/suiGRUB.git";
      rev = "2ea338454810e6fd3ad04166bc84c576e29a6bea";
      fetchSubmodules = false;
      deepClone = false;
      leaveDotGit = false;
      sparseCheckout = [ ];
      sha256 = "sha256-besErd3N+iVGiReYGzo6H3JKsgQOyRaRbe6E0wKKW54=";
    };
    date = "2024-11-01";
  };
}
