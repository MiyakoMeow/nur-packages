# generate-theme-info.nix
{
  lib,
  stdenv,
  writeShellScriptBin,
  python3,
  jq,
  config ? {
    owner = "voidlhf";
    repo = "StarRailGrubThemes";
    tag = "20250524-070052";
  },
}:
stdenv.mkDerivation {
  name =
    "star-rail-theme-info"
    + (lib.optionalString (config.tag != null) "-${lib.replaceStrings ["/"] ["-"] config.tag}");

  nativeBuildInputs = [
    (writeShellScriptBin "generate-theme-info" ''
      ${python3}/bin/python ${./generate-theme-info.py} \
        --owner "${config.owner}" \
        --repo "${config.repo}" \
        ${lib.optionalString (config.tag != null) "--tag \"${config.tag}\""}
    '')
    jq
  ];

  buildCommand = ''
    # 生成原始JSON
    generate-theme-info > raw.json

    # 验证JSON格式
    if ! jq empty raw.json; then
      echo "Invalid JSON generated!"
      exit 1
    fi

    # 添加元数据
    jq --arg date "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
       --arg owner "${config.owner}" \
       --arg repo "${config.repo}" \
       --arg tag "${
      if config.tag != null
      then config.tag
      else "all"
    }" \
       '. + {
         _metadata: {
           generated_at: $date,
           repository: "\($owner)/\($repo)",
           release_tag: $tag
         }
       }' raw.json > $out
  '';

  # 固定输出推导
  outputHashMode = "flat";
  outputHashAlgo = "sha256";
  outputHash = lib.fakeSha256;

  __noChroot = true;
  allowSubstitutes = false;
  preferLocalBuild = false;
}
