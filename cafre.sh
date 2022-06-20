#!/bin/bash
# Setup a CAFRE environment on the specified device

## Config variables

CAINE_SIZE="4G"
OVERLAY_SIZE="4G"

VERSION=0.1.1

## Code
DEVICE="$1"

## --------- Helper functions

# Shows a message only in debug mode
function debug {
    [ $debug = 1 ] && echo $*
    return 0
}

# Run command or just show it if do_nothing is set
function run_cmd {
    if [ $do_nothing = 1 ]; then
        echo $*
    else
        debug "Running $*"
        $*
    fi
}

# Show usage message
function usage {
  cat <<__EOF__
$0 [-h] | command options

Uso:
  -h              : Shows this help message
  -d              : Debug. Show debug messages
  -n              : Do nothing. Just show what should be done

Valid commands:

   - info: Show basic info about CAFRE environment
       - options: NONE
       - examples: 
           cafre info
   - setup: Setup the given device as a CAFRE boot device
       - options: DEVICE The device we want to use. ALL INFORMATION IN THIS DEVICE WILL BE DELETED
       - examples: 
           cafre setup /dev/sdb
   - hash_dir: Generate sha256 hashes for all files in the given dir (recursively)
       - options: DIRECTORY The directory containing the files we want to create hashes for
       - examples: 
           cafre hashdir /evidences
   - timestamp: Generate an external signature and timestamp for the given file (with FreeTSA)
       - options: FILE The file we want to timestamp
       - examples: 
           cafre timestamp sha256sum.txt
   - verify_timestamp: Verifies a given timestamp to make sure it's correct
       - options: FILE The file we want to check the timestamp for
       - examples: 
           cafre verify_timestamp sha256sum.txt
   - wipe_rw: Wipe (empty) the read/write overlay partition
       - options: NONE
       - examples: 
           cafre wiper_rw
   - protect_rw: Protect the read/write overlay partition (changing it's label to casper-rw-protec)
       - options: NONE
       - examples: 
           cafre protect_rw
   - unprotect_rw: Unprotect the read/write overlay partition (changing it's label back to casper-rw)
       - options: NONE
       - examples: 
           cafre unprotect_rw

__EOF__
}

#########################################
######        INFO COMMAND         ######
#########################################

#
# Show infor about CAFRE environment
function info {

    source /etc/lsb-release
    echo "CAFRE Forensic environment version ${VERSION}"
    echo "Running on ${DISTRIB_DESCRIPTION}"
    echo
    if [ -L /dev/disk/by-label/casper-rw-protec ]; then
        echo "Persistence partition is PROTECTED"
    elif [ -L /dev/disk/by-label/casper-rw ]; then
        echo "Persistence partition is UNPROTECTED"
    else
        echo "WARNING: No persistence partition found. Are you running me in plain CAINE??"
    fi
    echo
    if grep -q " persistent " /proc/cmdline; then
        echo "RUNNING IN PERSISTENT MODE"
    else
        echo "Running in NON PERSISTENT mode"
    fi

} 

#########################################
######       SETUP COMMAND         ######
#########################################

# Setup a CAFRE environment on given device
#
# TODO:
#   - Check we are running in CAINE 12 (for auditability)
#   - Timestamp the previous file?
#   - Publish the sha256sum.txt and timestamps in the repo
function setup {
    
    DEVICE=$1

    if [ "x$DEVICE" == "x" ]; then
        echo "Please, specify the device. ALL INFORMATION ON DEVICE WILL BE DELETED"
        exit
    fi
    
    ## Safety confirmation
    proceed="n"
    echo "THIS ACTION WILL DESTROY ALL INFORMATION ON DEVICE ${DEVICE}"
    read -r -p "Are you sure you want to proceed?[y/N]: " proceed
    if [ "$proceed" != "y" ]; then
        echo "SETUP ABORTED"
        exit
    fi

    ## Check that we are in the cafre directory
    if [ ! -f cafre.sh ]; then
        echo "ERROR: No cafre.sh file found in current directory"
        echo "setup command should be run inside the cafre directory"
        exit
    fi

    echo "Setting CAFRE environment in device: $DEVICE"
    
    echo "Zeroing beginning of disk $DEVICE"
    run_cmd "dd if=/dev/zero of=$DEVICE bs=1M count=10"
    
    echo "Setting partitions..."
    run_cmd "sfdisk -f -W always ${DEVICE}" <<__EOF__
,${CAINE_SIZE},c,*
,${OVERLAY_SIZE}
,,c
__EOF__


    echo "Creating filesystems"
    run_cmd "mkfs.vfat -n CASPER ${DEVICE}1"
    run_cmd "mkfs.ext2 -L casper-rw ${DEVICE}2"
    run_cmd "mkfs.vfat -n EVIDENCE ${DEVICE}3"

    # FIXME: Make sure this command succeeds before proceeding
    echo "Mounting CAINE partition"
    run_cmd "mount /dev/disk/by-label/CASPER /mnt"
    # Check mount worked
    if ! mount | grep -q /mnt; then
        echo "ERROR: mount of the CASPER partition in /mnt failed"
        exit
    fi

    echo "Copying CAINE"
    run_cmd "rsync -av /cdrom/ /mnt"

    echo "Writing MBR"
    run_cmd "dd if=/usr/lib/syslinux/mbr/mbr.bin of=${DEVICE}"

    # FIXME: Check that we are in the correct directory (assume we are in the directory containing the running cafre.sh script)
    echo "Copying cafre script to CAINE partition"
    run_cmd "mkdir /mnt/cafre"
    run_cmd "cp cafre.sh /mnt/cafre"

    echo "Installing syslinux"
    run_cmd "syslinux -s /dev/disk/by-label/CASPER"
    run_cmd "cp -av /mnt/isolinux /mnt/syslinux"
    run_cmd "rm /mnt/syslinux/isolinux.cfg"
    run_cmd cat <<__EOF__ > /mnt/syslinux/syslinux.cfg
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
    run_cmd cat <<__EOF__ > /mnt/boot/grub/grub.cfg
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

    echo "Saving sha256 hashes of all files to sha256sum-cafre.txt"
    run_cmd "hash_dir /mnt" | grep -v sha256sum-cafre.txt | tee /mnt/sha256sum-cafre.txt

    echo "Unmounting CAINE partition"
    run_cmd "umount /mnt"

    echo "*********************"
    echo "CAFRE SETUP COMPLETED"
    echo "*********************"
}

#########################################
#### PERSISTENCE PARTITION HANDLING #####
#########################################
#
# Protect the persistent partition (changing the label)
#
function protect_rw {

    if [ -L /dev/disk/by-label/casper-rw ]; then
        blockdev --setrw /dev/disk/by-label/casper-rw
        e2label /dev/disk/by-label/casper-rw casper-rw-protec
        blockdev --setro /dev/disk/by-label/casper-rw
    else
        echo "No casper-rw partition to protect"
        exit 1
    fi
}

#
# Unrotect the persistent partition (changing the label)
#
function unprotect_rw {

    if [ -L /dev/disk/by-label/casper-rw-protec ]; then
        blockdev --setrw /dev/disk/by-label/casper-rw
        e2label /dev/disk/by-label/casper-rw-protec casper-rw
        blockdev --setro /dev/disk/by-label/casper-rw
    else
        echo "No casper-rw-protected partition to unprotect"
        exit 1
    fi
}

#
# Wipe the persistent partition
#
function wipe_rw {

    ## Safety confirmation
    proceed="n"
    echo "THIS ACTION WILL DESTROY ALL INFORMATION ON PERSISTENCE PARTITION"
    read -r -p "Are you sure you want to proceed?[y/N]: " proceed
    if [ "$proceed" != "y" ]; then
        echo "WIPE ABORTED"
        exit
    fi
 
    if [ -L /dev/disk/by-label/casper-rw ]; then
        run_cmd "mkfs.ext2 -L casper-rw /dev/disk/by-label/casper-rw"
    else
        echo "No casper-rw partition to wipe"
        exit 1
    fi
}

#########################################
###### HASH AND TIMESTAMP COMMANDS ######
#########################################

#
# Generate sha256 hashes for all files in a given directory
#
function hash_dir {
    DIR=$1

    debug "hash_dir: $DIR"
    if [ -d $DIR ]; then
        pushd $DIR >/dev/null
        find . -type f | xargs -d '\n' sha256sum
        popd >/dev/null
    else
        echo "ERROR: Invalid directory $DIR"
        exit 1
    fi
}

#
# Get a FreeTSA timestamp for a file
#
function timestamp {
    FILE=$1

    debug "timestamp: $FILE"
    if [ ! -f $FILE ]; then
        echo "ERROR: Invalid file $FILE"
        exit 1
    fi

    # FIXME: Check if we have connection to the internet
    echo "Generating timestamp with FreeTSA for file: ${FILE}"
    openssl ts -query -data ${FILE} -no_nonce -sha512 -cert -out ${FILE}.tsq
    curl -s -H 'Content-Type: application/timestamp-query' --data-binary "@${FILE}.tsq" https://freetsa.org/tsr -o ${FILE}.tsr
    echo "Timestamp created in file: ${FILE}.tsr"
}
 
#
# Verify a FreeTSA timestamp for a file
#
function verify_timestamp {
    FILE=$1

    debug "verify_timestamp: $FILE"
    if [ ! -f $FILE ]; then
        echo "ERROR: Invalid file $FILE"
        exit 1
    fi
    if [ ! -f ${FILE}.tsr ]; then
        echo "ERROR: No timestamp for file. We need a ${FILE}.tsr file"
        exit 1
    fi

    echo "Downloading required certificates"
    curl -s https://www.freetsa.org/files/tsa.crt -o /tmp/tsa.crt
    curl -s https://www.freetsa.org/files/cacert.pem -o /tmp/cacert.pem

    # FIXME: Check if we have connection to the internet
    echo "**** Showing timestamp for file: ${FILE}"
    openssl ts -reply -in ${FILE}.tsr -text
    echo "**** Verifying signature"

    openssl ts -verify -data ${FILE} -in ${FILE}.tsr -CAfile /tmp/cacert.pem -untrusted /tmp/tsa.crt
    echo "***************************************************************************"
    echo "You don't need to trust this script"
    echo "You can manually check the timestamp following the FreeTSA documentation:"
    echo "https://www.freetsa.org/index_en.php"
    echo "***************************************************************************"
}


#########################################
######             MAIN            ######
#########################################

debug=0
do_nothing=0

# Parse options
while getopts "dhn" opt; do
  case $opt in
    d)
      debug=1
      ;;
    h)
      usage
      exit 0
      ;;
    n)
      do_nothing=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))

# Parse command
CMD=$1
case $CMD in
  "setup")
    setup $2
    ;;
  "info")
    info
    ;;
  "protect_rw")
    protect_rw
    ;;
  "unprotect_rw")
    unprotect_rw
    ;;
  "wipe_rw")
    wipe_rw
    ;;
  "hash_dir")
    hash_dir $2
    ;;
  "timestamp")
    timestamp $2
    ;;
  "verify_timestamp")
    verify_timestamp $2
    ;;
  *)
    echo "ERROR Invalid command: $CMD" >&2
    usage
    exit 1
    ;;
esac


