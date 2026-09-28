
#!/bin/bash

export PATH=$(pwd)/../aarch64-linux-android-4.9/bin:$PATH
export SEC_BUILD_OPTION_HW_REVISION=02
export PRODUCT_NAME=gts210velte

mkdir Qemu_out

make -C $(pwd) O=$(pwd)/Qemu_out ARCH=arm64 CROSS_COMPILE=aarch64-linux-android-  qemu_config
make -j$(nproc) -C $(pwd) O=$(pwd)/Qemu_out ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- KCFLAGS=-mno-android

cp Qemu_out/arch/arm64/boot/Image $(pwd)/arch/arm64/boot/Image
