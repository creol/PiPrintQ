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
  echo "7. Reset Print Counts (auto-backup)"
  echo "8. Clear Archived Files"
  echo "9. Exit"
  echo "============================="
  read -p "Choose an option: " choice

  case "$choice" in
    1) sudo systemctl start piprintq.service ;;
    2) sudo systemctl stop piprintq.service ;;
    3) sudo systemctl status piprintq.service ;;
    4) lpstat -p ;;
    5) ls -lh /home/vote/PrintCompleted | tail ;;
    6) sudo systemctl restart web-dashboard.service ;;
    7)
      ts=$(date +"%Y-%m-%d_%H-%M-%S")
      cp /home/vote/web_dashboard/stats.json "/home/vote/web_dashboard/stats_backup_$ts.json"
      cat /home/vote/web_dashboard/stats.clear > /home/vote/web_dashboard/stats.json
      echo "✅ Print counts reset and backed up to stats_backup_$ts.json"
      ;;
    8)
      rm -f /home/vote/PrintCompleted/*
      echo "✅ Archived files cleared."
      ;;
    9) exit ;;
    *) echo "Invalid option" ;;
  esac

  echo ""
  read -p "Press enter to continue..."
done

