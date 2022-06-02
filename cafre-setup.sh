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

## TODO: Add a safety confirmation

echo "Setting CAFRE environment in device: $DEVICE"

echo "Zeroing beginning of disk $DEVICE"
dd if=/dev/zero of=$DEVICE bs=1M count=10

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

echo "Creating grub EFI config"
cat <<__EOF__ > /mnt/media/kuko/CASPER/boot/grub/grub.cfg
if loadfont /boot/grub/font.pf2 ; then
	set gfxmode=auto
	insmod efi_gop
	insmod efi_uga
	insmod gfxterm
	terminal_output gfxterm
fi

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray
set theme=/boot/grub/theme.cfg

menuentry "Start CAINE" {
	set gfxpayload=keep
	linux	/casper/vmlinuz  file=/cdrom/preseed/custom.seed boot=casper iso-scan/filename=\${iso_path} fsck.mode=skip quiet splashi nopersistent --
	initrd	/casper/initrd.gz
}

menuentry "Start CAINE PERSISTENT" {
	set gfxpayload=keep
	linux	/casper/vmlinuz  file=/cdrom/preseed/custom.seed boot=casper iso-scan/filename=\${iso_path} fsck.mode=skip quiet splash persistent live-media=/dev/disk/by-label/CASPER --
	initrd	/casper/initrd.gz
}

menuentry "Start CAINE (Hard compatibility mode / ACPI off)" {
	linux	/casper/vmlinuz  file=/cdrom/preseed/custom.seed boot=casper xforcevesa noveau.modeset=0 iso-scan/filename=\${iso_path} fsck.mode=skip noapic noacpi nosplash acpi=off irqpoll --
	initrd	/casper/initrd.gz
}
menuentry "Start CAINE (Compatibility VESA mode)" {
	linux	/casper/vmlinuz  file=/cdrom/preseed/custom.seed boot=casper xforcevesa b43.blacklist=yes iso-scan/filename=\${iso_path} fsck.mode=skip noapic noacpi nosplash irqpoll --
	initrd	/casper/initrd.gz
}
menuentry "Start CAINE TO RAM" {
	linux	/casper/vmlinuz  file=/cdrom/preseed/custom.seed boot=casper toram nomdmonddf nomdmonisw iso-scan/filename=\${iso_path} ramdisk_size=2048576 root=/dev/ram rw fsck.mode=skip noapic noacpi nosplash irqpoll --
	initrd	/casper/initrd.gz
}
menuentry "Boot Live in debug mode" {
  set gfxpayload=keep
  linux /casper/vmlinuz boot=casper iso-scan/filename=\${iso_path} --
  initrd /casper/initrd.gz
}
menuentry "Check the integrity of the medium" {
	linux	/casper/vmlinuz  boot=casper integrity-check iso-scan/filename=\${iso_path} quiet splash --
	initrd	/casper/initrd.gz
}
__EOF__

echo "Unmounting CAINE partition"
umount /mnt

echo "*********************"
echo "CAFRE SETUP COMPLETED"
echo "*********************"
