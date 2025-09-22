{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  protobuf,
  ninja,
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

  # Provide sources for third_party dependencies to avoid CMake cloning
  rstdSrc = fetchFromGitHub {
    owner = "hypengw";
    repo = "rstd";
    rev = "dacb8a9e7492c2b6231957c05b8f6fa4152d49cd";
    hash = "sha256-O68HHAu/OYHMFVhMWGSM/MW4ZtruF1W9/luD8aCwaGs=";
  };
  asioSrc = fetchFromGitHub {
    owner = "chriskohlhoff";
    repo = "asio";
    # tag asio-1-34-0 resolves to this commit
    rev = "a892f73dc96bfaf92db98a3fe219f920fad007ea";
    hash = "sha256-7sFUcWuYn2LrTY7n3sy7Il2slNLlgIRSW+ZCzLE4qQM=";
  };
  pegtlSrc = fetchFromGitHub {
    owner = "taocpp";
    repo = "PEGTL";
    rev = "be527327653e94b02e711f7eff59285ad13e1db0"; # 3.2.8
    hash = "sha256-nPWSO2wPl/qenUQgvQDQu7Oy1dKa/PnNFSclmkaoM8A=";
  };
  ncrequestSrc = fetchFromGitHub {
    owner = "hypengw";
    repo = "ncrequest";
    rev = "b919f0ad9a85dc006392ebf8802eb4c7df7584a2";
    hash = "sha256-0XHrsistrS9IWl5u95D7PPA4LTEMENwo79EdWWvkLa8=";
  };
  kstoreSrc = fetchFromGitHub {
    owner = "hypengw";
    repo = "kstore";
    rev = "45a162c28902af44fe45bdb0a7fadbceb1f81daf"; # master at prefetch time
    hash = "sha256-jL/CMB9xyYRIg1Z2bH8YMUuLaetmbdmWSDYblWlQDuU=";
  };
  qmlMaterialSrc = fetchFromGitHub {
    owner = "hypengw";
    repo = "QmlMaterial";
    rev = "7474aad99c5021f819eb54e6979110a4e487f8aa"; # main at prefetch time
    hash = "sha256-Llic+oJjZMLLzLxcMtyUhIMi6cS8kNTdiKAc+PBp2/k=";
  };
  randomSrc = fetchFromGitHub {
    owner = "ilqvya";
    repo = "random";
    rev = "6983466aadd1173627b362ff1a297527d9842531";
    hash = "sha256-Kj71K2TGiEjaxx1VP1MWbj/0PZYpMeNZXyrY5/nJxSw=";
  };
  kdSingleAppSrc = fetchFromGitHub {
    owner = "KDAB";
    repo = "KDSingleApplication";
    rev = "631237acd4e20251c7f702db5e5434c83f0e336d";
    hash = "sha256-DBRzffutMoJcB25Ryqu2DMAlCb/JOOLKyazePG6D3S8=";
  };
  cubebSrc = fetchFromGitHub {
    owner = "mozilla";
    repo = "cubeb";
    rev = "78b2bce70e0d1c21d3c175b72f322c50801b2e94";
    hash = "sha256-7Euj2hGpaNZaTUzFbRjPHYvdjgQoBbuTK7/7iAgGaYk=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    protobuf
    ninja
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtgrpc
    qt6.qtsvg
    qt6.qtwayland
    curl
    ffmpeg
    cubeb
  ]
  ++ (cubeb.passthru.backendLibs or []);

  postPatch = ''
    # 禁用上游生成 .qmlls.ini，避免尝试向只读的 Nix store 写文件
    substituteInPlace CMakeLists.txt \
      --replace "set(QT_QML_GENERATE_QMLLS_INI ON)" "set(QT_QML_GENERATE_QMLLS_INI OFF)"
    # 取消上游强制使用 clang++，改用 Nix 默认编译器
    substituteInPlace CMakeLists.txt \
      --replace "set(CMAKE_CXX_COMPILER clang++ CACHE STRING \"default clang++\")" "# disabled by Nix build"

    # 将 kstore 作为本地 third_party 源，并修补重复的 rebind_alloc 定义
    mkdir -p third_party/kstore
    cp -r ${finalAttrs.kstoreSrc}/* third_party/kstore/
    chmod -R u+w third_party/kstore || true
    if [ -f third_party/kstore/include/kstore/qt/meta_list_model.hpp ]; then
      substituteInPlace third_party/kstore/include/kstore/qt/meta_list_model.hpp \
        --replace "using rebind_alloc = typename std::allocator_traits<Allocator>::template rebind_alloc<T>;" "// duplicate rebind_alloc removed by Nix"
    fi
  '';

  # Provide needed headers for third-party builds that don't use pkg-config
  NIX_CFLAGS_COMPILE = [
    "-isystem" "${curl.dev}/include"
    "-isystem" "${qt6.qtbase.dev}/include"
    "-isystem" "${qt6.qtbase.dev}/include/qt6"
    "-DASIO_HAS_THREADS"
    "-DASIO_NO_DEPRECATED"
    "-DASIO_NO_TYPEID"
    "-DASIO_HAS_STD_EXECUTION=0"
    "-DASIO_DISABLE_CONCEPTS"
  ];

  cmakeFlags = [
    "-G" "Ninja"
    "-DQCM_BUILD_TESTS=OFF"
    "-DQT_QML_GENERATE_QMLLS_INI=OFF"
    "-DCMAKE_CXX_STANDARD=23"
    # Disallow network and point FetchContent to pre-fetched sources
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    # Names correspond to FetchContent_Declare() names in third_party/CMakeLists.txt
    "-DFETCHCONTENT_SOURCE_DIR_RSTD=${finalAttrs.rstdSrc}"
    "-DFETCHCONTENT_SOURCE_DIR_ASIO=${finalAttrs.asioSrc}"
    "-DFETCHCONTENT_SOURCE_DIR_PEGTL=${finalAttrs.pegtlSrc}"
    "-DFETCHCONTENT_SOURCE_DIR_NCREQUEST=${finalAttrs.ncrequestSrc}"
    # kstore 由第三方 CMakeLists 通过本地目录添加，这里不覆盖其源目录
    "-DFETCHCONTENT_SOURCE_DIR_QML_MATERIAL=${finalAttrs.qmlMaterialSrc}"
    "-DFETCHCONTENT_SOURCE_DIR_RANDOM=${finalAttrs.randomSrc}"
    "-DFETCHCONTENT_SOURCE_DIR_KDSINGLEAPPLICATION=${finalAttrs.kdSingleAppSrc}"
    "-DFETCHCONTENT_SOURCE_DIR_CUBEB=${finalAttrs.cubebSrc}"
  ];

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
