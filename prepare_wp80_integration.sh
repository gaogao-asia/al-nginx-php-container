#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
[[ $# == 1 ]] || { echo "Usage: $0 /absolute/path/to/source-wordpress" >&2; exit 1; }
set -a; source .env; set +a
/usr/bin/python3 files/wp80-integration/prepare.py "$1"
