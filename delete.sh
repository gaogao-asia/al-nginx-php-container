#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# Keep certificates and the shared external database network. Never use down -v here.
docker compose down
