"""Independent goldens, deterministic stress vectors and IPv4/UDP checks."""
import binascii
import ipaddress
import struct
from pathlib import Path
from scripts.ethernet_reliability_test import make_records
from scripts.ethernet_tx_vectors import reply_frame, generate
from software.model import decode
from scripts.ethernet_vectors import ip_checksum


def test_stress_is_deterministic():
    assert make_records(150,20261111)==make_records(150,20261111)
    assert make_records(150,7)!=make_records(150,8)
    assert len(make_records(150,7))==150
    assert all(len(x)==16 for x in make_records(150,7))
    # Some deliberately invalid reserved bytes and ignored symbols.
    assert any(x[-2:]!=b'\x00\x00' for x in make_records(150,7))
    assert any(x[1]==2 for x in make_records(150,7))


def test_tx_ip_udp_frame_integrity():
    for payload in (b'I', b'E',b'R'+struct.pack('!IIIB',1,10000,0,0)):
        mii=reply_frame(payload)
        assert len(mii)==72
        assert mii[:8]==b'\x55'*7+b'\xd5'
        f=mii[8:]
        assert f[:6]==b'\xff'*6
        assert f[6:12]==bytes.fromhex('021122334455')
        assert f[12:14]==b'\x08\x00'
        assert binascii.crc32(f[:60])==struct.unpack('<I',f[60:64])[0]
        ip=f[14:34]
        assert ip_checksum(ip)==0
        assert ip[16:20]==ipaddress.IPv4Address('192.168.77.255').packed
        assert ip[12:16]==ipaddress.IPv4Address('192.168.77.2').packed
        assert int.from_bytes(ip[2:4],'big')==28+len(payload)
        assert f[34:36]==struct.pack('!H',5000)
        assert f[36:38]==struct.pack('!H',5001)
        assert int.from_bytes(f[38:40],'big')==8+len(payload)
        assert f[42:42+len(payload)]==payload
        assert f[42+len(payload):60]==bytes(60-42-len(payload))


def test_goldens_generated(tmp_path):
    payloads=generate(tmp_path)
    for name,payload in payloads.items():
        actual=bytes.fromhex((tmp_path/'tests'/'generated'/name).read_text())
        assert actual==reply_frame(payload)
