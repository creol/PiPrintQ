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

# Preserve existing dashboard data before resetting the repo
STATS_FILE=/home/pi/web_dashboard/stats.json
ARCHIVE_LOG=/home/pi/web_dashboard/archive_log.json
if [ -f "$STATS_FILE" ]; then
  cp "$STATS_FILE" /tmp/stats.backup.json
fi
if [ -f "$ARCHIVE_LOG" ]; then
  cp "$ARCHIVE_LOG" /tmp/archive_log.backup.json
fi

git reset --hard origin/main
git clean -fd

# Restore dashboard data after pulling updates
if [ -f /tmp/stats.backup.json ]; then
  mv /tmp/stats.backup.json "$STATS_FILE"
fi
if [ -f /tmp/archive_log.backup.json ]; then
  mv /tmp/archive_log.backup.json "$ARCHIVE_LOG"
fi

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

# Create a helper command to launch the boot menu
if [ ! -f /usr/local/bin/bm ]; then
  sudo tee /usr/local/bin/bm > /dev/null <<'EOF'
#!/bin/bash
/home/pi/web_dashboard/bootmenu.sh "$@"
EOF
  sudo chmod +x /usr/local/bin/bm
fi

echo "🔧 Configuring CUPS and printers..."

# Add user 'pi' to CUPS group
sudo usermod -aG lpadmin pi

# Open the CUPS port to the local network and allow access
sudo sed -i.bak -e 's/^Listen localhost:631/#&/' -e 's/^Listen 127.0.0.1:631/#&/' /etc/cups/cupsd.conf
if ! grep -q '^Port 631' /etc/cups/cupsd.conf; then
  sudo sed -i '1i Port 631' /etc/cups/cupsd.conf
fi
sudo sed -i '/<Location \/>/,/<\/Location>/ { /Allow @local/d; /<\/Location>/i\  Allow @local }' /etc/cups/cupsd.conf
sudo sed -i '/<Location \/admin>/,/<\/Location>/ { /Allow @local/d; /<\/Location>/i\  Allow @local }' /etc/cups/cupsd.conf

# Ensure remote access stays enabled
sudo cupsctl --remote-any --share-printers

# Restart CUPS to apply configuration changes
sudo systemctl restart cups

# Add 10 virtual printers
for i in {1..10}; do
  sudo lpadmin -p Printer$i -E -v file:/dev/null -m drv:///sample.drv/generic.ppd
done

# Configure Samba to share PrintQueue
# Ensure the Samba user "pi" exists with password "print"
if ! sudo pdbedit -L | grep -q '^pi:'; then
  echo -e "print\nprint" | sudo smbpasswd -s -a pi
fi

# Configure Samba to share PrintQueue requiring authentication
if ! grep -q "\[PrintQueue\]" /etc/samba/smb.conf; then
  sudo tee -a /etc/samba/smb.conf > /dev/null <<EOF

[PrintQueue]
   path = /home/pi/PrintQueue
   browseable = yes
   writable = yes
   guest ok = no
   valid users = pi
   create mask = 0777
   directory mask = 0777
   public = no
EOF
fi

# Restart Samba to apply share
sudo systemctl restart smbd

echo ""
echo "✅ PiPrintQ installation complete!"
echo "➡️  Reboot or re-login to start the system."
echo "🖨️  Printers Printer1–Printer10 installed"
echo "📁 /home/pi/PrintQueue shared on the network"

read -rp "Press Enter to reboot now or Ctrl+C to cancel..."
sudo reboot
