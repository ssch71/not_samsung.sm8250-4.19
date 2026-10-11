#!/bin/bash
# Pack boot.img (header v2) and dtbo.img from an already built out/<device>.
# Run this AFTER ./build_sm8250.sh <device> <toolchain-dir>.
#
# Usage: ./build_boot.sh <device>
# Optional env: BUILD_DATE, MKBOOTIMG, BOOT_CMDLINE, BOOT_OS_VERSION
set -euo pipefail

DEVICE="${1:?usage: $0 <device>}"
KERNEL_DIR="$(pwd)"
OUT_DIR="$KERNEL_DIR/out/$DEVICE"
BOOT_OUT="$OUT_DIR/arch/arm64/boot"
DTB_DIR="$BOOT_OUT/dts/vendor/qcom"
BUILD_DATE="${BUILD_DATE:-$(date +%Y-%m-%d_%H-%M)}"

# ===== Boot image parameters (SM8250 / kona, header v2) =====
CMDLINE="${BOOT_CMDLINE:-console=null androidboot.hardware=qcom androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 androidboot.usbcontroller=a600000.dwc3 swiotlb=2048 printk.devkmsg=on firmware_class.path=/vendor/firmware_mnt/image loop.max_part=7}"
OS_VERSION="${BOOT_OS_VERSION:-16.0.0}"
BASE="0x00000000"
KERNEL_OFFSET="0x00008000"
RAMDISK_OFFSET="0x02000000"
SECOND_OFFSET="0x00000000"
DTB_OFFSET="0x01f00000"
TAGS_OFFSET="0x01e00000"
BOARD="SRPUB26A012"
PAGESIZE="4096"

BOOT_IMG="$KERNEL_DIR/not-boot-${DEVICE}-${BUILD_DATE}.img"
DTBO_IMG="$KERNEL_DIR/not-dtbo-${DEVICE}-${BUILD_DATE}.img"

die() { echo "ERROR: $*" >&2; exit 1; }

# ===== Inputs from the kernel build =====
KERNEL_IMAGE="$BOOT_OUT/Image"
[ -f "$KERNEL_IMAGE" ] || die "$KERNEL_IMAGE not found. Run build_sm8250.sh $DEVICE first."

[ -f "$OUT_DIR/dtbo.img" ] || die "$OUT_DIR/dtbo.img not found."

# Same three SoC dtbs as the UN1CA reference, in this order.
DTB_FILE="$OUT_DIR/boot-dtb"
: > "$DTB_FILE"
for n in kona kona-v2 kona-v2.1; do
    [ -f "$DTB_DIR/$n.dtb" ] || die "$DTB_DIR/$n.dtb not found."
    cat "$DTB_DIR/$n.dtb" >> "$DTB_FILE"
done

# Per-device ramdisk wins over the shared one.
if [ -f "$KERNEL_DIR/boot/ramdisk-$DEVICE" ]; then
    RAMDISK="$KERNEL_DIR/boot/ramdisk-$DEVICE"
elif [ -f "$KERNEL_DIR/boot/ramdisk" ]; then
    RAMDISK="$KERNEL_DIR/boot/ramdisk"
else
    die "boot/ramdisk not found."
fi

# ===== mkbootimg =====
if [ -z "${MKBOOTIMG:-}" ]; then
    if [ -f "$KERNEL_DIR/mkbootimg/mkbootimg.py" ]; then
        MKBOOTIMG="$KERNEL_DIR/mkbootimg/mkbootimg.py"
    else
        MKB_DIR="$KERNEL_DIR/.mkbootimg"
        if [ ! -f "$MKB_DIR/mkbootimg.py" ]; then
            echo "Fetching AOSP mkbootimg..."
            for i in 1 2 3; do
                rm -rf "$MKB_DIR"
                git clone --depth 1 https://android.googlesource.com/platform/system/tools/mkbootimg "$MKB_DIR" && break
                [ "$i" = 3 ] && die "could not fetch mkbootimg"
                sleep 5
            done
        fi
        MKBOOTIMG="$MKB_DIR/mkbootimg.py"
    fi
fi

# ===== Build boot.img =====
echo "Building $(basename "$BOOT_IMG") (ramdisk: $(basename "$RAMDISK"))"
python3 "$MKBOOTIMG" \
    --header_version 2 \
    --kernel "$KERNEL_IMAGE" \
    --ramdisk "$RAMDISK" \
    --dtb "$DTB_FILE" \
    --cmdline "$CMDLINE" \
    --base "$BASE" \
    --kernel_offset "$KERNEL_OFFSET" \
    --ramdisk_offset "$RAMDISK_OFFSET" \
    --second_offset "$SECOND_OFFSET" \
    --dtb_offset "$DTB_OFFSET" \
    --tags_offset "$TAGS_OFFSET" \
    --board "$BOARD" \
    --pagesize "$PAGESIZE" \
    --os_version "$OS_VERSION" \
    --os_patch_level "$(date +%Y-%m)" \
    --output "$BOOT_IMG"

cp "$OUT_DIR/dtbo.img" "$DTBO_IMG"

# ===== Sanity check =====
UNPACK="$(dirname "$MKBOOTIMG")/unpack_bootimg.py"
if [ -f "$UNPACK" ]; then
    python3 "$UNPACK" --boot_img "$BOOT_IMG" --out "$OUT_DIR/boot-unpacked" --format=info || true
fi

ls -l "$BOOT_IMG" "$DTBO_IMG"
sha256sum "$BOOT_IMG" "$DTBO_IMG"
echo "Done: $(basename "$BOOT_IMG"), $(basename "$DTBO_IMG")"
