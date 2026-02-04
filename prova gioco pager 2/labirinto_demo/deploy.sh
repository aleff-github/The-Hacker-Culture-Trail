#!/usr/bin/env bash
# Deploy rapido del payload sul WiFi Pineapple Pager
# Uso:
#   ./deploy.sh 172.16.52.1
# oppure:
#   PAGER_HOST=172.16.52.1 ./deploy.sh
set -euo pipefail

HOST="${1:-${PAGER_HOST:-172.16.52.1}}"
USER="${PAGER_USER:-root}"

DEST="/root/payloads/user/games/labirinto_demo"

echo "Deploy verso ${USER}@${HOST}:${DEST}"
ssh "${USER}@${HOST}" "mkdir -p '${DEST}'"
scp -q ./payload.sh ./story.tsv "${USER}@${HOST}:${DEST}/"
ssh "${USER}@${HOST}" "chmod +x '${DEST}/payload.sh'"
echo "OK. Log: /root/loot/labirinto_librogame_debug.log"
