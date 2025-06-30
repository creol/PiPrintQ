# app.py - Flask server for PiPrintQ Dashboard

from flask import Flask, render_template, send_from_directory, jsonify, request, abort
import os
import json
import subprocess
from datetime import datetime

app = Flask(__name__, template_folder='templates')

ARCHIVE_FOLDER = '/home/pi/PrintCompleted'
STATS_FILE = '/home/pi/web_dashboard/stats.json'
ARCHIVE_LOG = '/home/pi/web_dashboard/archive_log.json'
PAUSE_FILE = '/home/pi/web_dashboard/printer_state.json'
ROUND_ROBIN_FILE = '/home/pi/web_dashboard/round_robin.json'
# Uncomment the next line to log lpstat output for debugging
# LPSTAT_LOG_FILE = '/home/pi/web_dashboard/lpstat.log'

os.makedirs(ARCHIVE_FOLDER, exist_ok=True)
if not os.path.exists(ROUND_ROBIN_FILE):
    with open(ROUND_ROBIN_FILE, 'w') as f:
        json.dump({"index": 0}, f)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/files')
def list_files():
    archive = load_json(ARCHIVE_LOG, [])
    archive = sorted(archive, key=lambda x: x['timestamp'], reverse=True)
    return jsonify(archive)

@app.route('/status')
def get_status():
    try:
        output = subprocess.check_output(['systemctl', 'is-active', 'piprintq.service']).decode().strip()
        return jsonify({"status": output})
    except:
        return jsonify({"status": "unknown"})

@app.route('/download/<filename>')
def download_file(filename):
    return send_from_directory(ARCHIVE_FOLDER, filename, as_attachment=True)

@app.route('/download_log/<filename>', methods=['POST'])
def log_download(filename):
    archive = load_json(ARCHIVE_LOG, [])
    for entry in archive:
        if entry['name'] == filename:
            if " - Downloaded" not in entry['name']:
                entry['name'] += " - Downloaded"
            break
    save_json(ARCHIVE_LOG, archive)

    stats = load_json(STATS_FILE, {"reprints": 0, "downloads": 0, "prints_by_printer": {}})
    stats['downloads'] += 1
    save_json(STATS_FILE, stats)
    return '', 204

@app.route('/reprint/<filename>', methods=['POST'])
def reprint_file(filename):
    filepath = os.path.join(ARCHIVE_FOLDER, filename)
    if not os.path.exists(filepath):
        abort(404)

    printer = get_next_printer()
    if not printer:
        return "All printers paused.", 503

    subprocess.run(['lp', '-d', printer, filepath])

    stats = load_json(STATS_FILE, {"reprints": 0, "downloads": 0, "prints_by_printer": {}})
    stats['reprints'] += 1
    stats['prints_by_printer'][printer] = stats['prints_by_printer'].get(printer, 0) + 1
    save_json(STATS_FILE, stats)

    archive = load_json(ARCHIVE_LOG, [])
    archive.append({
        "name": f"{filename} - Reprinted",
        "timestamp": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    })
    save_json(ARCHIVE_LOG, archive)
    return '', 204

@app.route('/stats')
def get_stats():
    stats = load_json(STATS_FILE, {"reprints": 0, "downloads": 0, "prints_by_printer": {}})
    return jsonify(stats)

@app.route('/printer_health')
def printer_health():
    health = {}
    paused = load_json(PAUSE_FILE, {})
    for i in range(1, 11):
        printer = f"Printer{i}"
        try:
            result = subprocess.run(['lpstat', '-p', printer], capture_output=True, text=True)
            output = (result.stdout + result.stderr).lower()
            if 'LPSTAT_LOG_FILE' in globals():
                with open(LPSTAT_LOG_FILE, 'a') as log_f:
                    log_f.write(f"{datetime.now().isoformat()} {printer}: rc={result.returncode} {output.strip()}\n")
            if paused.get(printer) == "paused":
                health[printer] = "yellow"
            elif result.returncode == 0 and "disabled" not in output:
                health[printer] = "green"
            else:
                health[printer] = "red"
        except FileNotFoundError:
            # If lpstat is unavailable, assume printer is active unless paused
            health[printer] = "yellow" if paused.get(printer) == "paused" else "green"
        except Exception:
            health[printer] = "red"
    return jsonify(health)

@app.route('/toggle_pause/<printer>', methods=['POST'])
def toggle_pause(printer):
    paused = load_json(PAUSE_FILE, {})
    if paused.get(printer) == "paused":
        paused.pop(printer)
    else:
        paused[printer] = "paused"
    save_json(PAUSE_FILE, paused)
    return '', 204

@app.route('/delete_all', methods=['POST'])
def delete_all():
    for f in os.listdir(ARCHIVE_FOLDER):
        os.remove(os.path.join(ARCHIVE_FOLDER, f))
    save_json(ARCHIVE_LOG, [])
    return '', 204

def load_json(path, default):
    if not os.path.exists(path): return default
    with open(path) as f:
        return json.load(f)

def save_json(path, data):
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)

def get_next_printer():
    paused = load_json(PAUSE_FILE, {})
    rr = load_json(ROUND_ROBIN_FILE, {"index": 0})
    start = rr.get("index", 0) % 10

    for offset in range(10):
        idx = (start + offset) % 10
        printer = f"Printer{idx+1}"
        if paused.get(printer) == 'paused':
            continue
        rr['index'] = (idx + 1) % 10
        save_json(ROUND_ROBIN_FILE, rr)
        return printer
    return None

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

