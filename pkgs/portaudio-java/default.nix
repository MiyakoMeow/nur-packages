{
  stdenv,
  portaudio,
  jdk,
  cmake,
  gradle,
  lib,
}:
stdenv.mkDerivation {
  pname = "portaudio-java";
  version = "dev";

  src = builtins.fetchGit {
    url = "https://github.com/philburk/portaudio-java.git";
    rev = "2ec5cc47d6f8abe85ddb09c34e69342bfe72c60b";
    ref = "main";
  };

  nativeBuildInputs = [cmake gradle jdk];
  buildInputs = [portaudio];

  # 设置必要的环境变量
  JAVA_HOME = jdk.home;
  GRADLE_HOME = gradle;

  # 修复CMake安装路径问题
  cmakeFlags = [
    "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
    # 修复gradlew找不到库问题
    "-DCMAKE_INSTALL_LIBDIR=lib"
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  configurePhase = ''
    cmake . $cmakeFlags
  '';

  buildPhase = ''
    # 仅构建不安装
    make

    # 关键修改3：手动定位并准备库文件
    JNI_LIB_DIR=$(find . -type d -path "*/jni" | head -1)
    mkdir -p native-libs
    find $JNI_LIB_DIR -name '*.so' -exec cp {} native-libs/ \;

    # 关键修改4：设置Java和JNI库路径
    export JAVA_LIBRARY_PATH=$PWD/native-libs:$JAVA_LIBRARY_PATH
    export LD_LIBRARY_PATH=$PWD/native-libs:$LD_LIBRARY_PATH

    # 构建Java部分
    export GRADLE_USER_HOME=$(mktemp -d)
    gradle --no-daemon -Djava.library.path=$PWD/native-libs assemble
  '';

  installPhase = ''
    echo "Installing jportaudio..."

    # 安装JAR文件
    mkdir -p $out/share/java
    cp build/libs/*.jar $out/share/java/

    # 安装原生库
    mkdir -p $out/lib
    cp ./*.so $out/lib/
    if [ -f $out/lib/libjportaudio_0_1_0.so ]; then
      ln -sf $out/lib/libjportaudio_0_1_0.so $out/lib/libjportaudio.so
    else
      echo "libjportaudio_0_1_0.so not found!"
      return 1
    fi
  '';

  meta = with lib; {
    description = "Java wrapper for PortAudio audio library";
    homepage = "https://github.com/philburk/portaudio-java";
    license = licenses.mit;
  };
}
