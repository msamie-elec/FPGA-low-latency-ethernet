#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python scripts/check_project.py
python scripts/generate_vectors.py
python -m pytest -q tests
mkdir -p build
c++ -std=c++17 -O2 -Wall -Wextra -Werror software/feed_reference.cpp -o build/feed_reference
build/feed_reference < examples/vectors.hex > build/actual.csv
# Compare non-header rows (model expected.csv includes header).
diff -u <(tail -n +2 examples/expected.csv) build/actual.csv
echo 'PASS static checks, Python and C++ reference regression'
