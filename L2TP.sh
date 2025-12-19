#!/bin/bash
set -e

echo "=== Step 1: UPDATE dan Instal L2TPD ==="
apt update
apt install -y xl2tpd socat

echo "=== Step 2: Backup and configure xl2tpd.conf ==="
mv /etc/xl2tpd/xl2tpd.conf /etc/xl2tpd/xl2tpd.conf.backup
cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[global]
port = 1701
ipsec saref = no
access control = no

[lns default]
ip range = 172.100.100.101-172.100.100.254
local ip = 172.100.100.1
require chap = yes
refuse pap = yes
require authentication = yes
name = L2TPServer
ppp debug = no
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF

echo "=== Step 3: Configure chap-secrets ==="
cat > /etc/ppp/chap-secrets <<EOF
RizkiNet       *	putra123      	172.100.100.101
007putra       *	putra123        172.100.100.102
CahayaNet      *	putra123	      172.100.100.103
CahaaNet2	     *	putra123	      172.100.100.104
FerlisNet	     *	putra123	      172.100.100.105
FerlisNet2	   *	putra123	      172.100.100.106
JuanNet        *  putra123        172.100.100.107
JuanNet2       *  putra123        182.100.100.108
EOF

echo "=== Step 4: Configure options.xl2tpd ==="
cat > /etc/ppp/options.xl2tpd <<EOF
ipcp-accept-local
ipcp-accept-remote
ms-dns 8.8.8.8
ms-dns 1.1.1.1
noccp
auth
mtu 1460
mru 1460
lock
nodefaultroute
require-chap
refuse-pap
hide-password
lcp-echo-interval 30
lcp-echo-failure 4
debug
proxyarp
EOF


echo "=== Step 5: Restart xl2tpd service ==="
systemctl restart xl2tpd
systemctl status xl2tpd --no-pager

echo "=== Step 6: Create l2tp-forward.sh script ==="
cat > /usr/local/bin/l2tp-forward.sh <<'EOF'
#!/bin/bash

CONF_FILE="/etc/l2tp-forwards.conf"

# Pastikan IP forwarding aktif
sysctl -w net.ipv4.ip_forward=1 > /dev/null

# Jalankan socat untuk setiap baris di config
while IFS=: read -r PORT_SERVER IP_CLIENT PORT_CLIENT
do
    # Lewati baris kosong atau komentar
    [[ -z "$PORT_SERVER" || "$PORT_SERVER" =~ ^# ]] && continue

    # Jalankan socat di background
    socat TCP-LISTEN:"$PORT_SERVER",fork TCP:"$IP_CLIENT":"$PORT_CLIENT" &
    echo "Forwarding $PORT_SERVER -> $IP_CLIENT:$PORT_CLIENT"
done < "$CONF_FILE"
EOF

chmod +x /usr/local/bin/l2tp-forward.sh

echo "=== Step 7: Create systemd service for L2TP forwarding ==="
cat > /etc/systemd/system/l2tp-forward.service <<EOF
[Unit]
Description=L2TP VPN Port Forwarding
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/l2tp-forward.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

echo "=== Step 8: Create generate-l2tp-conf.sh script ==="
cat > /usr/local/bin/generate-l2tp-conf.sh <<'EOF'
#!/bin/bash

CONFIG_FILE="/etc/l2tp-forwards.conf"
> "$CONFIG_FILE"

for i in $(seq 101 254); do
    IP="172.100.100.$i"
    for port in 1 2 3 4 5 6 7; do
        SERVER_PORT=$((port * 1000 + i - 100))

        if [ "$port" -eq 1 ]; then
            CLIENT_PORT=8291
        elif [ "$port" -eq 2 ]; then
            CLIENT_PORT=8728
        else
            CLIENT_PORT=$SERVER_PORT
        fi

        echo "${SERVER_PORT}:${IP}:${CLIENT_PORT}" >> "$CONFIG_FILE"
    done
done

echo "File $CONFIG_FILE berhasil dibuat (Winbox + API MikroTik)!"
EOF

chmod +x /usr/local/bin/generate-l2tp-conf.sh
/usr/local/bin/generate-l2tp-conf.sh

echo "=== Step 9: Enable and start forwarding service ==="
systemctl daemon-reload
systemctl enable l2tp-forward
systemctl restart l2tp-forward
systemctl status l2tp-forward

echo "=== Script selesai ==="
