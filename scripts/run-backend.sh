#!/bin/bash
# 4-Mac setup:
#   Mac 3  →  ./run-backend.sh A   (Backend A, port 3001)
#   Mac 4  →  ./run-backend.sh B   (Backend B, port 3001)
#
# Each backend Mac runs ONE instance.  Both listen on port 3001 so that
# nginx can use the same port for both upstream servers.
set -e
ID="$1"
if [ "$ID" = "A" ]; then
    PORT=3001
elif [ "$ID" = "B" ]; then
    PORT=3002   # Mac 4 runs Backend B on port 3002
else
    echo "Usage: $0 A|B"
    exit 1
fi

cd "$(dirname "$0")/../backend"
python3 -m venv .venv 2>/dev/null || true
source .venv/bin/activate
pip install -q -r requirements.txt
BACKEND_ID="$ID" PORT="$PORT" python3 app.py
