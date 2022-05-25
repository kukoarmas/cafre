#!/bin/bash
# Setup a CAFRE environment on the specified device

## Config variables

CAINE_SIZE="4G"
OVERLAY_SIZE="4G"

## Code

DEVICE="$1"

if [ "x$DEVICE" == "x" ]; then
    echo "Please, specify the device. ALL INFORMATION ON DEVICE WILL BE DELETED"
    exit
fi

echo "Setting CAFRE environment in device: $DEVICE"

echo "Setting partitions..."
sfdisk -f -W always ${DEVICE} <<__EOF__
,${CAINE_SIZE},c,*
,${OVERLAY_SIZE}
,,c
__EOF__


echo "Creating filesystems"
mkfs.vfat -n CASPER ${DEVICE}1
mkfs.ext2 -L casper-rw ${DEVICE}2
mkfs.vfat -n EVIDENCE ${DEVICE}3

echo "Mounting CAINE partition"
mount /dev/disk/by-label/CASPER /mnt

echo "Copying CAINE"
rsync -av /cdrom/ /mnt

echo "Writing MBR"
dd if=/usr/lib/syslinux/mbr/mbr.bin of=${DEVICE}

echo "Installing syslinux"
syslinux -s /dev/disk/by-label/CASPER
cp -av /mnt/isolinux /mnt/syslinux
rm /mnt/syslinux/isolinux.cfg
cat <<__EOF__ > /mnt/syslinux/syslinux.cfg
default vesamenu.c32
prompt 0
timeout 100

menu title CAINE
menu background splash.png
menu color title 1;37;44 #c0ffffff #00000000 std
menu tabmsg Press TAB key to edit

label live
  menu label START CAINE LIVE
  kernel /casper/vmlinuz
  append file=/cdrom/preseed/custom.seed boot=casper boot=casper initrd=/casper/initrd.gz fsck.mode=skip quiet splash nopersistent
  
label live-persistent
  menu label START CAINE LIVE PERSISTENT
  kernel /casper/vmlinuz
  append file=/cdrom/preseed/custom.seed boot=casper boot=casper initrd=/casper/initrd.gz fsck.mode=skip persistent live-media=/dev/disk/by-label/CASPER

label safe graphics mode acpi off
  menu label Boot Live in safe graphics mode
  kernel /casper/vmlinuz
  append file=/cdrom/preseed/custom.seed boot=casper boot=casper initrd=/casper/initrd.gz xforcevesa noveau.modeset=0 fsck.mode=skip noapic noacpi nosplash acpi=off irqpoll

label xforcevesa
  menu label Start in vesa compatibility mode
  kernel /casper/vmlinuz
  append file=/cdrom/preseed/custom.seed boot=casper boot=casper initrd=/casper/initrd.gz xforcevesa b43.blacklist=yes fsck.mode=skip noapic noacpi nosplash irqpoll
 
 label ToRAM
  menu label Boot Live in RAM
  kernel /casper/vmlinuz
  append file=/cdrom/preseed/custom.seed boot=casper boot=casper initrd=/casper/initrd.gz toram fsck.mode=skip quiet splash nomdmonddf nomdmonisw

label debug
  menu label Boot Live in debug mode
  kernel /casper/vmlinuz
  append file=/cdrom/preseed/custom.seed boot=casper boot=casper initrd=/casper/initrd.gz

label memtest
  menu label Memory test
  kernel /install/memtest
  append -
__EOF__

echo "Unmounting CAINE partition"
umount /mnt

echo "*********************"
echo "CAFRE SETUP COMPLETED"
echo "*********************"
