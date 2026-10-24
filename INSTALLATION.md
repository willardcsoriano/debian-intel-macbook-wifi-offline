# Debian Trixie (13) Installation Guide — Intel MacBook Air (Offline Method)

This guide walks through the complete process of installing Debian 13 Trixie on an Intel MacBook Air without an active internet connection. It covers preparing a hybrid USB stick that carries both the Debian installer and the offline WiFi driver packages, navigating the installer itself, and activating WiFi on first boot.

Before following this guide, download the offline package collection from the main repository. You will need those files ready before you begin.

---

## Table of Contents

- [How the Hybrid USB Works](#how-the-hybrid-usb-works)
- [Phase 1 — Prepare the Hybrid USB](#phase-1--prepare-the-hybrid-usb)
  - [1. Download the Debian Installer ISO](#1-download-the-debian-installer-iso)
  - [2. Flash the ISO to Your USB Stick](#2-flash-the-iso-to-your-usb-stick)
  - [3. Create the Driver Partition (Windows)](#3-create-the-driver-partition-windows)
  - [3. Create the Driver Partition (macOS)](#3-create-the-driver-partition-macos)
  - [3. Create the Driver Partition (Linux)](#3-create-the-driver-partition-linux)
  - [4. Copy the Packages to the DRIVERS Partition](#4-copy-the-packages-to-the-drivers-partition)
- [Phase 2 — Boot the MacBook Air from USB](#phase-2--boot-the-macbook-air-from-usb)
- [Phase 3 — The Debian Installer](#phase-3--the-debian-installer)
  - [Language and Location](#language-and-location)
  - [Network Configuration](#network-configuration)
  - [Users and Passwords](#users-and-passwords)
  - [Disk Partitioning](#disk-partitioning)
  - [Base System Installation](#base-system-installation)
  - [Software Selection](#software-selection)
  - [GRUB Bootloader](#grub-bootloader)
  - [Finishing the Installation](#finishing-the-installation)
- [Phase 4 — First Login and Driver Installation](#phase-4--first-login-and-driver-installation)
- [Troubleshooting](#troubleshooting)
  - [Mac Does Not Boot from USB](#mac-does-not-boot-from-usb)
  - [Installer Gets Stuck on Network Configuration](#installer-gets-stuck-on-network-configuration)
  - [No EFI Boot Option Visible](#no-efi-boot-option-visible)
  - [DRIVERS Partition Not Visible After Booting into Debian](#drivers-partition-not-visible-after-booting-into-debian)
  - [Installer Asks for a Network Mirror Repeatedly](#installer-asks-for-a-network-mirror-repeatedly)
- [Summary](#summary)

## How the Hybrid USB Works

Flashing a Debian ISO onto a USB stick with a tool like BalenaEtcher creates a read-only installer partition that fills only a small portion of the drive. The rest of the space is left as unallocated. This guide takes advantage of that unallocated space by creating a second writable partition — called `DRIVERS` — where the offline `.deb` packages live alongside the installer on the same physical stick.

This means you only need one USB stick for the entire process.

---

## Phase 1 — Prepare the Hybrid USB

This phase can be completed on any machine with internet access — Windows, macOS, or Linux all work.

### 1. Download the Debian Installer ISO

Download the Debian **13.4.0** netinst ISO from Debian's archive:

```
https://cdimage.debian.org/cdimage/archive/13.4.0/amd64/iso-cd/debian-13.4.0-amd64-netinst.iso
```

Use exactly this version, not the latest one from `https://www.debian.org/download`. The offline packages are pinned to 13.4.0's kernel (`6.12.73+deb13-amd64`) and libraries, and any other point release installs a kernel the driver cannot build against. The README's [Why 13.4.0 Exactly](README.md#why-1340-exactly) section explains this. The image is about 790 MB and contains what the installer needs to boot. The rest is normally fetched from the internet, but this guide skips that step.

### 2. Flash the ISO to Your USB Stick

Insert your USB stick (at least 8GB recommended, though 64GB or larger gives comfortable room for the driver partition).

Download and open BalenaEtcher from `https://etcher.balena.io`, select the ISO, select your USB stick, and click Flash. Wait for it to complete and verify.

> **Warning:** Flashing will erase everything currently on the USB stick. Back up anything important before proceeding.

### 3. Create the Driver Partition (Windows)

After flashing, Windows may show a dialog saying the drive needs to be formatted. **Dismiss or cancel this prompt — do not format.** The drive is not broken, Windows simply cannot read the Linux partition that BalenaEtcher created.

Open **Disk Management** (right-click the Start button and select Disk Management). Locate your USB stick in the list of drives. You will see two regions: a small partition containing the installer, and a large block of unallocated space. The unallocated space is what you will use.

Right-click the unallocated space and select **New Simple Volume**. Follow the wizard with these settings:
- Format: FAT32 or exFAT (both work — exFAT handles individual files larger than 4GB which matters for the kernel image)
- Volume label: `DRIVERS`
- Leave the drive letter assignment as whatever Windows suggests

Click Finish. The new partition will appear as a normal drive in Windows Explorer.

### 3. Create the Driver Partition (macOS)

Open **Disk Utility**, select your USB stick from the sidebar, and click **Partition**. Add a new partition in the unallocated space, format it as ExFAT, and name it `DRIVERS`.

### 3. Create the Driver Partition (Linux)

Open a terminal and run `lsblk` to identify your USB device (e.g. `/dev/sdb`). Then use `fdisk` or `gparted` to create a new partition in the unallocated space and format it as FAT32 or exFAT.

### 4. Copy the Packages to the DRIVERS Partition

Download the full package collection from the main repository (links in the README) and copy all `.deb` files into the root of the `DRIVERS` partition. Do not place them inside any subfolder — they need to be directly accessible at the top level of the partition for the wildcard install command to work correctly.

Safely eject the USB stick once the copy is complete.

---

## Phase 2 — Boot the MacBook Air from USB

1. Plug the USB stick into the MacBook Air.
2. Shut the Mac down completely — not sleep, not restart, a full shutdown.
3. Press the power button, then immediately hold the **Option (⌥)** key.
4. Keep holding Option until the boot selection screen appears showing drive icons.
5. Select the icon labeled **EFI Boot** — it will appear as a yellow external drive icon.
6. Press Enter to boot.

If you do not see EFI Boot, try unplugging and reinserting the USB, then repeat the process. Occasionally it takes two attempts for the Mac to detect a freshly flashed USB as bootable.

---

## Phase 3 — The Debian Installer

Once the installer loads, follow these steps. The choices highlighted here are specifically important for an offline installation — deviating from them may cause the installer to get stuck waiting for a network connection that will never come.

### Language and Location
Select your preferred language, country, and keyboard layout. These can be changed later and do not affect the offline process.

### Network Configuration
The installer will attempt to detect and configure a network interface. It will fail to find a working connection — this is expected. When it asks you to select a network interface or configure the network, choose:

```
Do not configure the network at this time
```

This is the most important choice in the entire installer. Skipping network configuration prevents the installer from blocking on steps that require internet access.

When asked for a hostname, enter anything you like — for example `debian` or your name. It can be changed later.

### Users and Passwords
You will be asked to set a root password and create a regular user account. The root password is particularly important — you will use it extensively during the driver installation phase after first boot. Choose something you will not forget and do not leave it blank.

### Disk Partitioning
For most users the simplest option works well:

- Select **Guided — use entire disk**
- Select your MacBook's internal SSD — it typically appears as `nvme0n1` or similar
- Select **All files in one partition**
- Confirm and write the changes to disk

> **Note:** This will erase everything on the internal SSD. If you intend to dual-boot macOS and Debian, do not use guided partitioning — manual partitioning is required and is beyond the scope of this guide.

### Base System Installation
The installer will copy the base system from the USB. When it asks the following questions, answer as shown:

- **Scan extra installation media?** — No
- **Use a network mirror?** — No
- **Participate in the package usage survey?** — your choice, no impact on the install

### Software Selection
This screen lets you choose which software to pre-install. For a minimal install suited to this guide, uncheck everything except **standard system utilities**. You can install a desktop environment later once WiFi is working and `apt` is available.

If you prefer to have a desktop environment ready on first boot, you may select GNOME, XFCE, or any other option — just be aware this does not affect the WiFi driver situation and you will still need to follow the driver installation steps before the network works.

### GRUB Bootloader
When asked to install the GRUB bootloader, select **Yes** and install it to your internal drive (`/dev/nvme0n1` or whichever device your SSD appeared as during partitioning).

### Finishing the Installation
The installer will indicate that the installation is complete and prompt you to reboot. When the screen goes dark during the reboot, remove the USB stick. The Mac should boot directly into your new Debian system.

---

## Phase 4 — First Login and Driver Installation

Boot into your new Debian system and log in. If you installed a desktop environment, open a terminal. If you installed the minimal system, you will land directly at a command line prompt.

Switch to root:

```
su -
```

Enter the root password you set during installation.

Now plug in the USB stick and follow the complete instructions in the main `README.md` of this repository to mount the DRIVERS partition, install the 92 packages, configure DKMS, and activate the Broadcom `wl` driver.

Once the driver is loaded and you have confirmed WiFi is working with `lsmod | grep wl`, proceed to connect to your network as described in the README. After that, install NetworkManager for persistent WiFi across reboots:

```
apt install network-manager
systemctl enable NetworkManager
systemctl start NetworkManager
```

At this point your Debian installation is complete and fully connected. Everything else you need can be installed through `apt`.

---

## Troubleshooting

### Mac Does Not Boot from USB
Make sure you are holding Option immediately after pressing the power button, before the Apple logo appears. If EFI Boot does not appear, try a different USB port or re-flash the ISO with BalenaEtcher.

### Installer Gets Stuck on Network Configuration
If you accidentally selected a network interface instead of skipping, the installer may hang waiting for DHCP. Let it time out — it will eventually offer you the option to skip or go back. Navigate back and choose to skip network configuration.

### No EFI Boot Option Visible
Some MacBook models require the USB to be formatted with a GUID Partition Table (GPT). BalenaEtcher handles this automatically, but if you used a different flashing tool you may need to reflash with BalenaEtcher specifically.

### DRIVERS Partition Not Visible After Booting into Debian
Run `lsblk` to find the correct partition. The DRIVERS partition will show up as a separate partition on the same device as your USB stick. Mount it manually as described in the README.

### Installer Asks for a Network Mirror Repeatedly
Simply select No each time. Some installer versions ask more than once depending on which software selections you make. Always answer No to any question involving network mirrors or downloading additional packages.

---

## Summary

The core insight behind this entire approach is that the Debian installer and the driver packages can coexist on a single USB stick by taking advantage of the unallocated space that BalenaEtcher leaves behind. The installer runs from its own read-only partition, and the drivers sit in a separate writable partition that you create afterward. Once Debian is installed and booted, you mount that second partition and complete the driver setup entirely offline.

The process requires patience and attention to a handful of critical choices — particularly skipping network configuration during installation and ensuring the correct kernel version is matched with the correct headers. Every other step is straightforward and repeatable.

---

*Part of the Debian Trixie MacBook Broadcom WiFi Offline Bootstrap project — April 2026.*
