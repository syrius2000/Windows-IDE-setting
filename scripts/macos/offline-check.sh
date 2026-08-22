#!/usr/bin/env bash
# ==============================================================================
# offline-check.sh - Pre-flight Offline & Air-Gap Verification Script
# ==============================================================================
set -euo pipefail

echo "========================================================"
echo "  macOS Pre-flight Offline Verification"
echo "  Checking network isolation for sensitive RWD/OCR..."
echo "========================================================"

ONLINE_ISSUES=0

# 1. Check Outbound Internet Connectivity (ICMP / IP)
echo "[1/5] Testing outbound internet connectivity..."
if ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1 || ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1; then
    echo "  [⚠️] ACTIVE INTERNET DETECTED: Outbound ping succeeded."
    ONLINE_ISSUES=$(( ONLINE_ISSUES + 1 ))
else
    echo "  [✓] Outbound Internet: DISCONNECTED (Ping failed as expected)."
fi

# 2. Check DNS Resolution
echo "[2/5] Testing DNS name resolution..."
if host -W 1 api.openai.com >/dev/null 2>&1 || host -W 1 github.com >/dev/null 2>&1; then
    echo "  [⚠️] ACTIVE DNS DETECTED: Public domains are resolvable."
    ONLINE_ISSUES=$(( ONLINE_ISSUES + 1 ))
else
    echo "  [✓] DNS Resolution: INACTIVE (No public names resolved)."
fi

# 3. Check Active Network Interfaces (Wi-Fi, Ethernet, Thunderbolt)
echo "[3/5] Checking active network interfaces..."
ACTIVE_IFACES=$(ifconfig 2>/dev/null | awk '/^[a-z0-9]+:/{iface=$1} /status: active/{print iface}' | tr -d ':')
if [[ -n "$ACTIVE_IFACES" ]]; then
    echo "  [⚠️] ACTIVE INTERFACES DETECTED: $ACTIVE_IFACES"
    ONLINE_ISSUES=$(( ONLINE_ISSUES + 1 ))
else
    echo "  [✓] Network Interfaces: No active external interfaces detected."
fi

# 4. Check Outbound Established Sockets
echo "[4/5] Checking established TCP/UDP sockets..."
ACTIVE_SOCKETS=$(netstat -an -f inet 2>/dev/null | grep ESTABLISHED | grep -v "127.0.0.1" || true)
if [[ -n "$ACTIVE_SOCKETS" ]]; then
    echo "  [⚠️] ESTABLISHED EXTERNAL SOCKETS DETECTED:"
    echo "$ACTIVE_SOCKETS" | head -n 5
    ONLINE_ISSUES=$(( ONLINE_ISSUES + 1 ))
else
    echo "  [✓] Active Sockets: No external established connections."
fi

# 5. Check Cloud Sync Processes & Daemons
echo "[5/5] Checking cloud synchronization daemons..."
SYNC_PROCS=("Dropbox" "OneDrive" "Google Drive" "kbfsfuse" "Box" "bird")
for proc in "${SYNC_PROCS[@]}"; do
    if pgrep -f "$proc" >/dev/null 2>&1; then
        echo "  [⚠️] Cloud sync process running: $proc"
        ONLINE_ISSUES=$(( ONLINE_ISSUES + 1 ))
    fi
done

echo -e "\n========================================================"
if [[ $ONLINE_ISSUES -eq 0 ]]; then
    echo "  [✓] OFFLINE STATUS: SAFE TO PROCEED"
    echo "  All network interfaces, sockets, and sync daemons are disconnected."
    echo "========================================================"
    exit 0
else
    echo "  [⚠️] OFFLINE STATUS: WARNING ($ONLINE_ISSUES network/sync triggers detected)"
    echo "  Please disconnect Wi-Fi/Ethernet before processing un-anonymized data."
    echo "========================================================"
    exit 1
fi
