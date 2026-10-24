# Debian on Intel MacBook — Offline Broadcom WiFi Kit

**Status:** Verified working, April 2026 · **Hardware:** Intel MacBooks
(2010–2019) with Broadcom BCM43xx WiFi · **OS:** Debian 13.4.0 (Trixie) amd64

## Overview

A fresh Debian install on most Intel MacBooks has no working WiFi: the
Broadcom chip needs the `broadcom-sta-dkms` driver, which has to be compiled
on the machine, and the compiler and kernel headers it needs are not on a
minimal install. This kit is the 92 `.deb` packages that break that loop,
carried in on a USB stick and installed with `dpkg`. The packages are pinned
to **Debian 13.4.0**, so install from the 13.4.0 media, not the latest ISO:
any other point release has a different kernel, and the driver will not
build. Once you are online, [Step 2 of the series](https://github.com/willardcsoriano/debian-intel-macbook-post-install)
switches you to the `linux-headers-amd64` metapackage, so the driver rebuilds
itself on every future kernel update.

## Table of Contents

- [Overview](#overview)
- [Requirements](#requirements)
  - [Why 13.4.0 Exactly](#why-1340-exactly)
- [Download the Packages](#download-the-packages)
- [What Is in the Kit](#what-is-in-the-kit)
- [Installation](#installation)
  - [1. Mount the USB as Root](#1-mount-the-usb-as-root)
  - [2. Install and Build the Driver](#2-install-and-build-the-driver)
  - [3. Load the Driver](#3-load-the-driver)
  - [4. Connect](#4-connect)
  - [5. Make WiFi Persistent](#5-make-wifi-persistent)
  - [6. Set Up sudo and Run Step 2](#6-set-up-sudo-and-run-step-2)
- [Troubleshooting](#troubleshooting)
  - [Kernel Mismatch](#kernel-mismatch)
  - [DKMS Build Failed](#dkms-build-failed)
  - [b43 Error at Boot](#b43-error-at-boot)
  - [Missing Package Errors](#missing-package-errors)
  - [wpa\_supplicant Fails to Connect](#wpa_supplicant-fails-to-connect)
  - [Non-Broadcom WiFi Chip](#non-broadcom-wifi-chip)
- [Contributing](#contributing)
- [Citation](#citation)

## Requirements

| | |
|---|---|
| **Hardware** | Intel MacBook with a Broadcom BCM43xx chip (BCM4360, BCM43224 and similar). Verified on a MacBook Air Mid-2015. Apple Silicon (M1 and later) is not supported. |
| **Install media** | Debian **13.4.0** amd64 netinst: [debian-13.4.0-amd64-netinst.iso](https://cdimage.debian.org/cdimage/archive/13.4.0/amd64/iso-cd/debian-13.4.0-amd64-netinst.iso) from Debian's archive |
| **Kernel** | `6.12.73+deb13-amd64`, the kernel 13.4.0 installs |
| **Driver** | `broadcom-sta-dkms` 6.30.223.271-26 |
| **Other** | A USB stick with 2 GB free, a second machine with internet, your WiFi name and password |

To check your chip first: in macOS, Apple menu → About This Mac → System
Report → Network → Wi-Fi, and look for an identifier starting with `BCM43`.

If you have not installed Debian yet, [INSTALLATION.md](INSTALLATION.md)
covers putting the installer and this kit on one USB stick.

### Why 13.4.0 Exactly

The kit's packages are the versions shipped in Debian 13.4.0, among them
kernel headers `6.12.73`, `libsystemd0 257.9` and `libc6 2.41-12+deb13u2`.

- **Newer media (13.5 and later)** installs a newer kernel, such as
  `6.12.86` in 13.5, so the bundled headers do not match and DKMS cannot
  build the driver. `dpkg -i` would also *downgrade* core libraries like
  `libc6` to the kit's older versions.
- **Older media (13.0–13.3)** installs an older kernel and fails on
  dependencies. For example, `libsystemd0 257.9` first shipped in 13.2.

`https://www.debian.org/download` always serves the newest point release,
so use the archive link above. Check what you are running with `uname -r`
and `cat /etc/debian_version`.

## Download the Packages

GitHub's size limits keep the packages out of this repo. The three hosts
carry the same package set:

| Host | Link |
|---|---|
| **Internet Archive** (recommended) | https://archive.org/details/debian-trixie-macbook-broadcom-wifi-offline |
| **Hugging Face** | https://huggingface.co/buckets/unicornfacemask/debian-trixie-macbook-broadcom-wifi-offline-packages |
| **Zenodo** (DOI) | https://zenodo.org/records/19414495 |

Put every `.deb` in one flat folder on the USB stick, with no subfolders.
The install step uses a `*.deb` wildcard.

`linux-image-6.12.73+deb13-amd64` (107 MB) is only a fallback, because the
13.4.0 install already runs that kernel. If a host is missing it, it is on
the [Debian mirror](http://ftp.debian.org/debian/pool/main/l/linux/linux-image-6.12.73+deb13-amd64_6.12.73-1_amd64.deb).

## What Is in the Kit

| Group | Packages |
|---|---|
| Driver | `broadcom-sta-dkms`, `dkms` |
| Kernel build | `linux-headers-6.12.73+deb13-amd64`, `linux-headers-6.12.73+deb13-common`, `linux-kbuild-6.12.73+deb13`, `pahole`, `dwarves` |
| Compiler | `gcc-14`, `cpp-14`, `binutils`, `make`, `patch`, and their `x86-64-linux-gnu` variants |
| Packaging | `dpkg-dev`, `libdpkg-perl`, `xz-utils`, `fakeroot` |
| WiFi tools | `wpasupplicant`, `iw`, `libnl-3-200`, `libnl-genl-3-200`, `libssl3t64` |
| Libraries | `libc6`, `libc6-dev`, `libsystemd0` and the other libraries the toolchain depends on |

## Installation

A minimal install has no `sudo`, so every command below runs as root.

### 1. Mount the USB as Root

Log in, become root, and find the USB stick's data partition. It is usually
the largest partition on the stick:

```bash
su -
lsblk -o NAME,SIZE,FSTYPE,LABEL
mkdir -p /mnt/usb
mount /dev/sdb2 /mnt/usb   # use your partition from lsblk
ls /mnt/usb                # should list the .deb files
```

Device names such as `sdb` can change between boots, so run `lsblk` each
time.

### 2. Install and Build the Driver

```bash
cd /mnt/usb
dpkg -i *.deb
dpkg --configure -a
```

The first command prints many dependency errors. That is expected: `dpkg`
unpacks everything in one pass, and `--configure -a` then sets the packages
up in the right order. During configuration, DKMS compiles the driver,
which takes 2–4 minutes. Wait for:

```text
DKMS: build completed.
DKMS: install completed.
```

Then check that nothing is left half-installed. If `dpkg --audit` prints
anything, run all three commands in this step again.

```bash
dpkg --audit
dkms status   # expect: broadcom-sta/6.30.223.271, 6.12.73+deb13-amd64, x86_64: installed
```

### 3. Load the Driver

The open-source Broadcom drivers conflict with `wl`, so unload them first:

```bash
modprobe -r b43 bcma ssb
modprobe wl
lsmod | grep wl   # expect a wl line
```

### 4. Connect

Find your interface name with `ip link`. On a 2015 MacBook Air it is
`wlp3s0`. Use your own name if it differs.

```bash
ip link set wlp3s0 up
iw wlp3s0 scan | grep SSID
wpa_passphrase "YOUR_NETWORK" "YOUR_PASSWORD" > /etc/wpa_supplicant/wpa_supplicant.conf
wpa_supplicant -B -i wlp3s0 -c /etc/wpa_supplicant/wpa_supplicant.conf
dhcpcd wlp3s0
ping -c 3 debian.org
```

### 5. Make WiFi Persistent

The connection above does not survive a reboot. Now that you are online,
hand it to NetworkManager:

```bash
apt install network-manager
systemctl enable --now NetworkManager
nmcli device wifi connect "YOUR_NETWORK" password "YOUR_PASSWORD"
```

### 6. Set Up sudo and Run Step 2

Still as root, add your user to the `sudo` group, then log out and back in
as that user:

```bash
usermod -aG sudo yourusername
```

Then run the post-install script, which sets up the XFCE desktop and the
MacBook hardware:

```bash
bash <(curl -s https://raw.githubusercontent.com/willardcsoriano/debian-intel-macbook-post-install/v1.10.0/setup.sh)
```

This runs the v1.10.0 release. The post-install repo's
[Quick Start](https://github.com/willardcsoriano/debian-intel-macbook-post-install#quick-start)
always has the command for the latest one. Among other things, it installs
the `linux-headers-amd64` metapackage. After that, every kernel upgrade
pulls in matching headers and DKMS rebuilds `wl` automatically, so the
pinned versions in this kit stop mattering.

## Troubleshooting

### Kernel Mismatch

If `uname -r` is not `6.12.73+deb13-amd64`, the bundled headers do not
match your kernel, and the DKMS build fails or never starts. The reliable
fix is to reinstall from the [13.4.0 media](#requirements).

Do not install the kit's older kernel over a newer system to force a
match. That downgrades the kernel and, through `dpkg -i *.deb`, core
libraries too. If you cannot reinstall, build a kit for your own kernel:
see [Contributing](#contributing).

### DKMS Build Failed

If `dkms status` does not say `installed`, the build failed. The usual
cause is that `patch` or `pahole` did not make it onto the stick:

```bash
dpkg -l patch pahole
```

Copy any missing package over and run `dpkg --configure -a` again.

### b43 Error at Boot

`b43 bcma0:1 probe with driver b43 failed with error -95` is harmless. It
means the open-source driver tried to claim the card and stepped aside for
`wl`.

### Missing Package Errors

An error such as `dpkg-dev depends on xz-utils` means a file was not
copied to the stick. Compare the stick against the download host's file
list, for example with `ls /mnt/usb | grep xz`.

### wpa\_supplicant Fails to Connect

Network names and passwords are case-sensitive. Re-run `wpa_passphrase`
with both in quotes.

### Non-Broadcom WiFi Chip

If `lspci | grep -i network` shows an Intel WiFi adapter, this kit is not
for your machine. Intel chips use firmware from Debian's
`non-free-firmware` packages instead.

## Contributing

To build a kit for a different point release, download the matching
`linux-headers`, `linux-kbuild` and `linux-image` packages, plus any
library whose version changed, from
`http://ftp.debian.org/debian/pool/main/` (the kernel is under
`l/linux/`). Pull requests with a verified package set are welcome.

If you test the kit on another MacBook model, open an issue with the model
(`sudo dmidecode -s system-product-name`), the Broadcom chip, and the
result.

## Citation

Cite the Zenodo archive, which carries a permanent DOI:
https://zenodo.org/records/19414113
