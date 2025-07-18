#!/bin/bash

while true; do
  clear
  IP=$(hostname -I | awk '{print $1}')
  echo "Dashboard: http://$IP:5000"
  echo "CUPS Admin: http://$IP:631/printers"
  echo "==== Pi Print Queue Menu ===="
  echo "1. Start print watcher"
  echo "2. Stop print watcher"
  echo "3. Status of print watcher"
  echo "4. List available printers"
  echo "5. View recent archived files"
  echo "6. Launch web dashboard"
  echo "7. Reset Print Counts"
  echo "8. Clear Archive Files"
  echo "9. Run installer from GitHub"
  echo "10. Reboot System"
  echo "11. Exit"
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
  echo "Running latest installer..."
  curl -sSL https://raw.githubusercontent.com/creol/PiPrintQ/main/install.sh | bash
  ;;
    10) sudo reboot ;;
    11) exit ;;
    *) echo "Invalid option" ;;
  esac
  echo ""
  read -p "Press enter to continue..."
done
