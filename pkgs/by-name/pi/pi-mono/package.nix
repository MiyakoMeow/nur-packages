{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeBinaryWrapper,
  ripgrep,
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

  npmDepsHash = "sha256-fE/kaSnvXPQczWoqPBZghb6SUQ+6fq65qhmblm1O6Y8=";

  fixWorkspaceSymlinks = runtimeDeps: ''
    local nm="$out/lib/node_modules/pi-monorepo/node_modules"

    for ws in ${lib.concatStringsSep " \\\n                " runtimeDeps}; do
      IFS=: read -r pkg src <<< "$ws"
      rm "$nm/$pkg"
      cp -r "$src" "$nm/$pkg"
    done

    find "$nm" -type l -lname '*/packages/*' -delete
    find "$nm/.bin" -xtype l -delete
  '';
in
rec {
  pi-ai = buildNpmPackage {
    pname = "pi-ai";
    inherit version src npmDepsHash;
    npmDepsFetcherVersion = 2;
    npmWorkspace = "packages/ai";
    npmFlags = [ "--legacy-peer-deps" ];
    npmRebuildFlags = [ "--ignore-scripts" ];

    buildPhase = ''
      runHook preBuild
      npx tsgo -p packages/ai/tsconfig.build.json
      runHook postBuild
    '';

    postInstall = fixWorkspaceSymlinks [ ];

    meta = {
      description = "Unified LLM API with automatic model discovery and provider configuration";
      homepage = "https://pi.dev";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [ ];
      mainProgram = "pi-ai";
      platforms = lib.platforms.all;
    };
  };

  pi-coding-agent = buildNpmPackage {
    pname = "pi-coding-agent";
    inherit version src npmDepsHash;
    npmDepsFetcherVersion = 2;
    npmWorkspace = "packages/coding-agent";
    npmFlags = [ "--legacy-peer-deps" ];
    npmRebuildFlags = [ "--ignore-scripts" ];

    nativeBuildInputs = [ makeBinaryWrapper ];

    buildPhase = ''
      runHook preBuild
      npx tsgo -p packages/ai/tsconfig.build.json
      npx tsgo -p packages/tui/tsconfig.build.json
      npx tsgo -p packages/agent/tsconfig.build.json
      npm run build --workspace=packages/coding-agent
      runHook postBuild
    '';

    postInstall = fixWorkspaceSymlinks [
      "@mariozechner/pi-ai:packages/ai"
      "@mariozechner/pi-agent-core:packages/agent"
      "@mariozechner/pi-tui:packages/tui"
    ];

    postFixup = "wrapProgram $out/bin/pi --prefix PATH : ${lib.makeBinPath [ ripgrep ]}";

    passthru.updateScript = nix-update-script { };

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

  pi-pods = buildNpmPackage {
    pname = "pi-pods";
    inherit version src npmDepsHash;
    npmDepsFetcherVersion = 2;
    npmWorkspace = "packages/pods";
    npmFlags = [ "--legacy-peer-deps" ];
    npmRebuildFlags = [ "--ignore-scripts" ];

    buildPhase = ''
      runHook preBuild
      npx tsgo -p packages/ai/tsconfig.build.json
      npx tsgo -p packages/agent/tsconfig.build.json
      npm run build --workspace=packages/pods
      runHook postBuild
    '';

    postInstall = fixWorkspaceSymlinks [
      "@mariozechner/pi-ai:packages/ai"
      "@mariozechner/pi-agent-core:packages/agent"
    ];

    meta = {
      description = "Pod management agent";
      homepage = "https://pi.dev";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [ ];
      mainProgram = "pi-pods";
      platforms = lib.platforms.all;
    };
  };

  pi-mom = buildNpmPackage {
    pname = "pi-mom";
    inherit version src npmDepsHash;
    npmDepsFetcherVersion = 2;
    npmWorkspace = "packages/mom";
    npmFlags = [ "--legacy-peer-deps" ];
    npmRebuildFlags = [ "--ignore-scripts" ];

    buildPhase = ''
      runHook preBuild
      npx tsgo -p packages/ai/tsconfig.build.json
      npx tsgo -p packages/tui/tsconfig.build.json
      npx tsgo -p packages/agent/tsconfig.build.json
      npm run build --workspace=packages/coding-agent
      npm run build --workspace=packages/mom
      runHook postBuild
    '';

    postInstall = fixWorkspaceSymlinks [
      "@mariozechner/pi-ai:packages/ai"
      "@mariozechner/pi-agent-core:packages/agent"
      "@mariozechner/pi-tui:packages/tui"
      "@mariozechner/pi-coding-agent:packages/coding-agent"
    ];

    meta = {
      description = "Agent for managing other agents";
      homepage = "https://pi.dev";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [ ];
      mainProgram = "mom";
      platforms = lib.platforms.all;
    };
  };
}
