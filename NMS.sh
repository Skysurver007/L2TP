#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════╗
# ║           🚀 MONITORING WIFI - TAHAP 1 INSTALLER 🚀            ║
# ║              Dibuat otomatis oleh RizkiNet                    ║
# ╚═══════════════════════════════════════════════════════════════╝

set -e  # Exit jika ada error

# Warna untuk tampilan menarik
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Fungsi header keren
show_header() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║  ██╗   ██╗███████╗███╗   ██╗ ██████╗ ██╗   ██╗██╗███╗   ██╗  ║"
    echo "║  ██║   ██║██╔════╝████╗  ██║██╔═══██╗██║   ██║██║████╗  ██║  ║"
    echo "║  ██║   ██║█████╗  ██╔██╗ ██║██║   ██║██║   ██║██║██╔██╗ ██║  ║"
    echo "║  ╚██╗ ██╔╝██╔══╝  ██║╚██╗██║██║   ██║╚██╗ ██╔╝██║██║╚██╗██║  ║"
    echo "║   ╚████╔╝ ███████╗██║ ╚████║╚██████╔╝ ╚████╔╝ ██║██║ ╚████║  ║"
    echo "║    ╚═══╝  ╚══════╝╚═╝  ╚═══╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝  ╚═══╝  ║"
    echo "║                                                               ║"
    echo "║           📡 NETWORK MONITORING SYSTEM 📡                     ║"
    echo "║                    ${YELLOW}TAHAP 1: PERSIAPAN${CYAN}                         ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Fungsi progress bar
progress_bar() {
    local duration=$1
    local prefix=$2
    local width=40
    local fill="█"
    local empty="░"
    
    for ((i=0; i<=width; i++)); do
        local percentage=$((i * 100 / width))
        local filled=$(printf "%${i}s" | tr ' ' "$fill")
        local unfilled=$(printf "%$((width-i))s" | tr ' ' "$empty")
        printf "\r${prefix} [${CYAN}${filled}${NC}${unfilled}] ${GREEN}${percentage}%%${NC}"
        sleep $(echo "scale=3; $duration/$width" | bc -l 2>/dev/null || echo "0.05")
    done
    echo ""
}

# Fungsi spinner loading
spinner() {
    local msg=$1
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    while true; do
        printf "\r${CYAN}${chars:$i:1}${NC} ${WHITE}${msg}${NC}"
        i=$(( (i+1) % 10 ))
        sleep 0.1
    done
}

# Fungsi sukses
success() {
    echo -e "\r${GREEN}✓${NC} $1"
}

# Fungsi info
info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Fungsi step header
step_header() {
    local current=$1
    local total=$2
    local title=$3
    echo ""
    echo -e "${YELLOW}[${current}/${total}]${NC} ${BOLD}${title}${NC}"
    echo -e "${CYAN}$(printf '=%.0s' {1..50})${NC}"
}

# ═══════════════════════════════════════════════════════════════
# MAIN INSTALLATION
# ═══════════════════════════════════════════════════════════════

show_header

echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║           🛠️  MULAI INSTALASI TAHAP 1                         ║${NC}"
echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# [1/5] Update sistem
step_header "1" "5" "📦 Updating dan Upgrading Sistem"
spinner "Updating package list..." &
PID=$!
apt update > /dev/null 2>&1
kill $PID 2>/dev/null
wait $PID 2>/dev/null
success "Package list updated"

spinner "Upgrading packages..." &
PID=$!
apt upgrade -y > /dev/null 2>&1
kill $PID 2>/dev/null
wait $PID 2>/dev/null
success "Packages upgraded"
progress_bar 0.5 "Progress"

# [2/5] Install Git
step_header "2" "5" "🔧 Menginstall Git"
spinner "Menginstall Git..." &
PID=$!
apt install git -y > /dev/null 2>&1
kill $PID 2>/dev/null
wait $PID 2>/dev/null
GIT_VERSION=$(git --version 2>/dev/null | awk '{print $3}')
success "Git v${GIT_VERSION} berhasil diinstall"
progress_bar 0.3 "Progress"

# [3/5] Clone repository
step_header "3" "5" "📥 Cloning Repository"
if [ -d "NMS" ]; then
    info "Menghapus folder NMS lama..."
    rm -rf NMS
fi
if [ -d "monitoring-wifi" ]; then
    info "Menghapus folder monitoring-wifi lama..."
    rm -rf monitoring-wifi
fi

spinner "Mengunduh source code dari GitHub..." &
PID=$!
git clone https://github.com/Skysurver007/NMS.git > /dev/null 2>&1
mv NMS monitoring-wifi
kill $PID 2>/dev/null
wait $PID 2>/dev/null
success "Repository berhasil di-clone ke /root/monitoring-wifi"
progress_bar 0.5 "Progress"

# [4/5] Install Python dan dependencies
step_header "4" "5" "🐍 Menginstall Python & Dependencies"
spinner "Menginstall Python3 dan pip..." &
PID=$!
apt install python3 python3-pip python3-venv curl wget -y > /dev/null 2>&1
kill $PID 2>/dev/null
wait $PID 2>/dev/null
PYTHON_VERSION=$(python3 --version 2>/dev/null)
success "${PYTHON_VERSION} berhasil diinstall"

spinner "Menginstall tools tambahan (curl, wget)..." &
PID=$!
# Sudah diinstall di atas
kill $PID 2>/dev/null
wait $PID 2>/dev/null
success "Tools tambahan siap"
progress_bar 0.5 "Progress"

# [5/5] Setup Python environment
step_header "5" "5" "⚙️  Setup Python Virtual Environment"

cd /root/monitoring-wifi

if [ -f "README.md" ]; then
    info "Membersihkan file README.md..."
    rm -rf README.md
fi

spinner "Membuat virtual environment..." &
PID=$!
python3 -m venv venv > /dev/null 2>&1
kill $PID 2>/dev/null
wait $PID 2>/dev/null
success "Virtual environment dibuat di ./venv"

echo ""
info "Menginstall Python packages:"
echo -e "  ${CYAN}•${NC} flask"
echo -e "  ${CYAN}•${NC} psutil"
echo -e "  ${CYAN}•${NC} requests"
echo -e "  ${CYAN}•${NC} routeros_api"
echo -e "  ${CYAN}•${NC} icmplib"
echo -e "  ${CYAN}•${NC} flask-compress"
echo -e "  ${CYAN}•${NC} gunicorn"

spinner "Menginstall packages (ini mungkin memerlukan waktu)..." &
PID=$!
source venv/bin/activate
pip install flask psutil requests routeros_api icmplib flask-compress gunicorn > /dev/null 2>&1
deactivate
kill $PID 2>/dev/null
wait $PID 2>/dev/null
success "Semua packages berhasil diinstall"

progress_bar 0.8 "Progress"

# ═══════════════════════════════════════════════════════════════
# SELESAI
# ═══════════════════════════════════════════════════════════════

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           ✅ TAHAP 1 BERHASIL SELESAI!                        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  📂 STRUKTUR DIREKTORI:                                       ║${NC}"
echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║  ${WHITE}/root/monitoring-wifi/${NC}                                      ${CYAN}║${NC}"
echo -e "${CYAN}║  ├── ${YELLOW}venv/${NC}          ← Virtual Environment                   ${CYAN}║${NC}"
echo -e "${CYAN}║  ├── ${YELLOW}app.py${NC}         ← Main Application (jika ada)          ${CYAN}║${NC}"
echo -e "${CYAN}║  └── ${YELLOW}[source files]${NC} ← File-file aplikasi                  ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  📝 CATATAN PENTING:                                          ║${NC}"
echo -e "${YELLOW}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${YELLOW}║  ${NC}Untuk menjalankan aplikasi secara manual:                    ${YELLOW}║${NC}"
echo -e "${YELLOW}║                                                               ║${NC}"
echo -e "${YELLOW}║  ${WHITE}cd /root/monitoring-wifi${NC}                                     ${YELLOW}║${NC}"
echo -e "${YELLOW}║  ${WHITE}source venv/bin/activate${NC}                                     ${YELLOW}║${NC}"
echo -e "${YELLOW}║  ${WHITE}python app.py${NC}         ${CYAN}# atau${NC} ${WHITE}gunicorn --bind 0.0.0.0:5002 app:app${NC}  ${YELLOW}║${NC}"
echo -e "${YELLOW}║                                                               ║${NC}"
echo -e "${YELLOW}║  ${NC}Untuk keluar dari virtual environment:                       ${YELLOW}║${NC}"
echo -e "${YELLOW}║  ${WHITE}deactivate${NC}                                                   ${YELLOW}║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  🚀 LANGKAH SELANJUTNYA (TAHAP 2):                            ║${NC}"
echo -e "${MAGENTA}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${MAGENTA}║  ${NC}Jalankan script Tahap 2 untuk:                               ${MAGENTA}║${NC}"
echo -e "${MAGENTA}║  ${WHITE}•${NC} Membuat systemd service                                    ${MAGENTA}║${NC}"
echo -e "${MAGENTA}║  ${WHITE}•${NC} Mengaktifkan auto-start pada boot                          ${MAGENTA}║${NC}"
echo -e "${MAGENTA}║  ${WHITE}•${NC} Menjalankan service secara background                      ${MAGENTA}║${NC}"
echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}✨ Instalasi persiapan selesai! Siap untuk Tahap 2.${NC}"
echo ""
