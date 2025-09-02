{
  lib,
  buildGoModule,
  fetchFromGitHub,
  fetchNpmDeps,
  npmHooks,
  nodejs,
  wails,
  webkitgtk_4_1,
  pkg-config,
  copyDesktopItems,
  makeDesktopItem,
  autoPatchelfHook,
  nix-update-script,
  ...
}:

buildGoModule (finalAttrs: rec {
  pname = "lampghost-dev";
  version = "0.3.0-unstable-2025-08-23";

  src = fetchFromGitHub {
    owner = "Catizard";
    repo = "lampghost";
    rev = "d667126547fdfc13976c45f1b14b42410288a6c6";
    hash = "sha256-d03dfloGB3fMZun59n5uYfNZuHEhobJEpTyfTRG9PoY=";
  };

  vendorHash = "sha256-5wPllsqYm26gl49fynuRnCKNCASHQtKK07p0zf+SBhA=";

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
    autoPatchelfHook
    nodejs
    npmHooks.npmConfigHook
    copyDesktopItems
  ];

  buildInputs = [ webkitgtk_4_1 ];

  buildPhase = ''
    runHook preBuild

    export HOME=$(mktemp -d)
    wails build -m -trimpath -devtools -tags webkit2_41 -o ${pname}

    runHook postBuild
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "${pname}";
      exec = "${pname}";
      desktopName = "LampGhost (Dev Version)";
      comment = "Offline & Cross-platform beatoraja lamp viewer and more";
      categories = [ "Game" ];
      startupNotify = true;
      keywords = [ "beatoraja" ];
    })
  ];

  installPhase = ''
    runHook preInstall

    install -Dm0755 build/bin/${pname} $out/bin/${pname}

    runHook postInstall
  '';

  passthru = {
    updateScript = nix-update-script {
      attrPath = "${pname}";
      extraArgs = [
        "--flake"
        "--subpackage"
        "frontend"
        "--version=branch"
      ];
    };
  };

  meta = {
    description = "Offline & Cross-platform beatoraja lamp viewer and more";
    homepage = "https://github.com/Catizard/lampghost";
    changelog = "https://github.com/Catizard/lampghost/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "${pname}";
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.linux;
  };
})
