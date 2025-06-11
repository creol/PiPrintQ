#!/bin/bash

# Create required folders
mkdir -p /home/pi/PrintQueue
mkdir -p /home/pi/PrintCompleted

# Clone GitHub repo if not already present
if [ ! -d /home/pi/web_dashboard ]; then
  git clone https://github.com/creol/PiPrintQ /home/pi/web_dashboard
fi

cd /home/pi/web_dashboard || exit

# Pull latest changes from GitHub
git reset --hard HEAD
git clean -fd
git pull

# Set up Python virtual environment
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Install and enable systemd services
sudo cp web_dashboard/systemd/piprintq.service /etc/systemd/system/
sudo cp web_dashboard/systemd/web-dashboard.service /etc/systemd/system/
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable piprintq.service
sudo systemctl enable web-dashboard.service

# Start services
sudo systemctl restart piprintq.service
sudo systemctl restart web-dashboard.service

# Ensure boot menu launches on login
if ! grep -Fxq "/home/pi/bootmenu.sh" /home/pi/.bashrc; then
  echo "/home/pi/bootmenu.sh" >> /home/pi/.bashrc
fi

# Launch boot menu
while true; do
  clear
  echo "==== Pi Print Queue Menu ===="
  echo "1. Start print watcher"
  echo "2. Stop print watcher"
  echo "3. Status of print watcher"
  echo "4. List available printers"
  echo "5. View recent archived files"
  echo "6. Launch web dashboard"
  echo "7. Reset Print Counts"
  echo "8. Clear Archive Files"
  echo "9. Update from GitHub"
  echo "10. Exit"
  echo "============================="
  read -p "Choose an option: " choice

  case "$choice" in
    1) sudo systemctl start piprintq.service ;;
    2) sudo systemctl stop piprintq.service ;;
    3) sudo systemctl status piprintq.service ;;
    4) lpstat -p ;;
    5) ls -lh /home/pi/PrintCompleted | tail ;;
    6) sudo systemctl restart web-dashboard.service ;;
    7) cat /home/pi/web_dashboard/stats.clear > /home/pi/web_dashboard/stats.json ;;
    8) rm -f /home/pi/PrintCompleted/* && echo "Archive cleared." ;;
    9)
      echo "Pulling latest from GitHub..."
      cd /home/pi/web_dashboard || exit
      git reset --hard HEAD
      git clean -fd
      git pull
      echo "Installing venv dependencies..."
      /home/pi/web_dashboard/venv/bin/pip install -r requirements.txt
      echo "Restarting services..."
      sudo systemctl restart piprintq.service
      sudo systemctl restart web-dashboard.service
      echo "Update complete."
      ;;
    10) exit ;;
    *) echo "Invalid option" ;;
  esac
  echo ""
  read -p "Press enter to continue..."
done
