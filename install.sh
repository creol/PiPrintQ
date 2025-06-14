#!/bin/bash

echo "🔧 Installing system dependencies..."
sudo apt update
sudo apt install -y git cups python3-pip python3-venv samba

# Create required folders
mkdir -p /home/pi/PrintQueue
mkdir -p /home/pi/PrintCompleted

# Clone GitHub repo if not already present
if [ ! -d /home/pi/web_dashboard ]; then
  git clone https://github.com/creol/PiPrintQ /home/pi/web_dashboard
fi

cd /home/pi/web_dashboard || exit

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
pip install flask watchdog

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

# Make bootmenu.sh executable
chmod +x /home/pi/web_dashboard/bootmenu.sh

echo "🔧 Configuring CUPS and printers..."

# Add user 'pi' to CUPS group
sudo usermod -aG lpadmin pi
sudo systemctl restart cups

# Add 10 virtual printers
for i in {1..10}; do
  sudo lpadmin -p Printer$i -E -v file:/dev/null -m drv:///sample.drv/generic.ppd
done

# Configure Samba to share PrintQueue
if ! grep -q "\[PrintQueue\]" /etc/samba/smb.conf; then
  sudo tee -a /etc/samba/smb.conf > /dev/null <<EOF

[PrintQueue]
   path = /home/pi/PrintQueue
   browseable = yes
   writable = yes
   guest ok = yes
   create mask = 0777
   directory mask = 0777
   public = yes
EOF
fi

# Restart Samba to apply share
sudo systemctl restart smbd

echo ""
echo "✅ PiPrintQ installation complete!"
echo "➡️  Reboot or re-login to start the system."
echo "🖨️  Printers Printer1–Printer10 installed"
echo "📁 /home/pi/PrintQueue shared on the network"
