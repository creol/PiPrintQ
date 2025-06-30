import json
import tempfile
import os
import pytest

os.makedirs('/home/pi/web_dashboard', exist_ok=True)

import app as flask_app

@pytest.fixture
def client():
    flask_app.app.config['TESTING'] = True
    with flask_app.app.test_client() as client:
        yield client

def test_status_returns_json(client, monkeypatch):
    monkeypatch.setattr(flask_app.subprocess, 'check_output', lambda *a, **k: b'active')
    resp = client.get('/status')
    assert resp.status_code == 200
    data = resp.get_json()
    assert data == {"status": "active"}

def test_files_returns_list(client, monkeypatch, tmp_path):
    archive_file = tmp_path / 'archive.json'
    file_list = [{"name": "test.gcode", "timestamp": "2024-01-01 00:00:00"}]
    archive_file.write_text(json.dumps(file_list))
    monkeypatch.setattr(flask_app, 'ARCHIVE_LOG', str(archive_file))
    resp = client.get('/files')
    assert resp.status_code == 200
    data = resp.get_json()
    assert isinstance(data, list)
    assert data == file_list


def _mock_lpstat(output, returncode=0):
    class Result:
        def __init__(self, out, code):
            self.stdout = out
            self.stderr = ''
            self.returncode = code
    def run(args, capture_output=True, text=True):
        return Result(output.format(printer=args[-1]), returncode)
    return run


def test_printer_health_enabled(client, monkeypatch):
    monkeypatch.setattr(flask_app.subprocess, 'run', _mock_lpstat('printer {printer} is idle. enabled since now'))
    monkeypatch.setattr(flask_app, 'load_json', lambda *a, **k: {})
    resp = client.get('/printer_health')
    assert resp.status_code == 200
    data = resp.get_json()
    assert data['Printer1'] == 'green'


def test_printer_health_disabled(client, monkeypatch):
    monkeypatch.setattr(flask_app.subprocess, 'run', _mock_lpstat('printer {printer} disabled since now'))
    monkeypatch.setattr(flask_app, 'load_json', lambda *a, **k: {})
    resp = client.get('/printer_health')
    assert resp.status_code == 200
    data = resp.get_json()
    assert data['Printer1'] == 'red'


def test_printer_health_paused(client, monkeypatch):
    monkeypatch.setattr(flask_app.subprocess, 'run', _mock_lpstat('printer {printer} is idle. enabled since now'))
    monkeypatch.setattr(flask_app, 'load_json', lambda *a, **k: {'Printer1': 'paused'})
    resp = client.get('/printer_health')
    assert resp.status_code == 200
    data = resp.get_json()
    assert data['Printer1'] == 'yellow'


def test_printer_health_logs_lpstat(client, monkeypatch, tmp_path):
    log_file = tmp_path / 'lpstat.log'
    monkeypatch.setattr(flask_app, 'LPSTAT_LOG_FILE', str(log_file), raising=False)
    monkeypatch.setattr(flask_app.subprocess, 'run', _mock_lpstat('printer {printer} is idle. enabled since now'))
    monkeypatch.setattr(flask_app, 'load_json', lambda *a, **k: {})
    resp = client.get('/printer_health')
    assert resp.status_code == 200
    assert log_file.exists()
    lines = log_file.read_text().splitlines()
    assert any('Printer1:' in line for line in lines)
