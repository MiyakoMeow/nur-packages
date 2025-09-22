{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  qt6,
  curl,
  ffmpeg,
  cubeb,
  nix-update-script,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "qcm";
  version = "1.2.0_qsql-unstable-2025-09-11";

  src = fetchFromGitHub {
    owner = "hypengw";
    repo = "Qcm";
    rev = "ca4e04da3ed7755c62433279ab1f05d2b8b064f6";
    fetchSubmodules = true;
    hash = "sha256-ouKJ8yumhzdgd/haOE0a7QcvFXHs7kecSNl1H3+U/pM=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtsvg
    qt6.qtwayland
    curl
    ffmpeg
    cubeb
  ]
  ++ (cubeb.passthru.backendLibs or []);

  # Correct qml import path
  postInstall = ''
    mv $out/lib/qt6 $out/lib/qt-6
  '';

  qtWrapperArgs = [
    "--prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath (cubeb.passthru.backendLibs or [])}"
  ];

  passthru = {
    updateScript = nix-update-script {
      extraArgs = [
        "--version=branch"
      ];
    };
  };

  meta = {
    description = "Unofficial Qt client for netease cloud music";
    homepage = "https://github.com/hypengw/Qcm";
    license = lib.licenses.gpl2Plus;
    mainProgram = "Qcm";
    maintainers = with lib.maintainers; [ aleksana ];
    platforms = lib.platforms.linux;
  };
})
