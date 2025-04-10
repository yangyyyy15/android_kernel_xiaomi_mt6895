#!/bin/bash
set -eo pipefail

# Get absolute path of current directory
KERNEL_DIR=$(pwd)
PARENT_DIR=$(dirname "$KERNEL_DIR")

# Determine if script is being sourced or executed
# $0 will be "-bash" or similar when sourced, and the script name when executed
SOURCED=0
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    SOURCED=1
    echo "===== Configuring Android Kernel Build Environment ====="
else
    echo "===== Full Android Kernel Build Environment Setup ====="
fi

# Function to configure environment variables
configure_environment() {
    echo "Setting up build environment variables..."
    export CLANG_PATH="$PARENT_DIR/clang-tc/bin/"
    export PATH="${CLANG_PATH}:${PATH}"
    export CLANG_TRIPLE="aarch64-linux-gnu-"
    export CROSS_COMPILE="aarch64-linux-gnu-"

    # Initialize environment variables for building boot image
    export BOOT_SIGN_KEY_PATH="$PARENT_DIR/kernel-build-tools/linux-x86/share/avb/testkey_rsa2048.pem"
    export AVBTOOL="$PARENT_DIR/kernel-build-tools/linux-x86/bin/avbtool"
    export MKBOOTIMG="$PARENT_DIR/mkbootimg/mkbootimg.py"
    export UNPACK_BOOTIMG="$PARENT_DIR/mkbootimg/unpack_bootimg.py"

    # Setup ccache
    if [ ! -d ".ccache" ]; then
        mkdir -p .ccache
    fi
    export CCACHE_DIR="$(pwd)/.ccache"
    export USE_CCACHE=1
    ccache -M 7.5G

    # Make sure mkbootimg scripts are executable
    chmod +x "$MKBOOTIMG" "$UNPACK_BOOTIMG" 2>/dev/null || true
    
    echo "Environment variables configured successfully!"
}

# Function to check if tools exist
check_tools() {
    local tools_missing=0
    
    if [ ! -d "$PARENT_DIR/kernel-build-tools" ]; then
        echo "kernel-build-tools directory not found"
        tools_missing=1
    fi

    if [ ! -d "$PARENT_DIR/mkbootimg" ]; then
        echo "mkbootimg directory not found"
        tools_missing=1
    fi

    if [ ! -d "$PARENT_DIR/clang-tc" ]; then
        echo "clang-tc directory not found"
        tools_missing=1
    fi
    
    return $tools_missing
}

# When sourced, only check and configure
if [ $SOURCED -eq 1 ]; then
    echo "Checking for required tools..."
    if check_tools; then
        echo "All tools found, configuring environment variables..."
        configure_environment
    else
        echo "Some tools are missing. Run 'bash env.sh' to install all tools."
        # Return early without setting up the environment
        return 1
    fi
else
    # Full installation mode
    # 更新并安装必要的依赖
    echo "[1/9] Installing dependencies..."
    sudo apt update -y
    sudo apt install bc binutils-dev bison build-essential ccache curl flex git libelf-dev lld make python3-dev cpio python-is-python3 tar perl wget lz4 unzip openssl -y

    # 清理内核源码树 (可选步骤)
    echo "[2/9] Cleaning kernel source tree..."
    if [ -d "out" ]; then
        echo "Removing existing build output directory"
        rm -rf out
    fi

    # 询问是否运行 make mrproper (WSL可能会崩溃)
    read -p "WSL may crash when running 'make mrproper'. Do you want to run it anyway? (y/N): " run_mrproper
    if [[ "$run_mrproper" == "y" || "$run_mrproper" == "Y" ]]; then
        echo "Running 'make mrproper' to clean source tree (this might crash WSL)..."
        make mrproper || echo "make mrproper failed or was interrupted. Continuing with setup..."
    else
        echo "Skipping 'make mrproper'. If build fails with 'source tree not clean' error, you may need to run it manually."
    fi

    # 克隆 AnyKernel3 仓库
    echo "[3/9] Setting up AnyKernel3..."
    if [ ! -d "AnyKernel3" ]; then
        git clone https://github.com/bachnxuan/AnyKernel3.git AnyKernel3
        cd AnyKernel3 && rm -rf .git .github && cd ..
    else
        echo "AnyKernel3 directory already exists, skipping clone"
    fi

    # 初始化 KernelSU-Next 子模块
    echo "[4/9] Initializing KernelSU-Next submodule..."
    if [ -d "KernelSU-Next" ]; then
        git submodule update --init --recursive
        cd KernelSU-Next
        git fetch --unshallow origin next-susfs-dev:next-susfs-dev || git fetch origin next-susfs-dev:next-susfs-dev
        git checkout next-susfs-dev
        git pull origin next-susfs-dev
        cd ..
    else
        echo "KernelSU-Next directory not found, make sure you're in the correct source directory"
        exit 1
    fi

    # 清理现有工具链目录（如果存在）
    echo "[5/9] Cleaning up existing toolchain directories..."
    if [ -d "$PARENT_DIR/kernel-build-tools" ]; then
        echo "Removing existing kernel-build-tools directory"
        rm -rf "$PARENT_DIR/kernel-build-tools"
    fi

    if [ -d "$PARENT_DIR/mkbootimg" ]; then
        echo "Removing existing mkbootimg directory"
        rm -rf "$PARENT_DIR/mkbootimg"
    fi

    if [ -d "$PARENT_DIR/clang-tc" ]; then
        echo "Removing existing clang-tc directory"
        rm -rf "$PARENT_DIR/clang-tc"
    fi

    # 清理ccache目录（如果存在）
    if [ -d ".ccache" ]; then
        echo "Removing existing .ccache directory"
        rm -rf ".ccache"
    fi

    # 设置 ccache
    echo "[6/9] Setting up ccache..."
    mkdir -p .ccache
    export CCACHE_DIR="$(pwd)/.ccache"
    export USE_CCACHE=1
    ccache -M 7.5G

    # 下载工具链
    echo "[7/9] Downloading toolchain to match CI environment..."
    AOSP_MIRROR=https://android.googlesource.com
    BRANCH=main-kernel-build-2024

    # Download tools to parent directory to match CI workflow
    cd "$PARENT_DIR"

    echo "Cloning kernel-build-tools to $PARENT_DIR/kernel-build-tools"
    git clone $AOSP_MIRROR/kernel/prebuilts/build-tools -b $BRANCH --depth 1 kernel-build-tools

    echo "Cloning mkbootimg to $PARENT_DIR/mkbootimg"
    git clone $AOSP_MIRROR/platform/system/tools/mkbootimg -b $BRANCH --depth 1 mkbootimg

    echo "Creating clang-tc directory in $PARENT_DIR/clang-tc"
    mkdir -p clang-tc && cd clang-tc
    echo "Downloading Clang toolchain (this may take a while)..."
    # 使用与 release.yml 相同的版本
    wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/tags/android-12.0.0_r12/clang-r416183b1.tar.gz
    tar -xf clang-r416183b1.tar.gz
    rm -rf clang-r416183b1.tar.gz

    # 返回内核目录
    cd "$KERNEL_DIR"

    # 创建测试密钥（如果需要）
    echo "[8/9] Setting up boot sign key..."
    if [ ! -f "$PARENT_DIR/kernel-build-tools/linux-x86/share/avb/testkey_rsa2048.pem" ]; then
        echo "Creating test key for boot signing (for development only)..."
        mkdir -p "$PARENT_DIR/kernel-build-tools/linux-x86/share/avb/"
        openssl genrsa -out "$PARENT_DIR/kernel-build-tools/linux-x86/share/avb/testkey_rsa2048.pem" 2048
    fi

    # 设置编译环境变量
    echo "[9/9] Setting up build environment variables..."
    configure_environment

    # 创建一个辅助脚本，如果需要清理源码树
    cat > clean_source_tree.sh << 'EOF'
#!/bin/bash
echo "WARNING: This might crash WSL. Save all work before proceeding."
read -p "Do you want to continue? (y/N): " confirm
if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    echo "Running 'make mrproper'..."
    make mrproper
    echo "Source tree cleaned."
else
    echo "Operation cancelled."
fi
EOF
    chmod +x clean_source_tree.sh

    # 更新build_images.sh的路径
    cat > build_images_fix.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Get absolute path of current directory
KERNEL_DIR=$(pwd)
PARENT_DIR=$(dirname "$KERNEL_DIR")

# 获取当前日期
BUILD_DATE=$(date +'%Y%m%d')

# 为build_images.sh设置环境变量
export BOOT_SIGN_KEY_PATH="$PARENT_DIR/kernel-build-tools/linux-x86/share/avb/testkey_rsa2048.pem"
export AVBTOOL="$PARENT_DIR/kernel-build-tools/linux-x86/bin/avbtool"
export MKBOOTIMG="$PARENT_DIR/mkbootimg/mkbootimg.py"
export UNPACK_BOOTIMG="$PARENT_DIR/mkbootimg/unpack_bootimg.py"

# 执行原始的build_images.sh
bash build_images.sh
EOF
    chmod +x build_images_fix.sh

    # 输出环境设置完成信息
    echo ""
    echo "===== Environment Setup Complete ====="
    echo "To build the kernel, run:"
    echo "bash build.sh"
    echo ""
    echo "After building, run the following to create AnyKernel3 zip and boot image:"
    echo "bash build_images_fix.sh  # This will set the correct environment variables"
    echo ""
    echo "If you encounter 'source tree is not clean' error, run:"
    echo "bash clean_source_tree.sh  # WARNING: This might crash WSL"
    echo ""
fi