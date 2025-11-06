{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "lr2oraja-endlessdream";
  version = "0.3.0";

  src = fetchurl {
    url = "https://github.com/seraxis/lr2oraja-endlessdream/releases/download/v${finalAttrs.version}/lr2oraja-0.8.8-endlessdream-linux-${finalAttrs.version}.jar";
    hash = "sha256-x3cZ5b5fZQdVKX6Df44m35mGYtBmM0FTxj4hm8A6hR0=";
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    cp $src $out/${finalAttrs.pname}.jar

    runHook postInstall
  '';

  meta = with lib; {
    description = "lr2oraja-endlessdream - A BMS player based on beatoraja";
    homepage = "https://github.com/seraxis/lr2oraja-endlessdream";
    license = licenses.gpl3;
    maintainers = [ ];
    platforms = platforms.linux;
  };
})
