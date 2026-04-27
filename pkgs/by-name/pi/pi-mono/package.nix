{
  lib,
  stdenv,
  pkgs,
  buildNpmPackage,
  fetchFromGitHub,
  nix-update-script,
}:

let
  version = "0.70.2";
  owner = "badlogic";
  repo = "pi-mono";
  src = fetchFromGitHub {
    inherit owner repo;
    rev = "v${version}";
    hash = "sha256-qqmJloTp3mWuZBGgpwoyoFyXx6QD8xhJEwCZb7xFabM=";
  };
in
rec {
  pi-ai = buildNpmPackage {
    pname = "@mariozechner/pi-ai";
    inherit version src;

    npmDepsFetcherVersion = 2;
    npmDepsHash = "sha256-fE/kaSnvXPQczWoqPBZghb6SUQ+6fq65qhmblm1O6Y8=";
    npmWorkspace = "packages/ai";
    npmFlags = [ "--legacy-peer-deps" ];
    npmRebuildFlags = [ "--ignore-scripts" ];

    dontNpmBuild = true;

    buildPhase = ''
      cd packages/ai
      npm run generate-models
      npx tsc -p tsconfig.build.json --skipLibCheck --noEmit false
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/node_modules/@mariozechner
      cp -r packages/ai/dist $out/lib/node_modules/@mariozechner/pi-ai
      runHook postInstall
    '';

    meta = {
      description = "Unified LLM API with automatic model discovery and provider configuration";
      homepage = "https://pi.dev";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [ ];
      platforms = lib.platforms.all;
    };
  };

  pi-tui = buildNpmPackage {
    pname = "@mariozechner/pi-tui";
    inherit version src;

    npmDepsFetcherVersion = 2;
    npmDepsHash = "sha256-fE/kaSnvXPQczWoqPBZghb6SUQ+6fq65qhmblm1O6Y8=";
    npmWorkspace = "packages/tui";
    npmFlags = [ "--legacy-peer-deps" ];
    npmRebuildFlags = [ "--ignore-scripts" ];

    dontNpmBuild = true;

    buildPhase = ''
      cd packages/tui
      npx tsc -p tsconfig.build.json --skipLibCheck --noEmit false
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/node_modules/@mariozechner
      cp -r packages/tui/dist $out/lib/node_modules/@mariozechner/pi-tui
      runHook postInstall
    '';

    meta = {
      description = "Terminal User Interface library with differential rendering";
      homepage = "https://pi.dev";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [ ];
      platforms = lib.platforms.all;
    };
  };

  pi-agent-core = buildNpmPackage {
    pname = "@mariozechner/pi-agent-core";
    inherit version src;

    npmDepsFetcherVersion = 2;
    npmDepsHash = "sha256-fE/kaSnvXPQczWoqPBZghb6SUQ+6fq65qhmblm1O6Y8=";
    npmWorkspace = "packages/agent";
    npmFlags = [ "--legacy-peer-deps" ];
    npmRebuildFlags = [ "--ignore-scripts" ];

    dontNpmBuild = true;

    buildPhase = ''
      cd packages/agent
      npx tsc -p tsconfig.build.json --skipLibCheck --noEmit false
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/node_modules/@mariozechner
      cp -r packages/agent/dist $out/lib/node_modules/@mariozechner/pi-agent-core
      runHook postInstall
    '';

    meta = {
      description = "General-purpose agent with transport abstraction, state management, and attachment support";
      homepage = "https://pi.dev";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [ ];
      platforms = lib.platforms.all;
    };
  };

  pi-mom = buildNpmPackage {
    pname = "@mariozechner/pi-mom";
    inherit version src;

    npmDepsFetcherVersion = 2;
    npmDepsHash = "sha256-fE/kaSnvXPQczWoqPBZghb6SUQ+6fq65qhmblm1O6Y8=";
    npmWorkspace = "packages/mom";
    npmFlags = [ "--legacy-peer-deps" ];
    npmRebuildFlags = [ "--ignore-scripts" ];

    dontNpmBuild = true;

    buildPhase = ''
      cd packages/mom
      npx tsc -p tsconfig.build.json --skipLibCheck --noEmit false
      shx chmod +x dist/main.js
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/node_modules/@mariozechner
      cp -r packages/mom/dist $out/lib/node_modules/@mariozechner/pi-mom
      runHook postInstall
    '';

    meta = {
      description = "Agent for managing other agents";
      homepage = "https://pi.dev";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [ ];
      platforms = lib.platforms.all;
    };
  };

  pi-pods = buildNpmPackage {
    pname = "@mariozechner/pi";
    inherit version src;

    npmDepsFetcherVersion = 2;
    npmDepsHash = "sha256-fE/kaSnvXPQczWoqPBZghb6SUQ+6fq65qhmblm1O6Y8=";
    npmWorkspace = "packages/pods";
    npmFlags = [ "--legacy-peer-deps" ];
    npmRebuildFlags = [ "--ignore-scripts" ];

    dontNpmBuild = true;

    buildPhase = ''
      cd packages/pods
      npx tsc -p tsconfig.build.json --skipLibCheck --noEmit false
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/node_modules/@mariozechner
      cp -r packages/pods/dist $out/lib/node_modules/@mariozechner/pi
      runHook postInstall
    '';

    meta = {
      description = "Pod management agent";
      homepage = "https://pi.dev";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [ ];
      platforms = lib.platforms.all;
    };
  };

  pi-web-ui = buildNpmPackage {
    pname = "@mariozechner/pi-web-ui";
    inherit version src;

    npmDepsFetcherVersion = 2;
    npmDepsHash = "sha256-fE/kaSnvXPQczWoqPBZghb6SUQ+6fq65qhmblm1O6Y8=";
    npmWorkspace = "packages/web-ui";
    npmFlags = [ "--legacy-peer-deps" ];
    npmRebuildFlags = [ "--ignore-scripts" ];

    dontNpmBuild = true;

    buildPhase = ''
      cd packages/web-ui
      npx tsc -p tsconfig.build.json --skipLibCheck --noEmit false
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/node_modules/@mariozechner
      cp -r packages/web-ui/dist $out/lib/node_modules/@mariozechner/pi-web-ui
      runHook postInstall
    '';

    meta = {
      description = "Web UI for pi";
      homepage = "https://pi.dev";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [ ];
      platforms = lib.platforms.all;
    };
  };

  pi-coding-agent = buildNpmPackage {
    pname = "pi-coding-agent";
    inherit version src;

    npmDepsFetcherVersion = 2;
    npmDepsHash = "sha256-fE/kaSnvXPQczWoqPBZghb6SUQ+6fq65qhmblm1O6Y8=";
    npmWorkspace = "packages/coding-agent";
    npmFlags = [ "--legacy-peer-deps" ];
    npmRebuildFlags = [ "--ignore-scripts" ];

    dontNpmBuild = true;

    preBuild = ''
      npm run build --workspace=packages/tui --include-dependencies
      npm run build --workspace=packages/ai --include-dependencies
      npm run build --workspace=packages/agent --include-dependencies
    '';

    buildPhase = ''
      runHook preBuild
      cd packages/coding-agent
      npx tsc -p tsconfig.build.json --skipLibCheck --noEmit false
      shx chmod +x dist/cli.js
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/node_modules/@mariozechner
      cp -r packages/coding-agent/dist $out/lib/node_modules/@mariozechner/pi-coding-agent
      mkdir -p $out/bin
      cat > $out/bin/pi <<EOF
      #!/bin/sh
      exec ${pkgs.nodejs}/bin/node $out/lib/node_modules/@mariozechner/pi-coding-agent/dist/cli.js "\$@"
      EOF
      chmod +x $out/bin/pi
      runHook postInstall
    '';

    passthru = {
      updateScript = nix-update-script {
        packageName = "@mariozechner/pi-coding-agent";
        url = "https://github.com/${owner}/${repo}";
      };
    };

    meta = {
      description = "Coding agent CLI with read, bash, edit, write tools and session management";
      homepage = "https://pi.dev";
      changelog = "https://github.com/${owner}/${repo}/blob/v${version}/packages/coding-agent/CHANGELOG.md";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [ ];
      mainProgram = "pi";
      platforms = lib.platforms.all;
    };
  };
}