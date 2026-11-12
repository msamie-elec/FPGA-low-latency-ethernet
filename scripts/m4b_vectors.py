"""Reference M4B back-to-back frame vectors, built independently in Python."""
from pathlib import Path
from m2c_vectors import build_frame, record_for_command

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "tests" / "generated"
OUT.mkdir(parents=True, exist_ok=True)

def vectors():
    commands = ['S'] * 20 + ['I', 'E']
    data = bytearray()
    for i, command in enumerate(commands, start=1):
        frame = build_frame(record_for_command(command, i), from_a=True)
        if len(frame) != 72:
            raise RuntimeError(f'Unexpected length {len(frame)}')
        data.extend(frame)
    bad = bytearray(build_frame(record_for_command('S', 23), from_a=True))
    bad[-1] ^= 0x80
    return bytes(data), bytes(bad)

def main():
    stream, bad = vectors()
    (OUT / 'm4b_22_frames.hex').write_text(''.join(f'{b:02x}\n' for b in stream))
    (OUT / 'm4b_bad_fcs.hex').write_text(''.join(f'{b:02x}\n' for b in bad))
    print('PASS generated 22 independent 72-byte frames (20 report, ignored, error), plus invalid CRC')

if __name__ == '__main__':
    main()
