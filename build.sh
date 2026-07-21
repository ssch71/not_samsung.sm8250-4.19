# ===== boot.img 리패키징 (magiskboot) =====
MAGISKBOOT="$(pwd)/tc/magiskboot"
if [ ! -x "$MAGISKBOOT" ]; then
    echo -e "${YELLOW}magiskboot not found! Downloading...${NC}"
    mkdir -p "$(dirname "$MAGISKBOOT")"
    if ! curl -L -o "$MAGISKBOOT" "https://github.com/HuskyDG/magiskboot_ci/releases/latest/download/magiskboot"; then
        echo -e "${RED}magiskboot download failed! Aborting...${NC}"
        exit 1
    fi
    chmod +x "$MAGISKBOOT"
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
mkdir -p "$BOOTWORK"
cp "$STOCK_BOOT" "$BOOTWORK/stock_boot.img"

pushd "$BOOTWORK" >/dev/null
"$MAGISKBOOT" unpack stock_boot.img
if [ $? -ne 0 ]; then
    echo -e "${RED}magiskboot unpack failed!${NC}"
    exit 1
fi

cp "$BOOT_DIR/Image" kernel

"$MAGISKBOOT" repack stock_boot.img
if [ ! -f new-boot.img ]; then
    echo -e "${RED}magiskboot repack failed! new-boot.img not found.${NC}"
    exit 1
fi
mv new-boot.img "boot-$DEVICE.img"
popd >/dev/null

cp "$BOOTWORK/boot-$DEVICE.img" "$(pwd)/boot-$DEVICE.img"
cp "$BOOT_DIR/dtbo.img" "$(pwd)/dtbo-$DEVICE.img"

echo -e "${GREEN}boot-$DEVICE.img and dtbo-$DEVICE.img ready!${NC}"