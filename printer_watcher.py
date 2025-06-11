# printer_watcher.py - Full Updated Version

import os
import time
import json
import shutil
import subprocess
from datetime import datetime

WATCH_FOLDER = '/home/vote/PrintQueue'
ARCHIVE_FOLDER = '/home/vote/PrintCompleted'
STATS_FILE = '/home/vote/web_dashboard/stats.json'
ARCHIVE_LOG = '/home/vote/web_dashboard/archive_log.json'
PAUSE_FILE = '/home/vote/web_dashboard/printer_state.json'
PRINTED_LOG = '/home/vote/web_dashboard/printed_files.log'

os.makedirs(WATCH_FOLDER, exist_ok=True)
os.makedirs(ARCHIVE_FOLDER, exist_ok=True)

def load_json(path, default):
    if not os.path.exists(path): return default
    with open(path) as f:
        return json.load(f)

def save_json(path, data):
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)

def get_active_printers():
    paused = load_json(PAUSE_FILE, {})
    printers = [f"Printer{i}" for i in range(1, 11) if paused.get(f"Printer{i}") != 'paused']
    return printers

def update_stats(printer):
    stats = load_json(STATS_FILE, {"reprints": 0, "downloads": 0, "prints_by_printer": {}})
    stats['prints_by_printer'][printer] = stats['prints_by_printer'].get(printer, 0) + 1
    save_json(STATS_FILE, stats)

def archive_file(filename):
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    archive = load_json(ARCHIVE_LOG, [])
    archive.append({"name": filename, "timestamp": timestamp})
    save_json(ARCHIVE_LOG, archive)

def print_file(filepath, printer):
    subprocess.run(['lp', '-d', printer, filepath])

def main():
    print("📂 Watching folder for print jobs...")
    last_index = 0
    while True:
        files = sorted(f for f in os.listdir(WATCH_FOLDER) if f.lower().endswith('.pdf'))
        active_printers = get_active_printers()

        for i, filename in enumerate(files):
            if not active_printers:
                print("⚠️ All printers paused. Waiting...")
                break

            printer = active_printers[i % len(active_printers)]
            src = os.path.join(WATCH_FOLDER, filename)
            dst = os.path.join(ARCHIVE_FOLDER, filename)

            print_file(src, printer)
            update_stats(printer)
            archive_file(filename)

            with open(PRINTED_LOG, 'a') as log:
                log.write(f"{filename} printed on {printer} at {datetime.now()}\n")

            shutil.move(src, dst)
            print(f"✅ Printed {filename} to {printer}")

        time.sleep(3)

if __name__ == '__main__':
    main()

