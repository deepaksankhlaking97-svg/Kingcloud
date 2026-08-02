cat > /root/fix-cloudflare.sh <<'EOF'
#!/bin/bash

set -e

echo "======================================"
echo " Cloudflare Tunnel Service Fix"
echo "======================================"

if ! command -v cloudflared >/dev/null 2>&1; then
    echo "❌ cloudflared command nahi mila."
    exit 1
fi

echo
echo "cloudflared:"
cloudflared --version

echo
read -rsp "🔑 Cloudflare Tunnel Token paste karo: " TOKEN
echo

if [ -z "$TOKEN" ]; then
    echo "❌ Token empty hai."
    exit 1
fi

sudo mkdir -p /etc/cloudflared

printf '%s\n' "$TOKEN" | sudo tee /etc/cloudflared/token >/dev/null
sudo chmod 600 /etc/cloudflared/token

sudo tee /etc/systemd/system/cloudflared.service >/dev/null <<'SERVICE'
[Unit]
Description=Cloudflare Tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/cloudflared tunnel --protocol http2 run --token-file /etc/cloudflared/token
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable cloudflared

echo
echo "Testing Cloudflare Tunnel..."
sudo systemctl restart cloudflared || true

sleep 3

echo
echo "======================================"
echo " SERVICE STATUS"
echo "======================================"

sudo systemctl status cloudflared --no-pager -l || true

echo
echo "======================================"
echo " RECENT LOGS"
echo "======================================"

sudo journalctl -u cloudflared -n 40 --no-pager || true
EOF

chmod +x /root/fix-cloudflare.sh
bash /root/fix-cloudflare.sh
