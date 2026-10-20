#!/usr/bin/env bash
set -euo pipefail
runtime_dir=$(mktemp -d)
trap 'rm -rf "$runtime_dir"' EXIT
chmod 700 "$runtime_dir"
export XDG_RUNTIME_DIR="$runtime_dir"
export PYTHONPYCACHEPREFIX="$runtime_dir/pycache"
export FUTBAR_SHELL_ROOT=${FUTBAR_SHELL_ROOT:-/opt/omarchy/shell}
test -d "$FUTBAR_SHELL_ROOT/Ui"
dbus-run-session -- cage -- python3 ci/run-tests.py
node tests/test_security.js
python3 -m compileall -q lib tests
