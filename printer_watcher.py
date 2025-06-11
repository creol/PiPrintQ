# File: printer_watcher.py
import os
import shutil
import time
import subprocess
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

WATCH_FOLDER = '/home/pi/PrintQueue'
COMPLETED_FOLDER = '/home/pi/PrintCompleted'
PRINTERS = [f'Printer{i}' for i in range(1, 11)]

def print_file(filepath):
    for printer in PRINTERS:
        try:
            result = subprocess.run(['lp', '-d', printer, filepath], capture_output=True, text=True)
            if result.returncode == 0:
                print(f"Printed {filepath} on {printer}")
                return True
            else:
                print(f"Failed on {printer}: {result.stderr.strip()}")
        except Exception as e:
            print(f"Exception on {printer}: {e}")
    return False

class PDFHandler(FileSystemEventHandler):
    def on_created(self, event):
        if not event.is_directory and event.src_path.lower().endswith('.pdf'):
            time.sleep(1)  # Ensure file is done writing
            success = print_file(event.src_path)
            if success:
                shutil.move(event.src_path, os.path.join(COMPLETED_FOLDER, os.path.basename(event.src_path)))

if __name__ == '__main__':
    os.makedirs(WATCH_FOLDER, exist_ok=True)
    os.makedirs(COMPLETED_FOLDER, exist_ok=True)
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
