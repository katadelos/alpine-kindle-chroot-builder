#!/bin/sh
MNT_PATH="/tmp/alpine"

create_mountpoint() {
  if [ ! -d $MNT_PATH ]; then
    mkdir $MNT_PATH
  fi
}
mount_fs() {
  mount -o loop /mnt/us/alpine-chroot/alpine.ext3 $MNT_PATH
}

mount_kindle_system() {
  mount -o bind /proc $MNT_PATH/proc
  mount -o bind /sys $MNT_PATH/sys
  mount -o bind /dev $MNT_PATH/dev
  mount -o bind /dev/pts $MNT_PATH/dev/pts
}

setup_resolv() {
  rm $MNT_PATH/etc/resolv.conf
  cp /etc/resolv.conf $MNT_PATH/etc/resolv.conf
}

unmount_kindle_system() {
  umount $MNT_PATH/dev/pts/ 
  umount $MNT_PATH/dev 
  umount $MNT_PATH/sys 
  umount $MNT_PATH/proc
}

unmount_alpine_mount() {
  umount $MNT_PATH
}

_mount() {
  create_mountpoint
  mount_fs
  mount_kindle_system
  setup_resolv
}

_unmount() {
  unmount_kindle_system
  unmount_alpine_mount
}

case $1 in
  start)
    _mount
    ;;
  stop)
    _unmount
    ;;
  enter)
    chroot $MNT_PATH /bin/ash
    ;;
  *)
    exit 1
    ;;
esac