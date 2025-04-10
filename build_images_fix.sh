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
