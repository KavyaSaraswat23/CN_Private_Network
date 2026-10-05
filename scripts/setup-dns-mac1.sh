#!/bin/bash
# Run once on Mac 1 (DNS server) to apply the dnsmasq config and macOS resolver.
# Usage: sudo ./scripts/setup-dns-mac1.sh
set -e

DNSMASQ_CONF=/opt/homebrew/etc/dnsmasq.conf
RESOLVER_DIR=/etc/resolver
DOMAIN=team1.test
MAC1_IP=10.7.16.225   # this Mac (DNS)
MAC2_IP=10.7.31.19    # Mac 2 (nginx edge)

echo "[1/3] Writing $DNSMASQ_CONF ..."
cat > "$DNSMASQ_CONF" << EOF
# dnsmasq config for Mac 1 — Private DNS Server
# 4-Mac setup: Mac1=DNS, Mac2=Edge(nginx), Mac3=Backend-A, Mac4=Backend-B

listen-address=127.0.0.1,${MAC1_IP}
bind-interfaces
domain-needed
bogus-priv
no-resolv
no-poll
server=8.8.8.8

# Private domain records — both point to Mac 2 (nginx edge)
address=/app.${DOMAIN}/${MAC2_IP}
address=/api.${DOMAIN}/${MAC2_IP}
address=/app.teamX.test/${MAC2_IP}
address=/api.teamX.test/${MAC2_IP}

# Short TTL for DNS TTL demo (Extension B)
local-ttl=30

# Query logging (useful as evidence)
log-queries
log-facility=/tmp/dnsmasq.log
EOF
echo "    Done."

echo "[2/3] Creating /etc/resolver/${DOMAIN} and /etc/resolver/teamX.test ..."
mkdir -p "$RESOLVER_DIR"
echo "nameserver 127.0.0.1" > "$RESOLVER_DIR/$DOMAIN"
echo "nameserver 127.0.0.1" > "$RESOLVER_DIR/teamX.test"
echo "    Done."

echo "[3/3] Restarting dnsmasq + flushing DNS cache ..."
brew services restart dnsmasq
dscacheutil -flushcache
killall -HUP mDNSResponder 2>/dev/null || true
echo "    Done."

echo ""
echo "=== Verification ==="
echo "-- /opt/homebrew/etc/dnsmasq.conf --"
cat "$DNSMASQ_CONF"
echo ""
echo "-- /etc/resolver/${DOMAIN} --"
cat "$RESOLVER_DIR/$DOMAIN"
echo ""
sleep 1
echo "-- dig @127.0.0.1 app.${DOMAIN} +short (expect ${MAC2_IP}) --"
dig @127.0.0.1 "app.${DOMAIN}" +short
