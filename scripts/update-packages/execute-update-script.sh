#!/usr/bin/env bash
set -euo pipefail

# execute-update-script.sh
# 在 GitHub Actions 的 update-package job 中执行，接收一个包属性路径作为参数。

if [ $# -lt 1 ]; then
  echo "用法: bash scripts/update-packages/execute-update-script.sh <package-attr-path>"
  exit 1
fi

PACKAGE="$1"

# Helper: 向 GitHub Actions 的 $GITHUB_OUTPUT 追加输出（本地调试时退回到 stdout）
append_github_output() {
  # $1 = key, $2 = value
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"
  else
    printf '%s=%s\n' "$1" "$2"
  fi
}

# 设置 Git 用户信息
git config --global user.email "actions@github.com"
git config --global user.name "GitHub Actions"

# 传入绝对 flake 引用，避免内置 '.' 被拒绝
export FLAKE_REF="path:${GITHUB_WORKSPACE:-$PWD}"

# 准备执行环境变量（兼容不同脚本类型）
export NIXPKGS_ALLOW_UNFREE=1
export NIXPKGS_ALLOW_BROKEN=1
export NIXPKGS_ALLOW_INSECURE=1

echo "NIX_PATH=$NIX_PATH"

# 使用临时HOME目录以防脚本写入HOME
export ORI_HOME="$HOME"
export HOME=$(mktemp -d)

echo "获取包 $PACKAGE 的updateScript"
script_json=$(nix eval --impure --json --expr "
  let
    f = builtins.getFlake (builtins.getEnv \"FLAKE_REF\");
    sys = \"x86_64-linux\";
    lp = builtins.getAttr sys f.legacyPackages;
    pkgsN = import <nixpkgs> {};
    lib = pkgsN.lib;
    path = lib.strings.splitString \".\" \"${PACKAGE}\";
    pkg = lib.attrsets.attrByPath path null lp;
  in
    if pkg == null then throw \"no pkg\"
    else if (pkg ? passthru && pkg.passthru ? updateScript) then pkg.passthru.updateScript
    else if (pkg ? updateScript) then pkg.updateScript
    else throw \"no updateScript\"
")
script_type=$(echo "$script_json" | jq -r 'type')

# 从 store 路径转换为本地路径
convert_store_path_to_local() {
  local store_path="$1"
  local workdir="${GITHUB_WORKSPACE:-$PWD}"
  
  if [[ "$store_path" =~ ^/nix/store/[a-z0-9]+-(.+)$ ]]; then
    local filename="${BASH_REMATCH[1]}"
    local local_path
    # 尝试在当前工作目录中查找同名文件
    local_path=$(find "$workdir" -name "$filename" -type f 2>/dev/null | head -n1)
    if [ -n "$local_path" ]; then
      echo "$local_path"
      return 0
    fi
  fi
  echo "$store_path"
  return 1
}

# 执行自定义 bash 脚本并处理 JSON 输出
execute_custom_script() {
  local script_array=("$@")
  local cmd="${script_array[0]}"
  
  # 检查是否是 bash 脚本
  if [[ "$cmd" != "bash" ]]; then
    return 1
  fi
  
  # 查找 .sh 脚本路径
  local script_path=""
  for arg in "${script_array[@]}"; do
    if [[ "$arg" =~ \.sh$ ]] || [[ "$arg" == *"update.sh" ]]; then
      script_path="$arg"
      break
    fi
  done
  
  if [ -z "$script_path" ]; then
    return 1
  fi
  
  # 尝试转换为本地路径
  local local_path
  if convert_store_path_to_local "$script_path" >/dev/null 2>&1; then
    local_path=$(convert_store_path_to_local "$script_path")
    echo "检测到自定义更新脚本: $script_path -> $local_path"
    
    # 替换为本地路径
    local new_array=()
    for arg in "${script_array[@]}"; do
      if [ "$arg" = "$script_path" ]; then
        new_array+=("$local_path")
      else
        new_array+=("$arg")
      fi
    done
    
    # 设置环境变量
    export UPDATE_NIX_ATTR_PATH="$PACKAGE"
    
    # 执行脚本并捕获输出
    echo "执行更新脚本: ${new_array[@]}"
    local output
    output=$("${new_array[@]}" 2>&1) || true
    local exit_code=$?
    
    echo "$output"
    
    # 检查是否是 JSON 输出
    if echo "$output" | jq -e . >/dev/null 2>&1; then
      echo "检测到 JSON 输出，处理更新..."
      
      # 解析 JSON 获取要更新的文件
      local files
      files=$(echo "$output" | jq -r '.[0].files[]?' 2>/dev/null || echo "")
      
      if [ -n "$files" ]; then
        for file in $files; do
          # 获取新版本和新 hash
          local new_version new_sha256
          new_version=$(echo "$output" | jq -r '.[0].newVersion' 2>/dev/null || echo "")
          new_sha256=$(echo "$output" | jq -r '.[0].newSha256' 2>/dev/null || echo "")
          
          if [ -f "$file" ] && [ -n "$new_version" ] && [ -n "$new_sha256" ]; then
            echo "更新文件: $file"
            echo "  version: $new_version"
            echo "  sha256: $new_sha256"
            
            # 更新 version 和 sha256
            sed -i -E \
              -e "s|(version = \")[0-9]+\.[0-9]+(\";)|\1${new_version}\2|" \
              -e "s|(sha256 = \")[^\"]+(\";)|\1${new_sha256}\2|" \
              "$file"
            echo "已更新 $file"
          fi
        done
      fi
    fi
    
    if [ $exit_code -ne 0 ] && [ -n "$output" ]; then
      # 检查是否是 "无需更新" 的情况
      if echo "$output" | grep -q "无需更新\|no changes\|already up to date"; then
        return 0
      fi
      return $exit_code
    fi
    
    return 0
  fi
  
  return 1
}

# 将命令数组重写为使用完整属性路径的 nix-update，并保留标志参数
execute_command_array() {
  local script_array=("$@")
  local cmd="${script_array[0]}"

  # 尝试执行自定义 bash 脚本（默认行为）
  if execute_custom_script "${script_array[@]}"; then
    return
  fi

  # 将 store 路径的 nix-update 规范化为 "nix-update"
  if [[ "$cmd" =~ ^/nix/store/.*/bin/nix-update$ ]]; then
    cmd="nix-update"
    script_array[0]="nix-update"
  fi

  if [[ "$cmd" == "nix-update" ]]; then
    local new_command=("nix-update")
    local has_flake=0

    # 保留所有以 - 开头或包含 = 的标志参数；丢弃位置参数，最后追加完整属性路径
    for ((i=1; i<${#script_array[@]}; i++)); do
      arg="${script_array[$i]}"
      if [[ "$arg" == "--flake" ]]; then
        has_flake=1
      fi
      if [[ "$arg" == -* || "$arg" == *=* ]]; then
        new_command+=("$arg")
      fi
    done

    if [[ $has_flake -eq 0 ]]; then
      new_command+=("--flake")
    fi

    new_command+=("$PACKAGE")

    echo "替换后的命令: ${new_command[@]}"
    "${new_command[@]}"
  else
    # 非 nix-update 命令按原样执行
    echo "执行更新命令(数组): ${script_array[@]}"
    "${script_array[@]}"
  fi
}

case "$script_type" in
  "array")
    mapfile -t script_array < <(echo "$script_json" | jq -r '.[]')
    execute_command_array "${script_array[@]}"
    ;;
  "string")
    command_str=$(echo "$script_json" | jq -r '.')
    # 将字符串拆分为数组以便重写
    read -r -a script_array <<< "$command_str"
    execute_command_array "${script_array[@]}"
    ;;
  "object")
    if echo "$script_json" | jq -e 'has("command")' >/dev/null; then
      command_type=$(echo "$script_json" | jq -r '.command | type')
      if [ "$command_type" = "array" ]; then
        mapfile -t script_array < <(echo "$script_json" | jq -r '.command[]')
        execute_command_array "${script_array[@]}"
      elif [ "$command_type" = "string" ]; then
        command_str=$(echo "$script_json" | jq -r '.command')
        read -r -a script_array <<< "$command_str"
        execute_command_array "${script_array[@]}"
      else
        echo "错误：不支持的command类型: $command_type"
        exit 1
      fi
    else
      echo "错误：属性集缺少command字段"
      exit 1
    fi
    ;;
  *)
    echo "错误：未知的updateScript类型: $script_type"
    exit 1
    ;;
esac

# 恢复原始HOME并清理临时目录
export TEMP_HOME="$HOME"
export HOME="$ORI_HOME"
rm -rf "$TEMP_HOME"

# 检查是否有需要提交的更改（不在此处提交，交由后续PR步骤）
if [ -n "$(git status --porcelain)" ]; then
    append_github_output "has_update" "true"
    echo "更新完成: $PACKAGE"
else
    append_github_output "has_update" "false"
    echo "没有更新: $PACKAGE"
fi