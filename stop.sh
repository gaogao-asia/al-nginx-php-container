#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ -f .parallel-wp80-active ]]; then
    echo 'Parallel WordPress mode is selected. Use start_parallel_wp80.sh or stop_parallel_wp80.sh first.' >&2
    exit 1
fi
docker compose stop
