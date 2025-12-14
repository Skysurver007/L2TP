#!/bin/bash
set -e

echo "=== Update & install dependencies ==="
apt update
apt install -y python3-pip jq
pip3 install requests

echo "=== Prepare directories & logs ==="
mkdir -p /var/run/ppp_sessions
chown root:root /var/run/ppp_sessions
chmod 755 /var/run/ppp_sessions

touch /var/log/ppp-monitor.log
chmod 644 /var/log/ppp-monitor.log

echo "=== Create ip-up script ==="
cat > /etc/ppp/ip-up.d/99-monitor <<'EOF'
#!/bin/bash
# /etc/ppp/ip-up.d/99-monitor
# args: $1=ifname $2=tty $3=speed $4=local_ip $5=remote_ip $6=ipparam

IFACE="$1"
LOCAL_IP="$4"
REMOTE_IP="$5"
USER="${PEERNAME:-${AUTHNAME:-Unknown}}"
START_TS="$(date +%s)"
CALLER="$(echo ${IFNAME:-} | tr -cd '[:print:]')"
SESS_DIR="/var/run/ppp_sessions"

mkdir -p "${SESS_DIR}"
cat > "${SESS_DIR}/${IFACE}.json" <<JSON
{"iface":"${IFACE}","user":"${USER}","local_ip":"${LOCAL_IP}","remote_ip":"${REMOTE_IP}","start":${START_TS},"caller":"${CALLER}"}
JSON

echo "$(date +"%F %T") CONNECT ${IFACE} ${USER} ${REMOTE_IP} ${LOCAL_IP}" >> /var/log/ppp-monitor.log
exit 0
EOF

chmod +x /etc/ppp/ip-up.d/99-monitor

echo "=== Create ip-down script ==="
cat > /etc/ppp/ip-down.d/99-monitor <<'EOF'
#!/bin/bash
# /etc/ppp/ip-down.d/99-monitor

IFACE="$1"
SESS_DIR="/var/run/ppp_sessions"

if [ -f "${SESS_DIR}/${IFACE}.json" ]; then
  mv "${SESS_DIR}/${IFACE}.json" "${SESS_DIR}/${IFACE}.ended-$(date +%s)"
fi

echo "$(date +"%F %T") DISCONNECT ${IFACE}" >> /var/log/ppp-monitor.log
exit 0
EOF

chmod +x /etc/ppp/ip-down.d/99-monitor

echo "=== Create Python monitor ==="
cat > /root/monitor_full.py <<'EOF'
#!/usr/bin/env python3
import time, json, os, subprocess, requests
from datetime import datetime

TOKEN = "ISI BOT TOKEN"
CHAT_ID = "ISI CHAT ID"
SESS_DIR = "/var/run/ppp_sessions"
BAN_FILE = "/etc/ppp/banlist.txt"
LOG_FILE = "/var/log/ppp-monitor.log"
POLL_INTERVAL = 3
GEO_API = "http://ip-api.com/json/"

def send(text):
    url = f"https://api.telegram.org/bot{TOKEN}/sendMessage"
    try:
        requests.post(url, data={
            "chat_id": CHAT_ID,
            "text": text,
            "parse_mode": "Markdown"
        }, timeout=5)
    except Exception as e:
        print("Telegram error:", e)

def read_ban():
    if not os.path.exists(BAN_FILE):
        return set()
    return set(l.strip() for l in open(BAN_FILE) if l.strip())

def read_sessions():
    sessions = {}
    if not os.path.isdir(SESS_DIR):
        return sessions
    for fn in os.listdir(SESS_DIR):
        if fn.endswith(".json"):
            try:
                with open(os.path.join(SESS_DIR, fn)) as f:
                    j = json.load(f)
                    sessions[j["iface"]] = j
            except:
                pass
    return sessions

def get_ifaces():
    out = subprocess.getoutput("ip -o link show | grep ppp | awk -F': ' '{print $2}'")
    return set(out.split())

def fmt_dur(s):
    s = int(s)
    h=s//3600; m=(s%3600)//60; sec=s%60
    if h: return f"{h}h {m}m {sec}s"
    if m: return f"{m}m {sec}s"
    return f"{sec}s"

def main():
    send("🔍 *Monitor L2TP Full* started.")
    known = read_sessions()

    while True:
        try:
            bans = read_ban()
            ifaces = get_ifaces()
            sessions = read_sessions()

            for iface,s in sessions.items():
                if iface in known or iface not in ifaces:
                    continue

                user = s.get("user","Unknown")
                if user in bans:
                    subprocess.getoutput(f"pkill -f 'ppp.*{iface}' || true")
                    send(f"🚫 *BANNED* `{user}` on `{iface}`")
                    continue

                count = sum(1 for x in sessions.values() if x.get("user")==user)
                if count > 1:
                    subprocess.getoutput(f"pkill -f 'ppp.*{iface}' || true")
                    send(f"⚠️ *Limit 1 device* `{user}` disconnected")
                    continue

                start = int(s.get("start", time.time()))
                ts = datetime.fromtimestamp(start).strftime("%F %T")
                send(
                    "🟢 *User Connect*\n"
                    f"User: `{user}`\n"
                    f"Interface: `{iface}`\n"
                    f"Local IP: `{s.get('local_ip')}`\n"
                    f"Peer IP: `{s.get('remote_ip')}`\n"
                    f"Start: `{ts}`"
                )
                known[iface] = s

            for iface in list(known):
                if iface not in ifaces or iface not in sessions:
                    s = known.pop(iface)
                    dur = time.time() - int(s.get("start", time.time()))
                    send(
                        "🔴 *User Disconnect*\n"
                        f"User: `{s.get('user')}`\n"
                        f"Interface: `{iface}`\n"
                        f"Duration: `{fmt_dur(dur)}`"
                    )

        except Exception as e:
            print("monitor error:", e)

        time.sleep(POLL_INTERVAL)

if __name__ == "__main__":
    main()
EOF

chmod +x /root/monitor_full.py

echo "=== Create systemd service ==="
cat > /etc/systemd/system/ppp-monitor.service <<'EOF'
[Unit]
Description=PPP/L2TP Monitor (Telegram notifier)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /root/monitor_full.py
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

echo "=== Enable & start service ==="
systemctl daemon-reload
systemctl enable --now ppp-monitor.service

echo "=== DONE ==="
systemctl status ppp-monitor.service --no-pager
