#!/bin/sh
set -eu

quint=${QUINT:-quint}
model=$(CDPATH= cd -- "$(dirname "$0")" && pwd)/protocol.qnt
tmp=$(mktemp -d "${TMPDIR:-/tmp}/rockstream-g03-count.XXXXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
python3 - "$model" "$tmp/protocol.qnt" <<'PY'
from pathlib import Path
import sys

model = Path(sys.argv[1]).read_text()
if not model.endswith('}\n') or '  var depth:' in model:
    raise SystemExit('unexpected model structure')
extension = '''  var depth: int
  action bounded_init = all { init, depth' = 0 }
  action bounded_step = all { depth < 3, step, depth' = depth + 1 }
'''
Path(sys.argv[2]).write_text(model[:-2] + extension + '}\n')
PY
printf '%s\n' '{"maxHeap":"-Xmx512m","stackSize":"-Xss8m","workers":1}' > "$tmp/tlc-config.json"
"$quint" verify "$tmp/protocol.qnt" --backend tlc --server-endpoint "localhost:${G03_TLC_PORT:-18822}" \
  --init bounded_init --step bounded_step \
  --invariants publication fencing_and_outcomes gc \
  --tlc-config "$tmp/tlc-config.json" --verbosity 3
