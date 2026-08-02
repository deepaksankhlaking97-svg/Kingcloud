cat > /root/kingcloud-cloudflare.sh <<'EOF'
#!/bin/bash

# ============================================================
# KINGCLOUD CLOUDFLARE TUNNEL INSTALLER
# ============================================================

PURPLE='\033[38;5;135m'
PINK='\033[38;5;213m'
WHITE='\033[1;37m'
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RESET='\033[0m'

clear

echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════╗"
echo "║          👑 KINGCLOUD CLOUDFLARE             ║"
echo "║             TUNNEL INSTALLER                 ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${RESET}"

echo -e "${CYAN}Cloudflare Tunnel Setup${RESET}"
echo

# ------------------------------------------------------------
# ROOT CHECK
# ------------------------------------------------------------

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run as root.${RESET}"
    echo "Use: sudo bash /root/kingcloud-cloudflare.sh"
    exit 1
fi

# ------------------------------------------------------------
# CLOUDFLARED CHECK
# ------------------------------------------------------------

if ! command -v cloudflared >/dev/null 2>&1; then
    echo -e "${RED}❌ cloudflared is not installed.${RESET}"
    echo
    echo "Install cloudflared first, then run this script again."
    exit 1
fi

echo -e "${GREEN}✓ cloudflared found${RESET}"
cloudflared --version
echo

# ------------------------------------------------------------
# REMOVE OLD CUSTOM SERVICE
# ------------------------------------------------------------

echo -e "${YELLOW}[1/5] Cleaning old Cloudflare service...${RESET}"

systemctl stop cloudflared 2>/dev/null || true
systemctl disable cloudflared 2>/dev/null || true

rm -f /etc/systemd/system/cloudflared.service
rm -f /etc/systemd/system/multi-user.target.wants/cloudflared.service

systemctl daemon-reload

echo -e "${GREEN}✓ Old service cleaned${RESET}"
echo

# ------------------------------------------------------------
# TOKEN
# ------------------------------------------------------------

echo -e "${YELLOW}[2/5] Cloudflare Tunnel Token${RESET}"
echo
echo -e "${WHITE}IMPORTANT:${RESET}"
echo -e "Paste your ${PINK}Cloudflare Tunnel Token${RESET} below."
echo -e "${CYAN}Do NOT paste 'sudo cloudflared service install' here.${RESET}"
echo

read -rsp "🔑 Token: " CF_TOKEN
echo
echo

if [ -z "$CF_TOKEN" ]; then
    echo -e "${RED}❌ Token is empty.${RESET}"
    exit 1
fi

# ------------------------------------------------------------
# INSTALL USING CLOUDFLARED OFFICIAL SERVICE COMMAND
# ------------------------------------------------------------

echo -e "${YELLOW}[3/5] Installing Cloudflare service...${RESET}"

# Install using cloudflared's own service installer.
# Token is passed only to the command and is not written
# into our custom systemd service file.

if ! cloudflared service install "$CF_TOKEN"; then
    echo
    echo -e "${RED}❌ Cloudflare service installation failed.${RESET}"
    echo
    echo -e "${YELLOW}Recent Cloudflare logs:${RESET}"
    journalctl -u cloudflared -n 30 --no-pager 2>/dev/null || true
    exit 1
fi

echo -e "${GREEN}✓ Cloudflare service installed${RESET}"
echo

# ------------------------------------------------------------
# SYSTEMD
# ------------------------------------------------------------

echo -e "${YELLOW}[4/5] Starting Cloudflare Tunnel...${RESET}"

systemctl daemon-reload
systemctl enable cloudflared >/dev/null 2>&1 || true
systemctl restart cloudflared

sleep 4

# ------------------------------------------------------------
# STATUS
# ------------------------------------------------------------

echo -e "${YELLOW}[5/5] Checking connection...${RESET}"
echo

if systemctl is-active --quiet cloudflared; then

    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║       ✅ CLOUDFLARE TUNNEL CONNECTED         ║"
    echo "║              👑 KINGCLOUD                    ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo
    echo -e "${CYAN}Service:${RESET} RUNNING"
    echo -e "${CYAN}Boot:${RESET}    ENABLED"
    echo

    systemctl status cloudflared --no-pager -l

else

    echo -e "${RED}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║        ❌ CLOUDFLARE CONNECTION FAILED       ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo
    echo -e "${YELLOW}Cloudflare error:${RESET}"
    journalctl -u cloudflared -n 50 --no-pager

    echo
    echo -e "${YELLOW}Try:${RESET}"
    echo "systemctl restart cloudflared"
    echo "journalctl -u cloudflared -f"

    exit 1
fi
EOF

chmod +x /root/kingcloud-cloudflare.sh
bash /root/kingcloud-cloudflare.sh
