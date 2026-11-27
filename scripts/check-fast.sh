#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test --workspace --locked
python3 -B -m unittest discover -s tests -p 'test_*.py'
python3 scripts/check-dependencies.py
python3 scripts/check-cross-term.py
python3 scripts/check-postgres.py
