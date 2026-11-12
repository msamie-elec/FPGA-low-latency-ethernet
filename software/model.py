"""Reference model for the 16-byte synthetic feed protocol (NOT an exchange protocol)."""
from dataclasses import dataclass

RECORD_SIZE = 16
TARGET_SYMBOL = 1
THRESHOLD = 5

@dataclass(frozen=True)
class Update:
    side: str
    symbol: int
    sequence: int
    price: int
    quantity: int


def encode(side: str, symbol: int, sequence: int, price: int, quantity: int,
           reserved: bytes = b"\x00\x00") -> bytes:
    if side not in ("A", "B"):
        raise ValueError("side must be A (ask) or B (bid)")
    if not 0 <= symbol <= 255:
        raise ValueError("symbol outside u8")
    if len(reserved) != 2:
        raise ValueError("reserved field must be two bytes")
    for value in (sequence, price, quantity):
        if not 0 <= value < (1 << 32):
            raise ValueError("integer outside u32")
    return (side.encode('ascii') + bytes([symbol]) + sequence.to_bytes(4, 'big') +
            price.to_bytes(4, 'big') + quantity.to_bytes(4, 'big') + reserved)


def decode(record: bytes) -> Update:
    if len(record) != RECORD_SIZE:
        raise ValueError("record must have exactly 16 bytes")
    if record[0] not in (ord('A'), ord('B')) or record[-2:] != b"\x00\x00":
        raise ValueError("invalid type or nonzero reserved field")
    return Update(chr(record[0]), record[1], int.from_bytes(record[2:6], 'big'),
                  int.from_bytes(record[6:10], 'big'),
                  int.from_bytes(record[10:14], 'big'))


class TopOfBook:
    def __init__(self, symbol=TARGET_SYMBOL, threshold=THRESHOLD):
        self.symbol = symbol
        self.threshold = threshold
        self.bid = None
        self.ask = None

    def push(self, update: Update):
        if update.symbol != self.symbol or update.quantity == 0:
            return None
        if update.side == 'B':
            self.bid = update.price
        else:
            self.ask = update.price
        signal = (self.bid is not None and self.ask is not None
                  and self.ask > self.bid and self.ask - self.bid <= self.threshold)
        return (update.sequence, self.bid or 0, self.ask or 0, int(signal))


def process(records, symbol=TARGET_SYMBOL, threshold=THRESHOLD):
    book = TopOfBook(symbol, threshold)
    reports, errors = [], 0
    for record in records:
        try:
            event = decode(record)
        except ValueError:
            errors += 1
            continue
        report = book.push(event)
        if report is not None:
            reports.append(report)
    return reports, errors
