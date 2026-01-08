
#!/bin/bash
set -e

echo "=== Step 1: Install repository script and update packages ==="
bash <(curl -s https://raw.githubusercontent.com/Skysurver007/repositoi-ubuntu/main/repository.sh)
apt update
apt install -y xl2tpd socat

echo "=== Step 2: Backup and configure xl2tpd.conf ==="
mv /etc/xl2tpd/xl2tpd.conf /etc/xl2tpd/xl2tpd.conf.backup || true
cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[global]
port = 1701
ipsec saref = no
access control = no

[lns default]
ip range = 172.25.100.2-172.25.100.150
local ip = 172.25.100.150
require chap = yes
refuse pap = yes
require authentication = yes
name = L2TPServer
ppp debug = no
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF
echo "=== Step 3: Configure options.xl2tpd ==="
cat > /etc/ppp/options.xl2tpd <<EOF
ipcp-accept-local
ipcp-accept-remote
ms-dns 8.8.8.8
ms-dns 1.1.1.1
noccp
auth
mtu 1450
mru 1450
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

echo "=== Step 4: Configure auth-up (limit 1 login per user) ==="
cat > /etc/ppp/auth-up <<'EOF'
#!/bin/bash

USER="$PEERNAME"
LOCKDIR="/var/run/ppp-user-lock"
LOCKFILE="$LOCKDIR/$USER.lock"

# safety check
[ -z "$USER" ] && exit 0

mkdir -p "$LOCKDIR"

# kalau user sudah online → tolak koneksi BARU
if [ -f "$LOCKFILE" ]; then
    logger -t L2TP "reject login for user=$USER (already connected)"
    kill -TERM "$PPPD_PID"
    exit 0
fi

# sesi pertama → buat lock
echo "$PPPD_PID" > "$LOCKFILE"
logger -t L2TP "user=$USER connected pid=$PPPD_PID"

exit 0
EOF

echo "=== Step 5: Configure ip-down (hapus lock saat disconnect) ==="
cat > /etc/ppp/ip-down <<'EOF'
#!/bin/bash

USER="$PEERNAME"
LOCKFILE="/var/run/ppp-user-lock/$USER.lock"

[ -n "$USER" ] && rm -f "$LOCKFILE"
logger -t L2TP "user=$USER disconnected"
EOF

chmod +x /etc/ppp/auth-up
chmod +x /etc/ppp/ip-down

echo "=== Step 6: Restart xl2tpd service ==="
systemctl restart xl2tpd

echo "=== Step 7: Create l2tp-forward.sh ==="
cat > /usr/local/bin/l2tp-forward.sh <<'EOF'
#!/bin/bash

CONF_FILE="/etc/l2tp-forwards.conf"

sysctl -w net.ipv4.ip_forward=1 > /dev/null

while IFS=: read -r PORT_SERVER IP_CLIENT PORT_CLIENT
do
    [[ -z "$PORT_SERVER" || "$PORT_SERVER" =~ ^# ]] && continue
    socat TCP-LISTEN:"$PORT_SERVER",fork TCP:"$IP_CLIENT":"$PORT_CLIENT" &
done < "$CONF_FILE"
EOF

chmod +x /usr/local/bin/l2tp-forward.sh

echo "=== Step 8: Create systemd service ==="
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

echo "=== Step 9: Generate port forwarding config ==="
cat > /usr/local/bin/generate-l2tp-conf.sh <<'EOF'
#!/bin/bash

CONFIG_FILE="/etc/l2tp-forwards.conf"
> "$CONFIG_FILE"

for i in $(seq 1 149); do
    IP="172.25.100.$i"
    for port in 1 2 3 4 5 6 7 8 ; do
        SERVER_PORT=$((port * 1000 + i))

        case "$port" in
            1)
                CLIENT_PORT=8291   # Winbox Mikrotik
                ;;
            2)
                CLIENT_PORT=8728   # API Mikrotik
                ;;
            8)
                CLIENT_PORT=22     # SSH
                ;;
            *)
                CLIENT_PORT=$SERVER_PORT
                ;;
        esac

        echo "${SERVER_PORT}:${IP}:${CLIENT_PORT}" >> "$CONFIG_FILE"
    done
done


EOF

chmod +x /usr/local/bin/generate-l2tp-conf.sh
/usr/local/bin/generate-l2tp-conf.sh

echo "=== Step 10: Enable forwarding service ==="
systemctl daemon-reload
systemctl enable l2tp-forward
systemctl restart l2tp-forward

echo "=== SEMUA SELESAI ==="
echo "✔ L2TP aktif"
echo "✔ 1 user = 1 login (anti multi-login)"
echo "✔ Port forwarding aktif"
