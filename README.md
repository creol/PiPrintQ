# PiPrintQ Setup Guide (Lite Edition)

This guide walks you through installing and running the **PiPrintQ** system on a Raspberry Pi using Raspberry Pi OS **Lite (headless)**.

## ✅ Features

* Auto-print PDFs from a watched folder
* Round-robin printing to 10+ USB printers for balanced use
* Web dashboard for monitoring, reprinting, and downloading
* Status lights, printer health, stats tracking
* Easy update, reboot, and reset tools

---

## 📦 Prerequisites

* Raspberry Pi 4 (2GB+ RAM recommended)
* Raspberry Pi OS Lite (Bookworm or Bullseye)
* USB printers or virtual printer setup
* Network connection

---

## 🪛 Step-by-Step Installation

### 1. Flash Raspberry Pi OS Lite

* Download [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
* Select **Raspberry Pi OS Lite (64-bit)**
* Set hostname to `piprintq`
* Enable SSH, set username: `pi` and password: `print`

### 2. Boot Pi and SSH In

```bash
ssh pi@<your-pi-ip>
```

### 3. Install Git

```bash
sudo apt update && sudo apt install -y git
```

### 4. Run the Installer

```bash
curl -sSL https://raw.githubusercontent.com/creol/PiPrintQ/main/install.sh | bash
```

When the installer finishes, press **Enter** to reboot when prompted.


---

## 📂 Folder Structure

* `/home/pi/PrintQueue` → Drop PDFs here to auto-print
* `/home/pi/PrintCompleted` → Stores printed files for reprint/download
* `/home/pi/web_dashboard/` → App files and configuration

---

## 🌐 Access the Dashboard

In your browser:

```
http://<pi-ip>:5000
```
or

* http://piprintq:5000

...

Use this interface to:

* View print jobs
* Search or filter by file name, time, or action
* Pause/resume printers
* Reprint/download with password

---

## 🌐 Access the Printer Admin

In your browser:

```
http://<pi-ip>:631/admin
```
or

* http://piprintq:631/admin

...

Use this interface to:

* Add printers
* Manage printers 
* Configure printers
   
---

## 🔁 Reinstalling/Updating

From the boot menu, choose:

```
9. Run installer from GitHub
```

This downloads and runs the latest `install.sh` script, giving you a clean installation of PiPrintQ. When it finishes you'll be prompted to reboot.

> 🔒 The installer always pulls the latest code from GitHub, discarding any local changes.

---

## 🔧 Services

These are managed with systemd:

```bash
sudo systemctl status piprintq.service
sudo systemctl status web-dashboard.service
```

To restart:

```bash
sudo systemctl restart piprintq.service
sudo systemctl restart web-dashboard.service
```

---

## 🔐 Default Passwords

* Reprint: `doit2times`
* Download: `doit2times`
* Delete all files: `skyfall`

You can customize these in `/home/pi/web_dashboard/app.py`

---

## 🧪 Simulate Printers (Optional)

If no physical printers are connected:

```bash
sudo lpadmin -p Printer1 -E -v file:/dev/null -m drv:///sample.drv/generic.ppd
sudo lpadmin -p Printer2 -E -v file:/dev/null -m drv:///sample.drv/generic.ppd
... (up to Printer10)
```

---

## ✅ All Set!

Your PiPrintQ system is now live and ready.

For questions or issues, open an issue on [GitHub](https://github.com/creol/PiPrintQ).
