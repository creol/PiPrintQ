import json
import tempfile
import os
import pytest

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
