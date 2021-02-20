#!/bin/ash

busybox install -s
rm /etc/hostname
echo kindle > /etc/hostname
mkdir /run/dbus
apk update
apk add bash sudo 
adduser alpine -D
echo -e \"alpine\nalpine\" | passwd alpine -d "alpine"
echo '%sudo ALL=(ALL) ALL' >> /etc/sudoers
addgroup sudo
addgroup alpine sudo