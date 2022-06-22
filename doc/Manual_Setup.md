# Manual Setup

Since this is a forensic environment you need to trust it ultimately.
If you want to be completely sure of how the environment is setup, you can follow this guide to do it manually.
You can also read the code to check that it does exactly what is documented in this guide

## Preparation steps

First of all, boot computer with a CAINE 12 Live envirnoment.
Then connect an external USB drive that will be used as boot device and to store the acquired evidences.

## Manual setup steps

This guide assumes that the target device is /dev/sdb. Change the commands to use the correct device

**WARNING: these setup will wipe all information stored in the target device**, so double check that you use the correct device

  * As a security measure for those copy & paste fans, we will define a variable with the device and use that variable in the following commands. This way it's less likely that you shoot yourself in the foot forgetting to change the device in a command a wipe the wrong device.

```bash
export DEVICE=/dev/sdb
```

  * Create three partitions in the target device

```bash
sfdisk ${DEVICE} <<__EOF__
,4G,c,*
,4G
,,c
__EOF__
```

  * Format partitions and label them
    * Partition 1: FAT boot CAINE partition, labeled as CASPER
    * Partition 2: ext2 persistent overlay, labeled as casper-rw
    * Partition 3: FAT partition for storing the acquired evidences, labeled as EVIDENCE

```bash
mkfs.vfat -n CASPER ${DEVICE}1
mkfs.ext2 -L casper-rw ${DEVICE}2
mkfs.vfat -n EVIDENCE ${DEVICE}3
```

  * Mount the first partition in /mnt. This will be the boot partition where the CAINE environment will be installed

```bash
mount ${DEVICE}1 /mnt
```

  * Copy the full CAINE environment from running environment (in a live CAINE system, the  read-only base system is mounted in /cdrom, even if it is not run from a CD)


```bash
rsync -av /cdrom/ /mnt
```

  * Write the syslinux MBR to the target device.

```bash
dd if=/usr/lib/syslinux/mbr/mbr.bin of=${DEVICE}
```

  * Install syslinux in the boot partition (the first one)

```bash
syslinux -s ${DEVICE}1
```

  * Copy the isolinux configuration files to be used by syslinux

```bash
cp -av /mnt/isolinux /mnt/syslinux
```

  * Rename /mnt/syslinux/isolinux.cfg to /mnt/syslinux/syslinux.cfg (that's the name used by syslinux, the syntax is the same)

```bash
mv /mnt/syslinux/isolinux.cfg /mnt/syslinux/syslinux.cfg
```

  * Edit the **FIRST BOOT OPTION** that already exists in /mnt/syslinux/syslinux.cfg to look like this

```
label live
  menu label START CAINE LIVE
  kernel /casper/vmlinuz
  append file=/cdrom/preseed/custom.seed boot=casper boot=casper initrd=/casper/initrd.gz fsck.mode=skip quiet splash live-media=/dev/disk/by-label/CASPER nopersistent
```

  * Add the following entry to /mnt/syslinux/syslinux.cfg as the **SECOND BOOT OPTION**

```
label live-persistent
  menu label START CAINE LIVE PERSISTENT
  kernel /casper/vmlinuz
  append file=/cdrom/preseed/custom.seed boot=casper boot=casper initrd=/casper/initrd.gz fsck.mode=skip quiet splash live-media=/dev/disk/by-label/CASPER persistent
```

  * For systems booting with UEFI, edit the **FIRST BOOT OPTION** that already exists in /mnt/boot/grub/grub.cfg to look like this

```
menuentry "Start CAINE" {
    set gfxpayload=keep
    linux   /casper/vmlinuz  file=/cdrom/preseed/custom.seed boot=casper iso-scan/filename=\${iso_path} fsck.mode=skip quiet splash live-media=/dev/disk/by-label/CASPER nopersistent --
    initrd  /casper/initrd.gz
}

```

  * For systems booting with UEFI, add the following entry to /mnt/boot/grub/grub.cfg as the **SECOND BOOT OPTION**

```
menuentry "Start CAINE PERSISTENT" {
    set gfxpayload=keep
    linux   /casper/vmlinuz  file=/cdrom/preseed/custom.seed boot=casper iso-scan/filename=\${iso_path} fsck.mode=skip quiet splash live-media=/dev/disk/by-label/CASPER persistent --
    initrd  /casper/initrd.gz
}

```

  * Get the cafre command line tool to the boot partition live environment

```
cd /mnt
git clone https://github.com/kukoarmas/cafre.git
```

  * Generate sha256sum file for all files in live environment

```
find . -type f | xargs -d '\n' sha256sum | grep -v sha256sum-cafre.txt | tee /mnt/sha256sum-cafre.txt
```

  * From now on, any tampering with the live environment can be detected checking the sha256 hashes

  * OPIONAL: Generate FreeTSA signed timestamp of the sha256sum-cafre.txt file.
    * This way, any tampering with the hashes file will also be detected because it will break the digital signature
    * Also, the timestamp proves the exact moment when the environment was setup


  * Unmount the device any all set!

```
cd
umount /mnt
```
