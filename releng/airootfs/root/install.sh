#!/bin/bash

# Function to print messages
msg() {
    echo -e "\n==> $1\n"
}

# Function to list available drives and their sizes
list_drives() {
    echo -e "\nAvailable drives:"
    lsblk -d -o NAME,SIZE | grep -E '^sd|^nvme|^vd'
    echo -e "\n"
}

# Check if Arch is already installed
check_arch_installed() {
    if command -v pacman >/dev/null 2>&1 && grep -q "Arch Linux" /etc/os-release; then
        msg "Arch Linux is already installed on this system."
        msg "Redirecting to bash shell..."
        /bin/bash
        exit 0
    fi
}

# Check if Arch is installed and redirect if true
check_arch_installed

# Setting up system clock
msg "Syncing system clock..."
timedatectl set-ntp true

# List available drives
list_drives

# Automatically select the first disk for installation
disk=$(lsblk -d -o NAME | grep -E '^sd|^nvme' | head -n 1)
msg "Automatically selected disk: $disk"

# Warning the user about disk formatting
msg "WARNING: This will erase all data on $disk!"

# Proceed with installation without user confirmation
msg "Proceeding with installation on $disk..."

# Partitioning the disk automatically
msg "Partitioning the disk..."
parted -s $disk mklabel gpt
parted -s $disk mkpart ESP fat32 1MiB 513MiB
parted -s $disk set 1 boot on
parted -s $disk mkpart primary ext4 513MiB 100%

# Formatting partitions
msg "Formatting partitions..."
mkfs.fat -F32 ${disk}1
mkfs.ext4 ${disk}2

# Mounting partitions
msg "Mounting partitions..."
mount ${disk}2 /mnt
mkdir -p /mnt/boot
mount ${disk}1 /mnt/boot

# Installing base system
msg "Installing base system..."
pacstrap /mnt base linux linux-firmware vim sudo

# Generating fstab
msg "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Chrooting into the new system
msg "Entering the system to configure it (chroot)..."
arch-chroot /mnt /bin/bash <<EOF

# Setting the time zone (default to UTC)
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

# Setting up localization
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Hostname setup
echo "archlinux" > /etc/hostname
echo "127.0.0.1    localhost" >> /etc/hosts
echo "::1          localhost" >> /etc/hosts
echo "127.0.1.1    archlinux.localdomain archlinux" >> /etc/hosts

# Setting root password
echo "Setting root password..."
echo "root:root" | chpasswd

# Installing essential packages
pacman -S --noconfirm grub efibootmgr networkmanager

# Installing GRUB bootloader
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Enabling NetworkManager
systemctl enable NetworkManager

EOF

# Unmounting partitions and finishing up
msg "Unmounting and completing installation..."
umount -R /mnt

msg "Arch Linux installation is complete! You can now reboot your system."

