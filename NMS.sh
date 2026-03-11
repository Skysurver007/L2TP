#!/bin/bash

# Script Instalasi Monitoring WiFi - Sekali Klik
# Dibuat otomatis oleh RizkiNet

set -e  # Exit jika ada error

echo "=========================================="
echo "  MONITORING WIFI - AUTO INSTALLER"
echo "=========================================="
echo ""

# Update dan upgrade sistem
echo "[1/12] Updating dan upgrading sistem..."
apt update && apt upgrade -y

# Install git
echo "[2/12] Menginstall Git..."
apt install git -y

# Clone repository
echo "[3/12] Cloning repository..."
if [ -d "NMS" ]; then
    rm -rf NMS
fi
git clone https://github.com/Skysurver007/NMS.git
mv NMS monitoring-wifi

# Install Python dan dependencies
echo "[4/12] Menginstall Python dan dependencies..."
apt install python3 python3-pip python3-venv curl wget -y

# Setup Python environment
echo "[5/12] Setup Python virtual environment..."
cd /root/monitoring-wifi
rm -rf README.md
python3 -m venv venv
source venv/bin/activate
pip install flask psutil requests routeros_api icmplib flask-compress gunicorn
deactivate

# Buat systemd service file
echo "[6/12] Membuat systemd service..."
cat > /etc/systemd/system/monitoring-wifi.service << 'EOF'
[Unit]
Description=Peycell NMS Monitoring Service
After=network.target

[Service]
User=root
WorkingDirectory=/root/monitoring-wifi
Environment=PATH=/root/monitoring-wifi/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

ExecStart=/root/monitoring-wifi/venv/bin/gunicorn --workers 1 --threads 4 --bind 0.0.0.0:5002 --timeout 120 app:app

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd dan enable service
echo "[7/12] Mengaktifkan service..."
systemctl daemon-reload
systemctl enable monitoring-wifi

# Install Node.js dan NPM
echo "[8/12] Menginstall Node.js dan NPM..."
apt install nodejs npm -y

# Install NPM dependencies
echo "[9/12] Menginstall NPM dependencies..."
cd /root/monitoring-wifi && npm install

# Start service
echo "[10/12] Menjalankan service..."
systemctl start monitoring-wifi
systemctl restart monitoring-wifi

# Cek status
echo "[11/12] Mengecek status service..."
sleep 2
systemctl status monitoring-wifi --no-pager

echo ""
echo "=========================================="
echo "  INSTALASI SELESAI!"
echo "=========================================="
echo ""
echo "Service Status:"
systemctl is-active monitoring-wifi && echo "✓ Service berjalan" || echo "✗ Service tidak berjalan"
echo ""
echo "Akses aplikasi di: http://IP_SERVER:5002"
echo ""
echo "Perintah yang berguna:"
echo "  - Cek status: systemctl status monitoring-wifi"
echo "  - Restart: systemctl restart monitoring-wifi"
echo "  - Stop: systemctl stop monitoring-wifi"
echo "  - Log: journalctl -u monitoring-wifi -f"
echo ""
