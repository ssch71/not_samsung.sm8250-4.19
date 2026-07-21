# ===== boot.img 리패키징 (AOSP 공식 mkbootimg tools) =====
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
    if [ ! -f "$MKBOOTIMG_DIR/unpack_bootimg.py" ]; then
        echo -e "${RED}unpack_bootimg.py missing after extraction! Aborting...${NC}"
        exit 1
    fi
fi

STOCK_BOOT="$(pwd)/firmware/boot.img"
if [ ! -f "$STOCK_BOOT" ]; then
    if [ -n "$STOCK_BOOT_URL" ]; then
        echo -e "${YELLOW}Downloading stock boot.img from STOCK_BOOT_URL...${NC}"
        mkdir -p "$(dirname "$STOCK_BOOT")"
        if ! curl -L "$STOCK_BOOT_URL" -o "$STOCK_BOOT"; then
            echo -e "${RED}stock boot.img download failed! Aborting...${NC}"
            exit 1
        fi
    else
        echo -e "${RED}stock boot.img not found at firmware/boot.img and STOCK_BOOT_URL is not set! Aborting...${NC}"
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

echo -e "${BLUE}Repack args:${NC}"
cat "$BOOTWORK/repack_args.txt"

REPACK_ARGS_STR=$(cat "$BOOTWORK/repack_args.txt")
eval "REPACK_ARGS=($REPACK_ARGS_STR)"

# --kernel 값을 우리가 빌드한 Image로 교체
for i in "${!REPACK_ARGS[@]}"; do
    if [ "${REPACK_ARGS[$i]}" == "--kernel" ]; then
        REPACK_ARGS[$((i+1))]="$BOOT_DIR/Image"
    fi
done

echo -e "${BLUE}Repacking boot.img with new kernel...${NC}"
python3 "$MKBOOTIMG_DIR/mkbootimg.py" "${REPACK_ARGS[@]}" \
    --output "$(pwd)/boot-$DEVICE.img"

if [ ! -f "$(pwd)/boot-$DEVICE.img" ]; then
    echo -e "${RED}mkbootimg repack failed! boot-$DEVICE.img not found.${NC}"
    exit 1
fi

cp "$BOOT_DIR/dtbo.img" "$(pwd)/dtbo-$DEVICE.img"

echo -e "${GREEN}boot-$DEVICE.img and dtbo-$DEVICE.img ready!${NC}"