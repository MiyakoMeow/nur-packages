{
  lib,
  pkgs,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  glib,
  vulkan-loader,
  libglvnd,
  mesa,
  libdrm,
  gtk3,
  xorg,
  makeDesktopItem,
  copyDesktopItems,
  wrapGAppsHook,
  polkit, # 用于权限管理
  ...
}:
stdenv.mkDerivation rec {
  pname = "mihomo-party";
  version = "1.7.2"; # 根据实际版本修改

  # 从你的下载地址替换这个URL
  src = fetchurl {
    url = "https://dl.p6p.net/mihomo-party/v${version}/mihomo-party-linux-${version}-amd64.deb";
    sha256 = "13kl4afla19yhy3hhrdb8pmvc8cmcj6pbyh29w40vdzjmp8dp6c4";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook # 自动处理库依赖
    makeWrapper # 新增包装工具
    copyDesktopItems
    wrapGAppsHook
    polkit # 用于权限管理
  ];

  buildInputs = with pkgs; [
    glib
    vulkan-loader
    # 基础依赖
    nss
    nspr
    dbus
    systemd

    # GUI相关依赖
    gtk3
    atk
    at-spi2-atk
    at-spi2-core
    cups
    alsa-lib

    # X11窗口系统依赖
    libxkbcommon
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxcb

    # 图形渲染相关
    mesa

    # 已找到但需要显式声明的依赖
    pango
    cairo
    expat

    # 新增 OpenGL/Vulkan 相关依赖
    mesa # 提供 libGL.so.1
    libglvnd # OpenGL 库的抽象层

    # 新增 GTK 模块
    gnome-color-manager # 提供 colorreload-gtk-module
    gnome-settings-daemon # 提供colorreload-gtk-module

    # 补充图形驱动相关
    libdrm
    libva
    xorg.libXxf86vm
  ];

  # 解包.deb文件
  unpackPhase = ''
    dpkg -x $src .
  '';

  installPhase = ''
    runHook preInstall

    # 安装到Nix存储的opt目录
    mkdir -p $out/opt/mihomo-party
    cp -r opt/mihomo-party/* $out/opt/mihomo-party/

    # 创建可执行文件链接到bin目录
    mkdir -p $out/bin
    makeWrapper $out/opt/mihomo-party/mihomo-party $out/bin/mihomo-party \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [
      glib
      vulkan-loader
      libglvnd
      mesa
      gtk3
      libdrm
    ]}" \
      --prefix VK_ICD_FILENAMES : "${vulkan-loader}/share/vulkan/icd.d/" \
      --prefix __EGL_VENDOR_LIBRARY_DIRS = "${pkgs.mesa}/share/glvnd/egl_vendor.d:${pkgs.libglvnd}/share/glvnd/egl_vendor.d" \
      --prefix LIBGL_DRIVERS_PATH : "${libglvnd}/lib:${vulkan-loader}/lib" \
      --prefix GTK_PATH : "${pkgs.gnome-settings-daemon}/lib/gtk-3.0/modules" \
      --set XDG_DATA_DIRS "${gtk3}/share/gsettings-schemas/${gtk3.name}" \
      --prefix PATH : "${lib.makeBinPath [xorg.xrandr]}"

    # 安装桌面图标
    mkdir -p $out/share/icons
    cp -r usr/share/icons/* $out/share/icons

    runHook postInstall
  '';

  # 修复可执行文件的库路径
  autoPatchelfIgnoreMissingDeps = [
    # 列出需要忽略的依赖（如果有）
  ];

  # 定义桌面文件
  desktopItems = [
    (makeDesktopItem {
      name = "Mihomo Party";
      exec = "mihomo-party";
      icon = "mihomo-party";
      comment = "Mihomo Party Application";
      desktopName = "Mihomo Party";
      categories = ["Network"];
      startupWMClass = "mihomo-party"; # 确保窗口匹配
    })
  ];

  meta = with lib; {
    description = "Mihomo Party Application";
    homepage = "https://mihomoparty.org"; # 替换实际官网
    license = licenses.mit; # 根据实际许可证修改
    platforms = ["x86_64-linux"]; # 根据架构需求修改
    mainProgram = "mihomo-party";
    broken = true;
  };
}
