#!/usr/bin/env bash
set -u

PEER_NAME="${1:-axonvertex-01}"
PEER_IP="${2:-100.82.103.57}"
MODEL_PORT="${3:-18181}"

echo "== WSL release =="
uname -a

echo
echo "== Resolver =="
cat /etc/resolv.conf

echo
echo "== MagicDNS resolution =="
getent hosts "$PEER_NAME" || echo "WARN: MagicDNS name did not resolve in WSL."

echo
echo "== IP reachability =="
ping -c 2 "$PEER_IP" || true

echo
echo "== SSH port =="
nc -vz -w 5 "$PEER_IP" 22 || true

echo
echo "== Model port =="
nc -vz -w 5 "$PEER_IP" "$MODEL_PORT" || true

echo
echo "If Windows and WSL both run Tailscale, stop one of them and repeat this test."
