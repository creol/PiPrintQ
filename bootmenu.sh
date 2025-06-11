cat << 'EOF' > ~/bootmenu.sh
#!/bin/bash

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
    7) cp /home/pi/web_dashboard/stats.clear /home/pi/web_dashboard/stats.json ;;
    8) rm -f /home/pi/PrintCompleted/*.pdf ;;
    9)
      echo "Pulling latest from GitHub..."
      cd /home/pi/web_dashboard
      git pull
      bash install.sh
      ;;
    10) exit ;;
    *) echo "Invalid option" ;;
  esac
  echo ""
  read -p "Press enter to continue..."
done
EOF
