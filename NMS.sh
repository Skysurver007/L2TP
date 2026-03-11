apt update && apt upgrade -y
apt install git -y
git clone https://github.com/Skysurver007/NMS.git
mv NMS monitoring-wifi
apt install python3 python3-pip python3-venv curl wget -y
cd /root/monitoring-wifi
rm -rf README.md
python3 -m venv venv
source venv/bin/activate
pip install flask psutil requests routeros_api icmplib flask-compress gunicorn
deactivate
nano /etc/systemd/system/monitoring-wifi.service
isi dengan 
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



systemctl daemon-reload
systemctl enable monitoring-wifi
systemctl start monitoring-wifi
systemctl restart monitoring-wifi
systemctl status monitoring-wifi


apt install nodejs npm -y
cd /root/monitoring-wifi && npm install


