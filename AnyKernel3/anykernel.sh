# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
properties() { '
kernel.string=Kernel for SAMSUNG SM8250 Series by skye // tachyon mianhamza @ xda-developers
do.devicecheck=0
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=x1q
device.name2=y2q
device.name3=z3q
device.name4=c1q
device.name5=c2q
supported.versions=13 - 16
supported.patchlevels=
'; }

## Shell variables
block=/dev/block/platform/soc/1d84000.ufshc/by-name/boot;
is_slot_device=$(getprop ro.boot.slot_suffix | grep -qE '^[ab]$' && echo 1 || echo 0);
ramdisk_compression=auto;

## Import core functions
. tools/ak3-core.sh;

## Permissions
set_perm_recursive 0 0 755 644 $ramdisk/*;
set_perm_recursive 0 0 750 750 $ramdisk/init* $ramdisk/sbin;

## Boot image handling
ui_print "----------------------------------------"
ui_print " • Extracting boot image... • "
ui_print "----------------------------------------"
dump_boot;

## DTB handling
case "$ZIPFILE" in
   *-eff*)
    ui_print " • Using efficient CPU frequency table • "
    mv $home/kona-eff.dtb $home/dtb
    ;;
   *)
    ui_print " • Using custom CPU frequency table • "
    mv $home/kona.dtb $home/dtb
    ;;
esac

## ROM detection
oneui=$(file_getprop /system/build.prop ro.build.version.oneui);
cos=$(file_getprop /system/build.prop ro.product.system.brand);
gos=$(file_getprop /system/build.prop ro.build.host);

if [ -n "$oneui" ]; then
    case "$oneui" in
        60000*)
            ui_print " • OneUI 6.x ROM Detected • "
            ;;
        70000*)
            ui_print " • OneUI 7.x ROM Detected • "
            ;;
        80000*)
            ui_print " • OneUI 8.x ROM Detected • "
            ;;
        *)
            ui_print " • OneUI ROM Detected (version: $oneui) • "
            ;;
    esac
    ui_print " • Patching Fingerprint Sensor... • "
    patch_cmdline "android.is_aosp" "android.is_aosp=0"
    patch_cmdline "android.is_uos" "android.is_uos=0"

elif [ "$gos" = "tachyon" ]; then
    ui_print " • GrapheneOS detected • "
    patch_cmdline "androidboot.selinux" "androidboot.selinux=permissive"
    patch_cmdline "android.is_aosp" "android.is_aosp=0"
    patch_cmdline "android.is_uos" "android.is_uos=0"
    ui_print " • Setting verified boot state to green • "
    patch_cmdline "ro.boot.verifiedbootstate=orange" "ro.boot.verifiedbootstate=green"
    patch_cmdline "androidboot.verifiedbootstate=orange" "androidboot.verifiedbootstate=green"

elif [ "$cos" = "oplus" ]; then
    ui_print " • Oplus ROM detected • "
    patch_cmdline "androidboot.selinux" "androidboot.selinux=permissive"
    patch_cmdline "android.is_aosp" "android.is_aosp=1"
    patch_cmdline "android.is_uos" "android.is_uos=0"

else
    ui_print " • AOSP ROM detected • "
    ui_print " • Spoofing verified boot state to green • "
    patch_cmdline "ro.boot.verifiedbootstate=orange" "ro.boot.verifiedbootstate=green"
    ui_print " • Patching Fingerprint Sensor... • "
    patch_cmdline "android.is_aosp" "android.is_aosp=1"
    patch_cmdline "android.is_uos" "android.is_uos=0"
fi

## vbmeta/dtbo patching
if [ -f "$home/vbmeta.img" ]; then
    ui_print " • Patching vbmeta... • "
    dd if=$home/vbmeta.img of=/dev/block/platform/soc/1d84000.ufshc/by-name/vbmeta
fi

if [ -f "$home/dtbo.img" ]; then
    ui_print " • Patching dtbo... • "
    dd if=$home/dtbo.img of=/dev/block/platform/soc/1d84000.ufshc/by-name/dtbo
fi

## Finalize
ui_print " • Flashing boot image... • "
flash_boot;

ui_print "----------------------------------------"
ui_print " • Kernel installation complete • "
ui_print "----------------------------------------"
