// SPDX-License-Identifier: MIT
// Standalone software oracle. Input: one 16-byte hex record per line.
// Output CSV: sequence,bid,ask,signal for accepted target-symbol updates.
#include <cstdint>
#include <iostream>
#include <optional>
#include <string>
#include <stdexcept>

static uint32_t be32(const std::string& s, std::size_t offset) {
    uint32_t v = 0;
    for (std::size_t k = 0; k < 4; ++k)
        v = (v << 8) | static_cast<unsigned char>(s.at(offset + k));
    return v;
}
static int hex_digit(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    throw std::invalid_argument("invalid hex character");
}
static std::string unhex(const std::string& h) {
    if (h.size() != 32) throw std::invalid_argument("expected 32 hexadecimal characters");
    std::string s;
    for (std::size_t i = 0; i < h.size(); i += 2)
        s.push_back(static_cast<char>((hex_digit(h[i]) << 4) | hex_digit(h[i+1])));
    return s;
}
int main() {
    std::optional<uint32_t> bid, ask;
    std::string line;
    unsigned errors = 0;
    while (std::getline(std::cin, line)) {
        try {
            const std::string r = unhex(line);
            const auto ty = static_cast<unsigned char>(r[0]);
            if ((ty != 'A' && ty != 'B') || r[14] != 0 || r[15] != 0)
                throw std::invalid_argument("invalid type or reserved bytes");
            const auto sym = static_cast<unsigned char>(r[1]);
            const uint32_t seq = be32(r, 2), price = be32(r, 6), qty = be32(r, 10);
            if (sym != 1 || qty == 0) continue;
            if (ty == 'B') bid = price; else ask = price;
            const bool signal = bid && ask && (*ask > *bid) && ((*ask - *bid) <= 5u);
            std::cout << seq << ',' << bid.value_or(0) << ',' << ask.value_or(0)
                      << ',' << (signal ? 1 : 0) << '\n';
        } catch (const std::exception&) {
            ++errors;
        }
    }
    std::cerr << "Rejected records: " << errors << '\n';
}
