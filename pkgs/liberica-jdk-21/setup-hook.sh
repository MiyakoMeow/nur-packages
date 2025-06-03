# shellcheck disable=SC2317
# 设置JDK环境变量的钩子脚本
postHook() {
    # 设置JAVA_HOME环境变量
    export JAVA_HOME="@out@"

    # 将JDK二进制目录加入PATH
    export PATH="@out@/bin:$PATH"
}
postHooks+=(postHook)
