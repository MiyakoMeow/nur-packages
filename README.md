# **[MiyakoMeow](https://github.com/MiyakoMeow)'s personal [NUR](https://github.com/nix-community/NUR) repository**

## Usage

- `flake.nix`:

```nix
inputs = {
  # NixOS 官方软件源，这里使用 nixos-25.05 分支
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  nur-miyakomeow = {
    url = "github:MiyakoMeow/nur-packages";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

- (Optional) Add Cache Server in `configuration.nix`:

```nix
nix.settings = {
  # Use Flake & Nix Commands
  experimental-features = ["nix-command" "flakes"];
  substituters = [
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
    "https://nix-community.cachix.org"
    "https://miyakomeow.cachix.org"
  ];
  trusted-public-keys = [
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "miyakomeow.cachix.org-1:85k7pjjK1Voo+kMHJx8w3nT1rlBow3+4/M+LsAuMCRY="
  ];
};
```

- Install a pack in `configuration.nix`:

```nix
environment.systemPackages = with pkgs; let
  nur-miyakomeow = inputs.nur-miyakomeow.packages.${pkgs.system};
in [
  nur-miyakomeow.liberica-jdk-21
];
```

- Or Use `nixpkgs.overlay`:

```nix
# nixpkgs设置
nixpkgs = {
  config = {
    # 可选：允许非自由软件
    allowUnfree = true;
  };
  overlays = [
    # NUR
    inputs.nur.overlays.default
    # MiyakoMeow's NUR Repo
    (final: prev: {
      nur-miyakomeow = import inputs.nur-miyakomeow {
        # 关键点：使用当前系统的配置，使上述config能够生效
        pkgs = prev;
      };
    })
  ];
};

environment.systemPackages = with pkgs.nur-miyakomeow; [
  liberica-jdk-21 
];
```

## Status

<!-- Remove this if you don't use github actions -->
![Build and populate cache](https://github.com/MiyakoMeow/nur-packages/workflows/Build%20and%20populate%20cache/badge.svg)

<!--
Uncomment this if you use travis:

[![Build Status](https://travis-ci.com/<YOUR_TRAVIS_USERNAME>/nur-packages.svg?branch=master)](https://travis-ci.com/<YOUR_TRAVIS_USERNAME>/nur-packages)
-->
[![Cachix Cache](https://img.shields.io/badge/cachix-miyakomeow-blue.svg)](https://miyakomeow.cachix.org)

## Package List
