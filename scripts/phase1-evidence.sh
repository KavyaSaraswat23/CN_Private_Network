#!/usr/bin/env bash
# Phase 1 evidence run (Mac 1). Runs each task's verification commands in turn and pauses
# so each screen can be captured. Output is also saved to evidence/phase_1/terminal-output.txt
#
# Usage:
#   ./scripts/phase1-evidence.sh                # Run all tasks (A-G) with 10s pause
#   ./scripts/phase1-evidence.sh 0              # Run all tasks instantly (no pause)
#   ./scripts/phase1-evidence.sh 5 B D E        # Run tasks B, D, E with 5s pause
#   ./scripts/phase1-evidence.sh C E            # Run tasks C and E with default 10s pause

set -u
cd "$(dirname "$0")/.." || exit 1

# Source team.env if available
if [ -f "team/team.env" ]; then
    # shellcheck disable=SC1091
    source team/team.env
fi

# Configuration defaults
TEAM_DOMAIN="${TEAM_DOMAIN:-team1.test}"
MAC1_IP="${MAC1_IP:-10.7.16.225}"
MAC2_IP="${MAC2_IP:-10.7.31.19}"
MAC3_IP="${MAC3_IP:-10.7.16.178}"
MAC4_IP="${MAC4_IP:-10.7.2.18}"

BACKEND_A="${MAC3_IP}:3001"
BACKEND_B="${MAC4_IP}:3002"
D="app.${TEAM_DOMAIN}"

# Parse pause duration and tasks
P=10
if [[ $# -gt 0 && "$1" =~ ^[0-9]+$ ]]; then
    P="$1"
    shift
fi

TASKS="${*:-A B C D E F G}"

OUT_DIR="evidence/phase_1"
mkdir -p "$OUT_DIR"
OUT="${OUT_DIR}/terminal-output.txt"
: > "$OUT"

sec() {
    clear
    echo "=================================================================="
    echo "  $1"
    echo "=================================================================="
    echo ""
    echo "=== $1 ===" >> "$OUT"
}

run() {
    echo -e "\033[1;32m\$ $*\033[0m"
    echo "\$ $*" >> "$OUT"
    eval "$*" 2>&1 | tee -a "$OUT"
    echo ""
}

hold() {
    if [ "$P" -gt 0 ]; then
        echo -e "\033[1;33m[Holding for ${P}s - capture screenshot now, or press Enter to continue]...\033[0m"
        read -r -t "$P" || true
        echo ""
    fi
}

echo "Starting Phase 1 Evidence Collection for domain: $D"
echo "Tasks selected: $TASKS"
echo "Output log: $OUT"
sleep 1

# -------------------------------------------------------------
# TASK A: Private LAN
# -------------------------------------------------------------
if [[ " $TASKS " =~ [[:space:]]A[[:space:]] ]]; then
    sec "Task A: Private LAN Network & Interface Verification"
    run "ipconfig getifaddr en0"
    run "ifconfig en0 | grep -E 'inet |ether'"
    run "route -n get default | grep -E 'gateway|interface'"
    run "ping -c 2 -W 1000 $MAC2_IP"
    run "ping -c 2 -W 1000 $MAC3_IP"
    run "ping -c 2 -W 1000 $MAC4_IP"
    hold
fi

# -------------------------------------------------------------
# TASK B: Private DNS Resolution
# -------------------------------------------------------------
if [[ " $TASKS " =~ [[:space:]]B[[:space:]] ]]; then
    sec "Task B: Private DNS Resolution & Public Isolation"
    echo "-- 1. macOS Resolver resolution (expect $MAC2_IP) --"
    run "dig $D +short"
    echo "-- 2. Direct query to local dnsmasq --"
    run "dig @$MAC1_IP $D"
    echo "-- 3. API domain query --"
    run "dig @$MAC1_IP api.${TEAM_DOMAIN} +short"
    echo "-- 4. Check DNS TTL (expect 30s) --"
    run "dig @$MAC1_IP $D | grep -E ';; ANSWER SECTION:|app\.'"
    echo "-- 5. Public DNS Isolation Check (expect NXDOMAIN / timeout) --"
    run "dig @8.8.8.8 $D | grep -E 'status:|ANSWER:'"
    hold
fi

# -------------------------------------------------------------
# TASK C: Direct Backends (Bypassing Edge)
# -------------------------------------------------------------
if [[ " $TASKS " =~ [[:space:]]C[[:space:]] ]]; then
    sec "Task C: Direct Backend Access (Mac 3 & Mac 4)"
    echo "-- Backend A direct ($BACKEND_A) --"
    run "curl --connect-timeout 3 -si http://$BACKEND_A/api/status | grep -E 'HTTP|X-Backend|backend'"
    echo "-- Backend B direct ($BACKEND_B) --"
    run "curl --connect-timeout 3 -si http://$BACKEND_B/api/status | grep -E 'HTTP|X-Backend|backend'"
    hold
fi

# -------------------------------------------------------------
# TASK D: Round-Robin Load Balancing
# -------------------------------------------------------------
if [[ " $TASKS " =~ [[:space:]]D[[:space:]] ]]; then
    sec "Task D: Round-Robin Load Balancing (6 Sequential Requests)"
    run "for i in 1 2 3 4 5 6; do echo -n \"Request \$i: \"; curl -s --connect-timeout 3 https://$D/api/status | grep -o '\"backend\":\"[^\"]*\"'; done"
    echo ""
    echo "-- Check X-Backend Header Distribution --"
    run "for i in 1 2 3 4; do curl -sI --connect-timeout 3 https://$D/api/status | grep -i 'x-backend'; done"
    hold
fi

# -------------------------------------------------------------
# TASK E: Trusted HTTPS & HTTP Protocols
# -------------------------------------------------------------
if [[ " $TASKS " =~ [[:space:]]E[[:space:]] ]]; then
    sec "Task E: Trusted HTTPS (TLS 1.3 / HTTP/2 - No -k Flag)"
    echo "-- 1. TLS Handshake & Certificate Verification --"
    run "curl -sv --connect-timeout 3 https://$D/api/status 2>&1 | grep -E 'Connected to|TLSv|ALPN|subject:|issuer:|SSL certificate verify ok|HTTP/'"
    echo "-- 2. Protocol HTTP/1.1 Negotiation --"
    run "curl --http1.1 -sI --connect-timeout 3 https://$D/api/status | head -n 5"
    echo "-- 3. Protocol HTTP/2 Negotiation --"
    run "curl --http2 -sI --connect-timeout 3 https://$D/api/status | head -n 5"
    hold
fi

# -------------------------------------------------------------
# TASK F: HTTP Caching & Conditional Requests
# -------------------------------------------------------------
if [[ " $TASKS " =~ [[:space:]]F[[:space:]] ]]; then
    sec "Task F: HTTP Caching & Conditional GET"
    echo "-- 1. Initial Request (verify Cache-Control & ETag) --"
    run "curl -sI --connect-timeout 3 https://$D/api/cache | grep -iE 'HTTP/|etag|cache-control'"
    echo "-- 2. Conditional Request with matching ETag (expect HTTP 304 Not Modified) --"
    run "curl -si --connect-timeout 3 -H 'If-None-Match: \"cn-cache-v1\"' https://$D/api/cache | head -n 8"
    hold
fi

# -------------------------------------------------------------
# TASK G: Packet Capture Traffic Verification
# -------------------------------------------------------------
if [[ " $TASKS " =~ [[:space:]]G[[:space:]] ]]; then
    sec "Task G: Packet Capture Traffic Verification"
    echo "-- 1. Resolve host --"
    run "dig $D +short"
    echo "-- 2. TLS 1.2 Handshake & Response --"
    run "curl --tlsv1.2 --tls-max 1.2 -sv --connect-timeout 3 https://$D/api/status 2>&1 | grep -E 'Connected to|TLSv|HTTP/|X-Backend|backend'"
    hold
fi

echo "=================================================================="
echo "  Evidence collection complete!"
echo "  Log saved to: $OUT"
echo "=================================================================="
