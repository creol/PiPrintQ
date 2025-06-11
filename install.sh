#!/bin/bash
# install.sh - Automated installer for PiPrintQ on Raspberry Pi OS Lite

set -e

REPO="https://github.com/creol/PiPrintQ"
TARGET_DIR="/home/pi/web_dashboard"
USER="pi"

# Update and install dependencies
echo "Updating system and installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y cups samba git python3 python3-pip jq

# Add user to lpadmin and system groups
sudo usermod -aG lpadmin $USER
sudo usermod -aG lp $USER

# Install Flask and gunicorn
sudo -H -u $USER pip3 install flask gunicorn

# Clone GitHub repo
if [ -d "$TARGET_DIR" ]; then
  echo "Existing web_dashboard folder found. Pulling latest..."
  cd "$TARGET_DIR" && git pull
else
  echo "Cloning PiPrintQ repo..."
  sudo -u $USER git clone "$REPO" "$TARGET_DIR"
fi

# Copy systemd services
echo "Installing systemd services..."
sudo cp "$TARGET_DIR/systemd/piprintq.service" /etc/systemd/system/
sudo cp "$TARGET_DIR/systemd/web-dashboard.service" /etc/systemd/system/
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable piprintq.service
sudo systemctl enable web-dashboard.service

# Create folder structure
mkdir -p /home/$USER/PrintQueue /home/$USER/PrintCompleted
chown $USER:$USER /home/$USER/PrintQueue /home/$USER/PrintCompleted

# Enable CUPS web interface and start service
sudo cupsctl --remote-any
sudo systemctl restart cups

# Setup boot menu in home directory
cp "$TARGET_DIR/bootmenu.sh" /home/$USER/bootmenu.sh
chmod +x /home/$USER/bootmenu.sh
chown $USER:$USER /home/$USER/bootmenu.sh

# Start services immediately
sudo systemctl start piprintq.service
sudo systemctl start web-dashboard.service

echo "\n✅ PiPrintQ setup complete. Reboot recommended."
echo "To launch the boot menu: ./bootmenu.sh"
