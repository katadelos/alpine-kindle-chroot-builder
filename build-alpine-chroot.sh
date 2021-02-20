#!/bin/bash

CDN_REPO="http://dl-cdn.alpinelinux.org/alpine"
#REPO="http://localhost/alpine"
VERSION="v3.13"
REPO=$CDN_REPO
OUTPUT_DIR=$( pwd )/out
IMAGE_NAME="alpine"
IMAGE_SIZE=40
BUILD_DIR="/tmp/alpine-chroot"
MNT_DIR="$BUILD_DIR/mnt"
RESOURCE_DIR="$BUILD_DIR/resources"
IMAGE_DIR="$BUILD_DIR/images"
STAGING_DIR="$BUILD_DIR/staging"
BASE_FS="$IMAGE_DIR/base.ext3"
IMAGE_PATH="$IMAGE_DIR/$IMAGE_NAME.ext3"
PKG_PATH="$IMAGE_DIR/alpine-chroot.tar.gz"

mkdirif() {
  if [[ ! -d $1 ]]; then
    mkdir "$1"
  fi
}

prepare_build() {
  if [[ -f /tmp/$IMAGE_NAME.ext3 ]]; then
    rm /tmp/$IMAGE_NAME.ext3
  fi

  if [[ -d $OUTPUT_DIR ]]; then
    rm -rf "$OUTPUT_DIR"
  fi

  mkdirif "$BUILD_DIR"
  mkdirif "$MNT_DIR"
  mkdirif "$RESOURCE_DIR"
  mkdirif "$OUTPUT_DIR"
  mkdirif "$IMAGE_DIR"
  mkdirif "$STAGING_DIR"

  chown "${SUDO_USER}:${SUDO_USER}" "$OUTPUT_DIR"
}

get_apk_tools() {
  if [[ ! -f $RESOURCE_DIR/APKINDEX.tar.gz ]]; then
    curl "$REPO/latest-stable/main/armhf/APKINDEX.tar.gz" -o $RESOURCE_DIR/APKINDEX.tar.gz
  fi

  APKVER=$(zgrep -A 5 -a "P:apk-tools-static" $RESOURCE_DIR/APKINDEX.tar.gz | \
           grep "V:" | cut -d ':' -f2)

  if [[ ! -f $RESOURCE_DIR/apk-tools-static.apk ]]; then
    curl "$REPO/latest-stable/main/armv7/apk-tools-static-$APKVER.apk" -o "$RESOURCE_DIR/apk-tools-static.apk"
    tar -xzf "$RESOURCE_DIR/apk-tools-static.apk" -C $RESOURCE_DIR
  fi
}

create_fs() {
  if [[ ! -f $BASE_FS ]]; then
    dd if=/dev/zero of=$BASE_FS bs=1M count=$IMAGE_SIZE
    mkfs -t ext3 $BASE_FS
    tune2fs -i 0 -c 0 $BASE_FS
  fi
  cp $BASE_FS "$IMAGE_PATH"
}

mount_image() {
  mount -o loop -t ext3 "$IMAGE_PATH" "$MNT_DIR"
}

mount_devices() {
  mount -o bind /dev/ $MNT_DIR/dev/
  mount -o bind /dev/pts $MNT_DIR/dev/pts
  mount -o bind /proc $MNT_DIR/proc
  mount -o bind /sys $MNT_DIR/sys
}

bootstrap_alpine() {
  qemu-arm-static $RESOURCE_DIR/sbin/apk.static \
                  -X "$REPO/$VERSION/main" \
                  -U --allow-untrusted \
                  --root "$MNT_DIR" \
                  --initdb add alpine-base \
                  --no-scripts
}

prepare_chroot() {
  mkdir -p "$MNT_DIR/etc/apk"
  echo -e "$REPO/$VERSION/main/\n$REPO/$VERSION/community/\n$REPO/$VERSION/testing/" > "$MNT_DIR/etc/apk/repositories"
  cp /etc/resolv.conf $MNT_DIR/etc/resolv.conf
  cp /usr/bin/qemu-arm-static $MNT_DIR/usr/bin/
  cp provision/default.sh $MNT_DIR/tmp/default.sh
  chmod +x $MNT_DIR/tmp/default.sh
}

setup_chroot() {
  chroot $MNT_DIR qemu-arm-static /bin/sh -C /tmp/default.sh /dev/null 2>/dev/null
  echo -e "$CDN_REPO/$VERSION/main/\n$CDN_REPO/$VERSION/community/\n$CDN_REPO/$VERSION/testing/" > "$MNT_DIR/etc/apk/repositories"
}

unmount_system() {
  umount $MNT_DIR/sys
  umount $MNT_DIR/proc
  umount $MNT_DIR/dev/pts
  umount $MNT_DIR/dev
}

unmount_image() {
  if mountpoint -q $MNT_DIR; then
    umount -R $MNT_DIR
  fi
}

zero_image() {
  zerofree -v "$IMAGE_PATH"
}

package_chroot() {
  cp $IMAGE_PATH $STAGING_DIR
  cp kindle/* $STAGING_DIR
  tar -czf $PKG_PATH --xform s:"${STAGING_DIR:1}":'alpine-chroot': $STAGING_DIR
  chown "${SUDO_USER}:${SUDO_USER}" $PKG_PATH
}

retrieve_package() {
  mv "$PKG_PATH" "$OUTPUT_DIR"
}

main() {
  prepare_build
  get_apk_tools
  create_fs
  mount_image
  bootstrap_alpine
  mount_devices
  prepare_chroot
  setup_chroot
  unmount_system
  unmount_image
  zero_image
  package_chroot
  retrieve_package
}
main