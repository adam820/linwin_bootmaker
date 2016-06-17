#!/bin/bash

## Based on instructions at: ##
## https://thornelabs.net/2013/06/10/create-a-bootable-windows-7-usb-drive-in-linux.html ##
## Please see LICENSE for license information. ##

# PRE-FLIGHT: Set some variables.
DISK=$1
WINISO=$2

# PRE-FLIGHT: Verify programs
# parted - partitioning
if [ -x "$(command -v parted)" ]; then
	PARTED=$(command -v parted)
else
	echo -e "[ ERROR ]: Cannot locate 'parted'; please install / make sure in PATH."
	exit 1
fi

# ms-sys - Write Windows-compatible bootloaders
if [ -x /usr/local/bin/ms-sys ]; then
	MSSYS=/usr/local/bin/ms-sys
elif [ -x "$(command -v ms-sys)" ]; then
	MSSYS=$(command -v ms-sys)
else
	echo -e "[ ERROR ]: Cannot locate 'ms-sys' (default '/usr/local/bin/ms-sys'); please install / make sure in PATH."
	exit 1
fi

# Usage info
if [ "$1" == "--help" ] || [ "$1" == "-h" ] || [ $# -lt 1 ]; then
	echo -ne "\n"
	echo -e "Usage: ${0} {/dev/mydisk} {/path/to/windows.iso}"
	exit 0
fi

# PRE-FLIGHT: A couple of sanity checks
# Check for disk parameter; verify it exists
if [ $# -gt 2 ]; then
	echo -e "[ ERROR ]: Too many arguments. Please specify the disk device and path to ISO."
	exit 1
elif [[ "${1}" != "/dev/"* ]]; then
	echo -e "[ ERROR ]: Please specify a disk device. -- e.g. \"/dev/sdX\""
	exit 1
fi

# Check for ISO
if [[ ! -a "${2}" ]]; then
	echo -e "[ ERROR ]: Please verify path to ISO file. Cannot find ${2}."
	exit 1
fi

if [ ! -b $DISK ]; then
	echo -e "[ ERROR ]: Disk device doesn't exist. Please verify."
	exit 1
fi

# Re-prompt about destroying. Quit if no.
echo -ne "\n"
echo -e ">> Using disk ${DISK}."
read -p ">> [ WARNING ]: ALL DATA WILL BE DESTROYED. ARE YOU SURE? (y/n)" -n 1 -r

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	echo -e "\n"
	exit 1
fi

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !!!! After here be dragons! !!!!!!
# !!!! Disk destruction below! !!!!!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Parted partitioning, create NTFS.
echo -ne "\n"
echo -e ">> Partitioning disk..."
$PARTED -s $DISK "mklabel msdos"
$PARTED -s $DISK "mkpart primary ntfs 1 -1"
sleep 1
$PARTED -s $DISK "set 1 boot on"

echo -ne "\n"
echo -e ">> Creating NTFS partition..."
mkfs.ntfs -f ${DISK}1

# Use ms-sys to make bootloader.
echo -ne "\n"
echo -e ">> Writing Windows 7 boot loader..."
$MSSYS -7 $DISK

# Mount and copy files to disk.
echo -ne "\n"
echo -e ">> Mounting disk to /mnt..."
if ! [ $(ls -A /mnt) ]; then
	mount ${DISK}1 /mnt
else
	echo -e "\n [ ERROR ]: /mnt not empty."
	exit 1
fi

echo -ne "\n"
echo -e ">> Mounting Windows 7 ISO to /media..."
if ! [ $(ls -A /media) ]; then
	mount -o loop $2 /media
	if [ $? -ne 0 ]; then
		echo -e "\n[ ERROR ]: Issue mounting ISO. Exiting."
	exit 1
fi
else
	echo -e "\n [ ERROR ]: /media not empty."
	exit 1
fi

echo -ne "\n"
echo -e ">> Copying Windows installation contents to disk..."
cp -av /media/* /mnt/
if [ $? -ne 0 ]; then
	echo -e "\n[ ERROR ]: Issue copying files. Exiting."
	exit 1
fi

# Clean up.
echo -ne "\n"
echo -e ">> Unmounting disks..."
umount /mnt
umount /media

echo -ne "\n \n"
echo -e "Creation complete. Enjoy!"
