#!/bin/bash

# Create required folders
mkdir -p /home/pi/PrintQueue
mkdir -p /home/pi/PrintCompleted

# Clone GitHub repo if not already present
if [ ! -d /home/pi/web_dashboard ]; then
  git clone https://github.com/creol/PiPrintQ /home/pi/web_dashboard
fi

cd /home/pi/web_dashboard || exit

# Make bootmenu.sh executable
chmod +x /home/pi/web_dashboard/bootmenu.sh

# Pull latest changes from GitHub
git fetch origin
git checkout main || git checkout -b main origin/main
git reset --hard origin/main
git clean -fd

# Set up Python virtual environment
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip

# Install requirements if the file exists
if [ -f requirements.txt ]; then
  pip install -r requirements.txt
else
  echo "WARNING: requirements.txt not found, skipping pip install"
fi

# Install and enable systemd services
sudo cp /home/pi/web_dashboard/systemd/piprintq.service /etc/systemd/system/
sudo cp /home/pi/web_dashboard/systemd/web-dashboard.service /etc/systemd/system/
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable piprintq.service
sudo systemctl enable web-dashboard.service

# Start services
sudo systemctl restart piprintq.service
sudo systemctl restart web-dashboard.service

# Ensure boot menu launches on login
if ! grep -Fxq "/home/pi/web_dashboard/bootmenu.sh" /home/pi/.bashrc; then
  echo "/home/pi/web_dashboard/bootmenu.sh" >> /home/pi/.bashrc
fi

echo "Installation complete. Reboot or re-login to use the boot menu."
