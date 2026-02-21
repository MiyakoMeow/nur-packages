{
  lib,
  stdenv,
  gtk3,
  webkitgtk_4_1,
  pkg-config,
  libsoup_3,
  glib-networking,
  gsettings-desktop-schemas,
  xorg,
  at-spi2-core,
  wails,
  buildGoModule,
  fetchFromGitHub,
  fetchNpmDeps,
  npmHooks,
  copyDesktopItems,
  makeDesktopItem,
  autoPatchelfHook,
  wrapGAppsHook3,
  nix-update-script,
}:

buildGoModule (finalAttrs: {
  pname = "lampghost-dev";
  version = "0.3.1-unstable-2025-11-06";

  src = fetchFromGitHub {
    owner = "Catizard";
    repo = "lampghost";
    rev = "7ee51b8730121f4372a4de2bb309b25d1ab15480";
    hash = "sha256-X7wPehdcpL2bwXoH7Q9mD5frLJbyMgdz2bJZvV+V4tw=";
  };

  vendorHash = "sha256-b2nWUsZjdNR2lmY9PPEhba/NsOn1K4nLDZhv71zxAK8=";

  env = {
    CGO_ENABLED = 1;
    npmDeps = fetchNpmDeps {
      src = "${finalAttrs.src}/frontend";
      hash = "sha256-YYF6RfA3uE65QdwuJMV+NSvGYtmZRxwrVbQtijNyHRE=";
    };
    npmRoot = "frontend";
  };

  nativeBuildInputs = [
    wails
    pkg-config
    copyDesktopItems
    npmHooks.npmConfigHook
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    gsettings-desktop-schemas
    autoPatchelfHook
    wrapGAppsHook3
  ];

  buildInputs =
    [ ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      webkitgtk_4_1
      gtk3
      libsoup_3
      glib-networking
      xorg.libX11
      xorg.libXcursor
      xorg.libXrandr
      xorg.libXinerama
      xorg.libXi
      xorg.libXxf86vm
      xorg.libXfixes
      xorg.libXext
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXrender
      xorg.xvfb
      xorg.xorgserver
      at-spi2-core
    ];

  buildPhase = ''
    runHook preBuild

    wails build -m -trimpath -devtools ${lib.optionalString stdenv.hostPlatform.isLinux "-tags webkit2_41"} -o lampghost-dev

    runHook postBuild
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "lampghost-dev";
      exec = "lampghost-dev";
      desktopName = "LampGhost (Dev Version)";
      comment = "Offline & Cross-platform beatoraja lamp viewer and more";
      categories = [ "Game" ];
      startupNotify = true;
      keywords = [ "beatoraja" ];
    })
  ];

  installPhase = ''
    runHook preInstall

    install -Dm0755 build/bin/lampghost-dev $out/bin/lampghost-dev

    runHook postInstall
  '';

  passthru = {
    updateScript = nix-update-script {
      extraArgs = [
        "--version=branch"
      ];
    };
  };

  meta = {
    description = "Offline & Cross-platform beatoraja lamp viewer and more";
    homepage = "https://github.com/Catizard/lampghost";
    changelog = "https://github.com/Catizard/lampghost/commits/main";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "lampghost-dev";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
