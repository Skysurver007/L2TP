#!/bin/bash

set -e

echo "Update system..."
apt update && apt upgrade -y

echo "Install dependencies..."
apt install python3 python3-pip python3-venv curl wget git -y

echo "Download repository..."
rm -rf /root/monitoring-wifi
git clone https://github.com/Skysurver007/monitoring-wifi /root/monitoring-wifi

cd /root/monitoring-wifi

echo "Create python virtual environment..."
python3 -m venv venv

source venv/bin/activate

echo "Install python packages..."
pip install --upgrade pip
pip install flask psutil requests routeros_api icmplib flask-compress gunicorn

deactivate

echo "Create systemd service..."
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

echo "Reload systemd..."
systemctl daemon-reload

echo "Enable service..."
systemctl enable monitoring-wifi

echo "Start service..."
systemctl restart monitoring-wifi

echo "Installation complete!"
echo "Service status:"
systemctl status monitoring-wifi --no-pager
