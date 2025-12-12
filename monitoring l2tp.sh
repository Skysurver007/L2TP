#!/bin/bash
set -e

echo "[1/8] Update & install dependensi..."
apt update
apt install -y python3-pip jq
pip3 install requests

echo "[2/8] Menyiapkan direktori & log..."
mkdir -p /var/run/ppp_sessions
chown root:root /var/run/ppp_sessions
chmod 755 /var/run/ppp_sessions

touch /var/log/ppp-monitor.log
chmod 644 /var/log/ppp-monitor.log

echo "[3/8] Membuat script ip-up..."
cat > /etc/ppp/ip-up.d/99-monitor << 'EOF'
#!/bin/bash
IFACE="$1"
LOCAL_IP="$4"
REMOTE_IP="$5"
USER="${PEERNAME:-${AUTHNAME:-Unknown}}"
START_TS="$(date +%s)"
CALLER="$(echo ${IFNAME:-} | tr -cd '[:print:]')"
SESS_DIR="/var/run/ppp_sessions"

mkdir -p "${SESS_DIR}"
cat > "${SESS_DIR}/${IFACE}.json" <<EOL
{"iface":"${IFACE}","user":"${USER}","local_ip":"${LOCAL_IP}","remote_ip":"${REMOTE_IP}","start":${START_TS},"caller":"${CALLER}"}
EOL

echo "$(date +"%F %T") CONNECT ${IFACE} ${USER} ${REMOTE_IP} ${LOCAL_IP}" >> /var/log/ppp-monitor.log
exit 0
EOF
chmod +x /etc/ppp/ip-up.d/99-monitor

echo "[4/8] Membuat script ip-down..."
cat > /etc/ppp/ip-down.d/99-monitor << 'EOF'
#!/bin/bash
IFACE="$1"
SESS_DIR="/var/run/ppp_sessions"
if [ -f "${SESS_DIR}/${IFACE}.json" ]; then
  mv "${SESS_DIR}/${IFACE}.json" "${SESS_DIR}/${IFACE}.ended-$(date +%s)"
fi
echo "$(date +"%F %T") DISCONNECT ${IFACE}" >> /var/log/ppp-monitor.log
exit 0
EOF
chmod +x /etc/ppp/ip-down.d/99-monitor

echo "[5/8] Membuat monitor_full.py..."
cat > /root/monitor_full.py << 'EOF'
<=== MASUKKAN SCRIPT monitor_full.py DI SINI ===>
EOF

# --- otomatis isi sesuai script yang kamu kirim ---
sed -i '1,/EOF/!d' /root/monitor_full.py
cat >> /root/monitor_full.py << 'EOF'
#!/usr/bin/env python3
import time, json, os, subprocess, requests
from datetime import datetime

TOKEN = "8506333953:AAEhYywqf0Gl2CleU03HWEyRCVgJ6AxNPVE"
CHAT_ID = "-5072450926"
SESS_DIR = "/var/run/ppp_sessions"
BAN_FILE = "/etc/ppp/banlist.txt"
LOG_FILE = "/var/log/ppp-monitor.log"
POLL_INTERVAL = 3
GEO_API = "http://ip-api.com/json/"

def send(text):
    try:
        requests.post(
            f"https://api.telegram.org/bot{TOKEN}/sendMessage",
            data={"chat_id": CHAT_ID, "text": text, "parse_mode": "Markdown"},
            timeout=5
        )
    except Exception as e:
        print("Telegram error:", e)

def read_ban():
    if not os.path.exists(BAN_FILE):
        return set()
    try:
        return set([l.strip() for l in open(BAN_FILE) if l.strip()])
    except:
        return set()

def read_sessions():
    sessions = {}
    if not os.path.isdir(SESS_DIR):
        return sessions
    for fn in os.listdir(SESS_DIR):
        if fn.endswith(".json"):
            try:
                j = json.load(open(os.path.join(SESS_DIR, fn)))
                sessions[j.get("iface")] = j
            except:
                continue
    return sessions

def get_ifaces():
    out = subprocess.getoutput("ip -o link show | grep ppp | awk -F': ' '{print $2}'")
    return set([l.strip() for l in out.splitlines() if l.strip()])

def geo_lookup(ip):
    try:
        j = requests.get(GEO_API + ip, timeout=4).json()
        if j.get("status") == "success":
            return f"{j.get('country','?')}, {j.get('regionName','?')}, {j.get('city','?')} (ISP: {j.get('isp','?')})"
    except:
        pass
    return "Unknown"

def fmt_dur(s):
    s = int(s)
    h = s // 3600; m = (s % 3600) // 60; sec = s % 60
    if h > 0: return f"{h}h {m}m {sec}s"
    if m > 0: return f"{m}m {sec}s"
    return f"{sec}s"

def main():
    send("🔍 *Monitor L2TP Full started*")
    known = {}
    seed = read_sessions()
    for k,v in seed.items():
        known[k]=v

    while True:
        try:
            bans = read_ban()
            current_ifaces = get_ifaces()
            sessions = read_sessions()

            for iface,s in sessions.items():
                if iface in known:
                    continue
                if iface not in current_ifaces:
                    continue

                user = s.get("user","Unknown")
                local_ip = s.get("local_ip","-")
                remote_ip = s.get("remote_ip","-")
                start_ts = s.get("start") or int(time.time())

                if user in bans:
                    subprocess.getoutput(f"pkill -f 'ppp.*{iface}' || true")
                    send(f"🚫 *BANNED* `{user}` tried to connect — disconnected.")
                    continue

                if sum(1 for x in sessions.values() if x.get("user")==user) > 1:
                    subprocess.getoutput(f"pkill -f 'ppp.*{iface}' || true")
                    send(f"⚠️ *Limit 1 device* — `{user}` extra session was disconnected.")
                    continue

                geo = geo_lookup(remote_ip)
                ts = datetime.fromtimestamp(int(start_ts)).strftime("%Y-%m-%d %H:%M:%S")

                send(
                    "🟢 *User Connect*\n"
                    f"User: `{user}`\nInterface: `{iface}`\nLocal IP: `{local_ip}`\nPeer IP: `{remote_ip}`\nStart: `{ts}`\nLocation: `{geo}`"
                )

                known[iface] = s

            for iface in list(known.keys()):
                if iface not in current_ifaces or iface not in sessions:
                    entry = known.pop(iface)
                    user = entry.get("user","Unknown")
                    local_ip = entry.get("local_ip","-")
                    remote_ip = entry.get("remote_ip","-")
                    start_ts = int(entry.get("start") or time.time())

                    dur = time.time() - start_ts
                    send(
                        "🔴 *User Disconnect*\n"
                        f"User: `{user}`\nInterface: `{iface}`\nLocal IP: `{local_ip}`\nPeer IP: `{remote_ip}`\nDuration: `{fmt_dur(dur)}`"
                    )

        except Exception as e:
            print("monitor error:", e)

        time.sleep(POLL_INTERVAL)

if __name__ == "__main__":
    main()
EOF

chmod +x /root/monitor_full.py

echo "[6/8] Membuat systemd service..."
cat > /etc/systemd/system/ppp-monitor.service << 'EOF'
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

echo "[7/8] Reload & enable service..."
systemctl daemon-reload
systemctl enable --now ppp-monitor.service

echo "[8/8] Membuat script daily summary..."
cat > /root/ppp_daily_summary.py << 'EOF'
#!/usr/bin/env python3
import time, os, requests
LOG="/var/log/ppp-monitor.log"
TOKEN="8506333953:AAEhYywqf0Gl2CleU03HWEyRCVgJ6AxNPVE"
CHAT="-5072450926"

def send(text):
    requests.post(
        f"https://api.telegram.org/bot{TOKEN}/sendMessage",
        data={"chat_id":CHAT,"text":text,"parse_mode":"Markdown"}
    )

if not os.path.exists(LOG):
    send("📝 Daily PPP Summary: no log found.")
    exit()

cutoff=time.time()-86400
lines=[]
with open(LOG) as f:
    for l in f:
        try:
            ts=l.split()[0]+" "+l.split()[1]
            dt=time.mktime(time.strptime(ts,"%Y-%m-%d %H:%M:%S"))
            if dt>=cutoff: lines.append(l.strip())
        except: pass

if not lines:
    send("📝 Daily PPP Summary: no activity in last 24h.")
else:
    send("📝 *Daily PPP Summary (24h)*\n\n" + "\n".join(lines[-200:]))
EOF

chmod +x /root/ppp_daily_summary.py

echo "=== INSTALASI SELESAI ==="
systemctl status ppp-monitor.service --no-pager
