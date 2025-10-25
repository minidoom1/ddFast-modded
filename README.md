#  ddFast modded

**ddFast modded** — DD but faster & user-friendly.  
Cleanest & fastest disk flashing tool!

---

###  Install

It's easier than ever:

```bash
sudo curl -fsSL https://raw.githubusercontent.com/minidoom1/ddFast-modded/main/ddfast -o /usr/local/bin/ddfast
sudo chmod +x /usr/local/bin/ddfast
```


#  tools

here is some cool and rad commands you can use:

```bash
core writing commands
──────────────────────
ddfast <image.iso> <target_disk>     write image to target disk

utility & info commands
──────────────────────
show_usage                          print usage help and available commands
show_disks                          list all detected disks
list_usb                            list usb devices only
show_info <disk>                    show detailed disk info (uses smartctl)
show_temp <disk>                    show temperature info (if available)
show_partitions <disk>              list partitions on disk
get_free_space <disk>               show free space on disk
summary <image> <disk>              show quick summary of image and disk sizes

verification commands
──────────────────────
check_mounts <disk>                 show what partitions are mounted on the target
verify_image <image>                compute sha256 hash of image file
verify_target <disk>                hash a small section of the target disk for sanity check

disk operations
──────────────────────
wipe_target <disk>                  write zeros to disk (secure wipe)
eject_target <disk>                 eject removable media if supported
clone_disk <src_disk> <dst_disk>    clone one disk directly to another
backup_mbr <disk>                   backup the master boot record to mbr_backup.bin
restore_mbr <disk>                  restore mbr from mbr_backup.bin
mount_image <image>                 mount image to /mnt/ddfast_mount
unmount_image                       unmount mounted image
sync_all                            flush all pending disk writes

performance & testing
──────────────────────
show_speed_test <disk>              test write speed (1g write)
show_read_test <disk>               test read speed (1g read)
benchmark_disk <disk>               run hdparm benchmark if available

maintenance
──────────────────────
cleanup_temp                        remove temporary files and mount dirs
update_ddfast                       update script to latest version from dd.minidoom.one
