# File: printer_watcher.py
import os
import shutil
import time
import subprocess
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import json
from datetime import datetime

WATCH_FOLDER = '/home/pi/PrintQueue'
COMPLETED_FOLDER = '/home/pi/PrintCompleted'
STATS_FILE = '/home/pi/web_dashboard/stats.json'
ARCHIVE_LOG = '/home/pi/web_dashboard/archive_log.json'
PAUSE_FILE = '/home/pi/web_dashboard/printer_state.json'
ROUND_ROBIN_FILE = '/home/pi/web_dashboard/round_robin.json'

PRINTERS = [f'Printer{i}' for i in range(1, 11)]


def load_json(path, default):
    if not os.path.exists(path):
        return default
    with open(path) as f:
        return json.load(f)


def save_json(path, data):
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)

def print_file(filepath):
    """Send the PDF to an available printer using round robin.

    Returns the printer used on success or ``None`` on failure.
    """
    paused = load_json(PAUSE_FILE, {})
    rr = load_json(ROUND_ROBIN_FILE, {"index": 0})
    start = rr.get("index", 0) % len(PRINTERS)

    for offset in range(len(PRINTERS)):
        idx = (start + offset) % len(PRINTERS)
        printer = PRINTERS[idx]
        if paused.get(printer) == "paused":
            continue
        try:
            result = subprocess.run(['lp', '-d', printer, filepath], capture_output=True, text=True)
            if result.returncode == 0:
                rr['index'] = (idx + 1) % len(PRINTERS)
                save_json(ROUND_ROBIN_FILE, rr)
                print(f"Printed {filepath} on {printer}")
                return printer
            else:
                print(f"Failed on {printer}: {result.stderr.strip()}")
        except Exception as e:
            print(f"Exception on {printer}: {e}")
    return None

class PDFHandler(FileSystemEventHandler):
    def on_created(self, event):
        if not event.is_directory and event.src_path.lower().endswith('.pdf'):
            time.sleep(1)  # Ensure file is done writing
            printer = print_file(event.src_path)
            if printer:
                filename = os.path.basename(event.src_path)
                shutil.move(event.src_path, os.path.join(COMPLETED_FOLDER, filename))

                # Update stats.json
                stats = load_json(STATS_FILE, {"reprints": 0, "downloads": 0, "prints_by_printer": {}})
                stats.setdefault("prints_by_printer", {})
                stats["prints_by_printer"][printer] = stats["prints_by_printer"].get(printer, 0) + 1
                save_json(STATS_FILE, stats)

                # Update archive_log.json
                archive = load_json(ARCHIVE_LOG, [])
                archive.append({
                    "name": filename,
                    "timestamp": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                })
                save_json(ARCHIVE_LOG, archive)

if __name__ == '__main__':
    os.makedirs(WATCH_FOLDER, exist_ok=True)
    os.makedirs(COMPLETED_FOLDER, exist_ok=True)
    if not os.path.exists(ROUND_ROBIN_FILE):
        save_json(ROUND_ROBIN_FILE, {"index": 0})
    observer = Observer()
    observer.schedule(PDFHandler(), path=WATCH_FOLDER, recursive=False)
    observer.start()
    print(f"Watching folder: {WATCH_FOLDER}")
    try:
        while True:
            time.sleep(10)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
