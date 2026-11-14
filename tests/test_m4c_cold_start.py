"""Host-only M4C first-burst test checks. No serial hardware required."""
import json
from pathlib import Path
import struct
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from m4c_cold_start import COLUMNS, acquire, make_session, write_summary


class FakePort:
    def __init__(self, payload):
        self.payload = payload
        self.sent = []
        self.in_waiting = 0

    def read(self, n):
        return self.payload[:n]

    def reset_input_buffer(self):
        pass

    def write(self, data):
        self.sent.append(data)

    def flush(self):
        pass


def response(profile='C', unique=1000):
    return struct.pack('>4s9I', b'B' + profile.encode() + b'\x01\x00',
                       1000, unique, 0, 0, 0, 0, 1000, 1000, 999000)


def test_first_burst_pass():
    port = FakePort(response())
    row = acquire(port, cycle=1, mode='reset', phase='first', profile='C')
    assert row['status'] == 'PASS'
    assert row['missing'] == 0
    assert row['uart_bytes'] == 40
    assert port.sent == [b'C']
    assert set(row) == set(COLUMNS)


def test_loss_remains_a_failure():
    row = acquire(FakePort(response(unique=0)), cycle=1, mode='reset',
                  phase='first', profile='C')
    assert row['status'] == 'FAIL'
    assert row['missing'] == 1000


def test_truncated_telemetry_is_recorded_without_retry():
    port = FakePort(b'')
    row = acquire(port, cycle=1, mode='reset', phase='first', profile='C')
    assert row['status'] == 'ERROR'
    assert row['uart_bytes'] == 0
    assert 'Expected 40 UART bytes' in row['error']
    assert port.sent == [b'C']


def test_new_session_and_summary(tmp_path):
    session = make_session(tmp_path)
    assert session.is_dir()
    row = acquire(FakePort(response()), cycle=1, mode='reset',
                  phase='first', profile='C')
    path = session / 'summary.json'
    write_summary(path, mode='reset', profile='C', rows=[row], completed=True)
    summary = json.loads(path.read_text())
    assert summary['first_run_passes'] == 1
    assert summary['first_run_trials'] == 1
    assert summary['completed'] is True
