#!/usr/bin/env bash
# Wireshark Traffic Generator for Mac 1 (Client / DNS)
# Generates clear, easily filtered network events for Wireshark demonstration.

set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

if [ -f "team/team.env" ]; then
    source team/team.env
fi

DOMAIN="${TEAM_DOMAIN:-team1.test}"
MAC1="${MAC1_IP:-10.7.16.225}"
MAC2="${MAC2_IP:-10.7.31.19}"
HOST="app.${DOMAIN}"

echo "=================================================================="
echo "           WIRESHARK LIVE DEMO TRAFFIC GENERATOR"
echo "=================================================================="
echo "  Target Host : $HOST"
echo "  DNS Server  : $MAC1 (Mac 1)"
echo "  Edge Nginx  : $MAC2 (Mac 2: 443)"
echo "=================================================================="
echo ""
echo "Ensure Wireshark is capturing on interface: en0"
echo "Filter: ip.addr == $MAC2 || ip.addr == $MAC1"
echo ""
read -p "Press [Enter] when Wireshark capture is started..."
echo ""

echo "[1/4] Generating DNS Query/Response (UDP Port 53)..."
echo "  Command: dig @$MAC1 $HOST +short"
dig "@$MAC1" "$HOST" +short
echo "  -> Wireshark filter: dns.qry.name contains \"${DOMAIN}\""
echo ""
sleep 2

echo "[2/4] Generating TCP 3-Way Handshake & TLS 1.2 Handshake (Port 443)..."
echo "  Command: curl --tlsv1.2 --tls-max 1.2 -s https://$HOST/api/status"
curl --tlsv1.2 --tls-max 1.2 -s "https://$HOST/api/status"
echo ""
echo "  -> Wireshark filter: ip.addr == $MAC2 && (tcp.flags.syn == 1 || tls.handshake.type == 1)"
echo ""
sleep 2

echo "[3/4] Generating Modern TLS 1.3 & HTTP/2 Traffic..."
echo "  Command: curl --http2 -s https://$HOST/api/status"
curl --http2 -s "https://$HOST/api/status"
echo ""
echo "  -> Wireshark filter: ip.addr == $MAC2 && http2"
echo ""
sleep 2

echo "[4/4] Generating HTTP Caching (304 Not Modified)..."
echo "  Command: curl -si -H 'If-None-Match: \"cn-cache-v1\"' https://$HOST/api/cache"
curl -si -H 'If-None-Match: "cn-cache-v1"' "https://$HOST/api/cache" | head -n 8
echo ""
echo "=================================================================="
echo "  Traffic generation finished! You can now stop the capture in Wireshark."
echo "=================================================================="
