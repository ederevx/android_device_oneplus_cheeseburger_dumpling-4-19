#!/system/bin/sh

# liblp writes LP_METADATA_GEOMETRY_MAGIC ("gDla") at 4096 and a backup 4096
# later. Probing it is independent of the group names inside the super.
SUPER_DEV=/dev/block/by-name/system

has_super_metadata() {
    [ -e "$SUPER_DEV" ] || return 1
    for off in 4096 8192; do
        if [ "$(dd if=$SUPER_DEV bs=1 skip=$off count=4 2>/dev/null)" = "gDla" ]; then
            return 0
        fi
    done
    return 1
}

# Dynamic Partitions
if has_super_metadata; then
    # The OTA updater adds every logical partition with
    # LP_PARTITION_ATTR_READONLY (updater_runtime_dynamic_partitions.cpp), so
    # fs_mgr_dm_linear creates all dm tables read-only and a rw mount fails
    # with EACCES. Row emission matches official TeamWin: ro rows for every
    # logical partition.
    echo >> /system/etc/recovery.fstab
    for p in system system_ext product vendor odm; do
        echo "${p} /${p} ext4 ro,barrier=1,discard wait,logical" >> /system/etc/recovery.fstab
        echo "${p} /${p} erofs ro wait,logical" >> /system/etc/recovery.fstab
    done
    echo >> /system/etc/twrp.flags
    for p in vendor; do
        echo "/super_${p} emmc /dev/block/bootdevice/by-name/${p} flags=display=\"Super_${p}\";backup=1;flashimg" >> /system/etc/twrp.flags
    done
else
    # Fix MTG Installation
    # Test -L too: the link is dangling until /dev/block/bootdevice appears.
    if [ ! -e /dev/block/mapper ] && [ ! -L /dev/block/mapper ]; then
        ln -s /dev/block/bootdevice/by-name /dev/block/mapper
    fi

    echo >> /system/etc/twrp.flags
    cat /fstab/twrp.flags.nondynpart >> /system/etc/twrp.flags
fi