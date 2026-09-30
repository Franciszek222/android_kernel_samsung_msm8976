Debugging certain functions can be particularly challenging—especially when dealing with a kernel function where an error causes the device to reset abruptly. Solutions like `pstore`—which saves kernel logs to RAM for later analysis following a warm reset—are not always sufficient. For instance, when dealing with a race condition that requires tracing memory accesses, print-based debugging becomes impractical. Therefore, to attach a debugger to the kernel and trace the precise processes occurring within it, one should use the QEMU virtual machine.

However, running a heavily modified kernel on a virtual machine is not straightforward, as it requires:
*   correctly configuring the kernel to enable `virtio` drivers
*   fixing compilation errors
*   booting the kernel within a virtual machine running a standard Linux distribution

Having successfully completed these steps, I will briefly outline the necessary actions in this note.

0. Before we begin
You need to download the "vanilla" kernel tree—the unmodified, original Linux kernel. You can do this via:

`wget -t 0 -O - https://cdn.kernel.org/pub/linux/kernel/v3.x/linux-3.10.108.tar.xz | xz -cd | tar xvf -`

1. Kernel configuration

Note: I have included my ready-made kernel configuration in the repository at `Qemu_out/.config`. Feel free to use it if you wish. The first step is to generate the default configuration; if the `arch/arm64/defconfig` file is missing, you must copy it from the vanilla source.

`make -C $(pwd) O=$(pwd)/qemu_out ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- KCFLAGS=-mno-android defconfig`

Next, you need to customize the resulting configuration to meet your requirements. For instance, I want to debug the TCP stack (and potentially other mechanisms), so I target the entire segment spanning from `CONFIG_NET=y` to `CONFIG_L2TP=y`. I copy this into `qemu_out/.config`, overwriting the corresponding section. Generally speaking, one should never manually edit the configuration, but I am doing so in this specific instance. You must insert the snippet at the exact location in the file where it originally appeared.

Then, disable any features enabled by the default configuration that aren't needed. Enabling extra features in downstream kernels often leads to additional compilation issues. Disable any items that are not present in the device configuration you are building against. Note: `out/.config` is intended to be the final configuration file resulting from a command such as: `make -C $(pwd) O=$(pwd)/out ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- KCFLAGS=-mno-android VARIANT_DEFCONFIG=msm8976_sec_defconfig gts210vewifi_defconfig SELINUX_DEFCONFIG=selinux_defconfig SELINUX_LOG_DEFCONFIG=selinux_log_defconfig TIMA_DEFCONFIG=tima8976_defconfig DMVERITY_DEFCONFIG=dmverity_defconfig`

for i in $(cat Qemu_out/.config|grep =y); do grep $(echo $i | sed -e 's/=y//g') out/.config | grep -v =y | awk '{print $2}' ; done > raw.txt
cat raw.txt | sort | uniq > disable.txt

Next, when you start the Linux build process, a "restart config" phase will trigger; the script will ask questions about options that were not in our original config but arise from the options we previously enabled. For instance, if we run `scripts/config --file Qemu_out/.config --enable CONFIG_PCI`, the script will politely ask if we want to enable specific network cards that likely have no use outside the x86 market. Our role is to answer "No," unless the option relates to VIRTIO.

Okay, if you’ve reached this stage and everything is working, that’s great. Compilation errors might occur, but you shouldn't be compiling the kernel right now; instead, ensure that a single "restart config" pass doesn't lead to repeated, successive prompts every time. If that happens, something is messed up, and you probably need to start over. I suggest making a local commit, then running `git reset --hard`, reviewing the changes you made, and reverting them via Git.

Now you need to enable the drivers used by QEMU. You must do this in the following order: `BLK_DEV` followed by `CONFIG_VIRTIO_BLK`, because the latter depends on the former; if you run `restartconfig`, the second option would otherwise be disabled due to unmet dependencies. Here is a general list of items you should enable:

BLK_DEV
CONFIG_VIRTIO_BLK
CONFIG_PCI
CONFIG_SERIAL_8250
CONFIG_SERIAL_8250_PCI
CONFIG_SERIAL_8250_CONSOLE
CONFIG_VIRTIO_CONSOLE
CONFIG_VIRTIO
CONFIG_VIRTIO_PCI
CONFIG_VIRTIO_BALLOON
CONFIG_VIRTIO_MMIO
CONFIG_VIRTIO_NET
CONFIG_EXT3_FS

`ext3` will be needed because `ext4` includes new features that are not supported by older kernels. We will select this file system during the system installation.

3. Fixing compilation errors

Whenever I make my own changes, I implement them on a local copy; then, when pushing to GitHub, I try to incorporate those changes in an elegant and official manner. In this specific project, `ifdef`s were missing in a few places...
