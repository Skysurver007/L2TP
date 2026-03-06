#!/bin/bash

echo "=== Update System ==="
apt update && apt upgrade -y

echo "=== Install Dependencies ==="
apt install python3 python3-pip python3-venv curl wget git -y

echo "=== Setup Directory ==="
mkdir -p /root/monitoring-wifi
cd /root/monitoring-wifi

echo "=== Download NMS from Github ==="
git clone https://github.com/Skysurver007/NMS .
    
echo "=== Setup Python Virtual Environment ==="
python3 -m venv venv
source venv/bin/activate

echo "=== Install Python Packages ==="
pip install flask psutil requests routeros_api icmplib flask-compress gunicorn

deactivate

echo "=== Create Systemd Service ==="

cat <<EOF > /etc/systemd/system/monitoring-wifi.service
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

echo "=== Enable & Start Service ==="
systemctl daemon-reload
systemctl enable monitoring-wifi
systemctl restart monitoring-wifi

echo "================================="
echo "INSTALL SELESAI ✅"
echo "Akses NMS di:"
echo "http://IP-SERVER:5002"
echo "================================="
