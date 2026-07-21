# ===== boot.img 리패키징 (AOSP 공식 mkbootimg tools, ROM 빌드용) =====
MKBOOTIMG_DIR="$(pwd)/tc/mkbootimg"
if [ ! -f "$MKBOOTIMG_DIR/unpack_bootimg.py" ]; then
    echo -e "${YELLOW}mkbootimg tools not found! Cloning from AOSP...${NC}"
    rm -rf "$MKBOOTIMG_DIR"
    mkdir -p "$MKBOOTIMG_DIR"
    if ! curl -L "https://android.googlesource.com/platform/system/tools/mkbootimg/+archive/refs/heads/main.tar.gz" \
        | tar -xz -C "$MKBOOTIMG_DIR"; then
        echo -e "${RED}mkbootimg tools download failed! Aborting...${NC}"
        exit 1
    fi
fi

STOCK_BOOT="$(pwd)/firmware/boot.img"
if [ ! -f "$STOCK_BOOT" ]; then
    echo -e "${RED}stock boot.img not found at firmware/boot.img! Aborting...${NC}"
    echo -e "${RED}Place the stock boot.img for $DEVICE at that path (or set STOCK_BOOT_URL).${NC}"
    if [ -n "$STOCK_BOOT_URL" ]; then
        echo -e "${YELLOW}STOCK_BOOT_URL set, downloading...${NC}"
        mkdir -p "$(dirname "$STOCK_BOOT")"
        curl -L "$STOCK_BOOT_URL" -o "$STOCK_BOOT" || { echo -e "${RED}download failed!${NC}"; exit 1; }
    else
        exit 1
    fi
fi

BOOTWORK="$(pwd)/bootwork"
rm -rf "$BOOTWORK"
mkdir -p "$BOOTWORK/unpacked"

echo -e "${BLUE}Unpacking stock boot.img...${NC}"
python3 "$MKBOOTIMG_DIR/unpack_bootimg.py" \
    --boot_img "$STOCK_BOOT" \
    --out "$BOOTWORK/unpacked" \
    --format mkbootimg > "$BOOTWORK/repack_args.txt"

if [ ! -s "$BOOTWORK/repack_args.txt" ]; then
    echo -e "${RED}unpack_bootimg.py produced no repack args! Aborting...${NC}"
    exit 1
fi

echo -e "${BLUE}Repack args (stock):${NC}"
cat "$BOOTWORK/repack_args.txt"

REPACK_ARGS_STR=$(cat "$BOOTWORK/repack_args.txt")
eval "REPACK_ARGS=($REPACK_ARGS_STR)"

# kernel은 우리가 빌드한 Image로, dtb는 우리가 만든 kona.dtb로 교체
# (기존 인자에 --kernel/--dtb가 있으면 값만 바꾸고, 없으면 새로 추가)
HAS_KERNEL=0
HAS_DTB=0
for i in "${!REPACK_ARGS[@]}"; do
    if [ "${REPACK_ARGS[$i]}" == "--kernel" ]; then
        REPACK_ARGS[$((i+1))]="$BOOT_DIR/Image"
        HAS_KERNEL=1
    fi
    if [ "${REPACK_ARGS[$i]}" == "--dtb" ]; then
        REPACK_ARGS[$((i+1))]="$BOOT_DIR/kona.dtb"
        HAS_DTB=1
    fi
done
[ "$HAS_KERNEL" -eq 0 ] && REPACK_ARGS+=(--kernel "$BOOT_DIR/Image")
[ "$HAS_DTB" -eq 0 ] && REPACK_ARGS+=(--dtb "$BOOT_DIR/kona.dtb")

echo -e "${BLUE}Repacking boot.img with new kernel + dtb...${NC}"
python3 "$MKBOOTIMG_DIR/mkbootimg.py" "${REPACK_ARGS[@]}" \
    --output "$(pwd)/boot-$DEVICE.img"

if [ ! -f "$(pwd)/boot-$DEVICE.img" ]; then
    echo -e "${RED}mkbootimg repack failed! boot-$DEVICE.img not found.${NC}"
    exit 1
fi

cp "$BOOT_DIR/dtbo.img" "$(pwd)/dtbo-$DEVICE.img"

echo -e "${GREEN}boot-$DEVICE.img and dtbo-$DEVICE.img ready!${NC}"