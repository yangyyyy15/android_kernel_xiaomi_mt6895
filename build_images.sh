#!/bin/bash
set -euo pipefail

# 获取当前日期
BUILD_DATE=$(date +'%Y%m%d')

# 创建 AnyKernel3 zip
if [ ! -f "./out/arch/arm64/boot/Image.gz" ]; then
    echo "Error: Image.gz not found. Please build the kernel first."
    exit 1
fi

echo "===== Creating AnyKernel3 package ====="
cp ./out/arch/arm64/boot/Image.gz ./Image.gz
cd AnyKernel3
ZIP_NAME="android12-5.10.X-lts-${BUILD_DATE}-AnyKernel3.zip"
echo "Creating zip file: $ZIP_NAME..."
cp ../Image.gz ./Image.gz
zip -r "../$ZIP_NAME" ./*
rm ./Image.gz
cd ..

# 构建 boot image
echo "===== Building boot image ====="
mkdir -p bootimgs
cd bootimgs

GKI_URL=https://dl.google.com/android/gki/gki-certified-boot-android12-5.10-2025-02_r1.zip
FALLBACK_URL=https://dl.google.com/android/gki/gki-certified-boot-android12-5.10-2023-01_r1.zip

echo "Checking if GKI kernel URL is reachable: $GKI_URL"
status=$(curl -sL -w "%{http_code}" "$GKI_URL" -o /dev/null)

if [ "$status" = "200" ]; then
    echo "[+] Downloading from GKI_URL"
    curl -Lo gki-kernel.zip "$GKI_URL"
else
    echo "[+] $GKI_URL not found, using $FALLBACK_URL"
    curl -Lo gki-kernel.zip "$FALLBACK_URL"
fi

echo "Unzipping the downloaded kernel..."
unzip -o gki-kernel.zip && rm gki-kernel.zip

echo "Unpacking boot.img..."
FULL_PATH=$(pwd)/boot-5.10.img
echo "Unpacking using: $FULL_PATH"

echo "Running unpack_bootimg.py..."
python3 $UNPACK_BOOTIMG --boot_img="$FULL_PATH"

echo "Building boot.img"
cp ../Image.gz ./Image.gz
python3 $MKBOOTIMG --header_version 4 --kernel Image.gz --output boot.img --ramdisk out/ramdisk --os_version 12.0.0 --os_patch_level 2025-02
#python3 $AVBTOOL add_hash_footer --partition_name boot --partition_size $((64 * 1024 * 1024)) --image boot.img --algorithm SHA256_RSA2048 --key $BOOT_SIGN_KEY_PATH

$AVBTOOL add_hash_footer --partition_name boot --partition_size $((64 * 1024 * 1024)) --image boot.img --algorithm SHA256_RSA2048 --key $BOOT_SIGN_KEY_PATH

cp ./boot.img "../android12-5.10.X-lts-${BUILD_DATE}-boot.img"

cd ..
echo "===== Build Complete ====="
echo "Output files:"
echo " - $(pwd)/${ZIP_NAME}"
echo " - $(pwd)/android12-5.10.X-lts-${BUILD_DATE}-boot.img"
