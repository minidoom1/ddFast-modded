#!/usr/bin/env bash

set -euo pipefail

install_dir="/usr/local/lib/ddfast"

if [[ $euid -ne 0 ]]; then
  echo "run as root (sudo ddfast ...)"
  exit 1
fi

main_action="${1:-}"
src="${2:-}"
dst="${3:-}"

ascii_banner() {
cat <<'EOF'
    .___  .___ _____                 __                                 .___  .___         .___ 
  __| _/__| _// ____\____    _______/  |_              _____   ____   __| _/__| _/____   __| _/ 
 / __ |/ __ |\   __\\__  \  /  ___/\   __\   ______   /     \ /  _ \ / __ |/ __ |/ __ \ / __ |  
/ /_/ / /_/ | |  |   / __ \_\___ \  |  |    /_____/  |  y y  (  <_> ) /_/ / /_/ \  ___// /_/ |  
\____ \____ | |__|  (____  /____  > |__|             |__|_|  /\____/\____ \____ |\___  >____ |  
     \/    \/            \/     \/                         \/            \/    \/    \/     \/  

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
modded vers by minidoom1 (https://minidoom.one)
original by lucy (https://lucys.space)
EOF
echo
}

show_commands_list() {
cat <<'EOF'
usable commands
─────────────────────────────────────────────────────────────────────────────
core writing
  ddfast <image.iso> <target_disk>     write image to target disk

utility & info
  show_usage                           print usage help and available commands
  show_disks                           list all detected disks
  list_usb                             list usb devices only
  show_info <disk>                     show detailed disk info (uses smartctl)
  show_temp <disk>                     show temperature info (if available)
  show_partitions <disk>               list partitions on disk
  get_free_space <disk>                show free space on disk
  summary <image> <disk>               show quick summary of image and disk sizes

verification
  check_mounts <disk>                  show what partitions are mounted
  verify_image <image>                 compute sha256 hash of image file
  verify_target <disk>                 hash a small section of the target disk

disk operations
  wipe_target <disk>                   write zeros to disk (secure wipe)
  eject_target <disk>                  eject removable media if supported
  clone_disk <src_disk> <dst_disk>     clone one disk directly to another
  backup_mbr <disk>                    backup master boot record to mbr_backup.bin
  restore_mbr <disk>                   restore mbr from mbr_backup.bin
  mount_image <image>                  mount image to /mnt/ddfast_mount
  unmount_image                        unmount mounted image
  sync_all                             flush all pending disk writes

performance & testing
  show_speed_test <disk>               test write speed (1g write)
  show_read_test <disk>                test read speed (1g read)
  benchmark_disk <disk>                run hdparm benchmark if available

maintenance
  cleanup_temp                         remove temporary files and mounts
  update_ddfast                        update script from api.dd.minidoom.one
─────────────────────────────────────────────────────────────────────────────
EOF
echo
}

if [[ -z "$main_action" ]]; then
  ascii_banner
  show_commands_list
  exit 0
fi

check_root() {
  [[ $euid -eq 0 ]] || { echo "must run as root"; exit 1; }
}

show_usage() {
  ascii_banner
  show_commands_list
  exit 0
}

check_mounts() { disk="${1:-}"; [[ -z "$disk" ]] && { echo "missing disk"; exit 1; }; echo "checking mounts for $disk..."; lsblk "$disk" -o name,mountpoint; }
verify_image() { file="${1:-}"; [[ -z "$file" ]] && { echo "missing image"; exit 1; }; echo "verifying image checksum..."; sha256sum "$file"; }
verify_target() { disk="${1:-}"; [[ -z "$disk" ]] && { echo "missing disk"; exit 1; }; echo "verifying target checksum..."; dd if="$disk" bs=4m count=100 status=none | sha256sum; }
wipe_target() { disk="${1:-}"; [[ -z "$disk" ]] && { echo "missing disk"; exit 1; }; echo "secure wiping $disk..."; dd if=/dev/zero of="$disk" bs=4m status=progress || true; sync; }
eject_target() { disk="${1:-}"; [[ -z "$disk" ]] && { echo "missing disk"; exit 1; }; echo "ejecting $disk..."; eject "$disk" 2>/dev/null || echo "eject command not supported"; }
show_disks() { echo "available disks:"; lsblk -dpno name,size,model; }
show_speed_test() { disk="${1:-}"; [[ -z "$disk" ]] && { echo "missing disk"; exit 1; }; echo "testing write speed on $disk..."; dd if=/dev/zero of="$disk" bs=1g count=1 oflag=direct 2>&1 | grep -Eo '[0-9\.]+ [A-Z]B/s' || true; }
show_read_test() { disk="${1:-}"; [[ -z "$disk" ]] && { echo "missing disk"; exit 1; }; echo "testing read speed on $disk..."; dd if="$disk" of=/dev/null bs=1g count=1 iflag=direct 2>&1 | grep -Eo '[0-9\.]+ [A-Z]B/s' || true; }
show_info() { disk="${1:-}"; [[ -z "$disk" ]] && { echo "missing disk"; exit 1; }; echo "disk info for $disk:"; smartctl -i "$disk" 2>/dev/null || echo "smartctl not available"; }
show_temp() { disk="${1:-}"; [[ -z "$disk" ]] && { echo "missing disk"; exit 1; }; echo "checking drive temperature..."; smartctl -a "$disk" 2>/dev/null | grep -i temperature || echo "no temperature info"; }
sync_all() { echo "syncing all disks..."; sync; }
mount_image() { file="${1:-}"; [[ -z "$file" ]] && { echo "missing image"; exit 1; }; echo "mounting $file to /mnt/ddfast_mount..."; mkdir -p /mnt/ddfast_mount; mount -o loop "$file" /mnt/ddfast_mount || echo "failed to mount"; }
unmount_image() { echo "unmounting image..."; umount /mnt/ddfast_mount 2>/dev/null || true; }
show_partitions() { disk="${1:-}"; [[ -z "$disk" ]] && { echo "missing disk"; exit 1; }; echo "listing partitions on $disk..."; lsblk "$disk"; }
backup_mbr() { disk="${1:-}"; [[ -z "$disk" ]] && { echo "missing disk"; exit 1; }; echo "backing up mbr from $disk..."; dd if="$disk" of=mbr_backup.bin bs=512 count=1; }
restore_mbr() { disk="${1:-}"; [[ -z "$disk" ]] && { echo "missing disk"; exit 1; }; echo "restoring mbr to $disk..."; dd if=mbr_backup.bin of="$disk" bs=512 count=1; }
clone_disk() { src_disk="${1:-}"; dst_disk="${2:-}"; [[ -z "$src_disk" || -z "$dst_disk" ]] && { echo "usage: clone_disk <src_disk> <dst_disk>"; exit 1; }; echo "cloning $src_disk → $dst_disk..."; dd if="$src_disk" of="$dst_disk" bs=4m status=progress; }
list_usb() { echo "listing usb devices..."; lsblk -S | grep usb || echo "no usb devices found"; }
update_ddfast() { echo "updating ddfast..."; curl -fsSL https://minidoom.one/ddfast-latest.sh -o /usr/local/bin/ddfast && chmod +x /usr/local/bin/ddfast; }
cleanup_temp() { echo "cleaning up temp files..."; rm -rf /mnt/ddfast_mount mbr_backup.bin 2>/dev/null || true; }
get_free_space() { disk="${1:-}"; [[ -z "$disk" ]] && { echo "missing disk"; exit 1; }; df -h "$disk" 2>/dev/null || echo "cannot get free space info"; }
benchmark_disk() { disk="${1:-}"; [[ -z "$disk" ]] && { echo "missing disk"; exit 1; }; hdparm -tT "$disk" 2>/dev/null || echo "hdparm not found"; }
summary() { src="${1:-}"; dst="${2:-}"; [[ -z "$src" || -z "$dst" ]] && { echo "missing args"; exit 1; }; src_size=$(stat -c%s "$src"); src_h=$(numfmt --to=iec-i --suffix=b "$src_size" 2>/dev/null || echo "$src_size bytes"); dst_size=$(blockdev --getsize64 "$dst" 2>/dev/null || echo 0); dst_h=$(numfmt --to=iec-i --suffix=b "$dst_size" 2>/dev/null || echo "$dst_size bytes"); echo "summary:"; echo "source: $src"; echo "target: $dst"; echo "source size: $src_h"; echo "target size: $dst_h"; }

if [[ "$main_action" =~ ^(check_mounts|verify_image|verify_target|wipe_target|eject_target|show_disks|show_usage|show_speed_test|show_read_test|show_info|show_temp|sync_all|mount_image|unmount_image|show_partitions|backup_mbr|restore_mbr|clone_disk|list_usb|update_ddfast|cleanup_temp|get_free_space|benchmark_disk|summary)$ ]]; then
  shift
  "$main_action" "$@"
  exit 0
fi

[[ "$dst" != /dev/* ]] && dst="/dev/$dst"
[[ -f "$main_action" ]] && src="$main_action"

[[ -f "$src" ]] || { echo "file not found: $src"; exit 1; }
[[ -b "$dst" ]] || { echo "target not found or invalid: $dst"; exit 1; }

src_size=$(stat -c%s "$src")
src_h=$(numfmt --to=iec-i --suffix=b "$src_size" 2>/dev/null || echo "$src_size bytes")
dst_size=$(blockdev --getsize64 "$dst" 2>/dev/null || echo 0)
dst_h=$(numfmt --to=iec-i --suffix=b "$dst_size" 2>/dev/null || echo "$dst_size bytes")

echo "welcome to ddfast!"
echo "source: $src ($src_h)"
echo "target: $dst ($dst_h)"
echo

read -r -p "this will erase all data on $dst — continue? (type yes): " conf
[[ "$conf" == "yes" ]] || { echo "aborted."; exit 1; }

for p in $(lsblk -ln -o name "$dst" | grep -v "$(basename "$dst")"); do
  umount "/dev/$p" 2>/dev/null || true
done

sync

if command -v pv >/dev/null 2>&1; then
  echo "using pv for progress..."
  pv -tpreb "$src" | dd of="$dst" bs=4m iflag=fullblock conv=fsync oflag=direct status=none
else
  echo "using dd status=progress..."
  dd if="$src" of="$dst" bs=4m iflag=fullblock conv=fsync oflag=direct status=progress
fi

sync
echo
echo "done! wrote $src → $dst"
echo
echo "────────────────────────────────────────────"
echo " thank you for using ddfast"
echo " modded version by minidoom1"
echo " https://minidoom.one/"
echo "────────────────────────────────────────────"
echo " og vers by lucysgutz"
echo " https://lucys.space/"
echo "────────────────────────────────────────────"
