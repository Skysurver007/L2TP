#!/bin/bash

#===============================================================================
# NMS Monitoring WiFi - Professional Auto Installer
# Version: 2.0
# Author: System Administrator
# Description: One-click installer for Peycell NMS Monitoring Service
#===============================================================================

#-------------------------------------------------------------------------------
# KONFIGURASI
#-------------------------------------------------------------------------------
set -euo pipefail  # Strict mode: exit on error, undefined vars, pipe failures

# Warna untuk output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# Konfigurasi
readonly INSTALL_DIR="/root/monitoring-wifi"
readonly SERVICE_NAME="monitoring-wifi"
readonly PORT="5002"
readonly GIT_REPO="https://github.com/Skysurver007/NMS.git"
readonly LOG_FILE="/var/log/monitoring-wifi-install.log"

# Variabel status
INSTALL_STEP=0
TOTAL_STEPS=12
START_TIME=$(date +%s)

#-------------------------------------------------------------------------------
# FUNGSI UTILITAS
#-------------------------------------------------------------------------------

# Fungsi logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Fungsi header
print_header() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════════════╗
    ║                                                                  ║
    ║           ███╗   ██╗███╗   ███╗███████╗    ██████╗               ║
    ║           ████╗  ██║████╗ ████║██╔════╝   ██╔════╝               ║
    ║           ██╔██╗ ██║██╔████╔██║███████╗   ██║  ███╗              ║
    ║           ██║╚██╗██║██║╚██╔╝██║╚════██║   ██║   ██║              ║
    ║           ██║ ╚████║██║ ╚═╝ ██║███████║██╗╚██████╔╝              ║
    ║           ╚═╝  ╚═══╝╚═╝     ╚═╝╚══════╝╚═╝ ╚═════╝               ║
    ║                                                                  ║
    ║                  Network Monitoring System                       ║
    ║                    Professional Edition                          ║
    ╚══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${BOLD}Version:${NC} 2.0 | ${BOLD}Date:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${BOLD}Target:${NC} ${INSTALL_DIR} | ${BOLD}Port:${NC} ${PORT}"
    echo -e "${YELLOW}────────────────────────────────────────────────────────────────────${NC}"
    echo ""
}

# Fungsi progress bar
show_progress() {
    local current=$1
    local total=$2
    local message=$3
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r${BLUE}[${NC}"
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "${BLUE}]${NC} ${CYAN}%3d%%${NC} ${YELLOW}%s${NC}" "$percentage" "$message"
    
    if [ $current -eq $total ]; then
        echo ""
    fi
}

# Fungsi step counter
next_step() {
    INSTALL_STEP=$((INSTALL_STEP + 1))
    echo ""
    echo -e "${PURPLE}▶ Step ${INSTALL_STEP}/${TOTAL_STEPS}:${NC} ${BOLD}$1${NC}"
    log "STEP ${INSTALL_STEP}: $1"
    sleep 1
}

# Fungsi sukses
success_msg() {
    echo -e "${GREEN}✔${NC} $1"
    log "SUCCESS: $1"
}

# Fungsi error
error_msg() {
    echo -e "${RED}✘${NC} $1"
    log "ERROR: $1"
}

# Fungsi warning
warning_msg() {
    echo -e "${YELLOW}⚠${NC} $1"
    log "WARNING: $1"
}

# Fungsi info
info_msg() {
    echo -e "${CYAN}ℹ${NC} $1"
    log "INFO: $1"
}

# Fungsi cek root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_msg "This script must be run as root!"
        echo -e "${YELLOW}Please run: sudo $0${NC}"
        exit 1
    fi
    success_msg "Root privileges verified"
}

# Fungsi cek OS
check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    info_msg "Detected OS: $OS $VER"
    
    case "$OS" in
        *Debian*|*Ubuntu*)
            success_msg "Supported operating system detected"
            ;;
        *)
            warning_msg "Untested operating system. Continuing anyway..."
            ;;
    esac
}

# Fungsi cek koneksi internet
check_internet() {
    info_msg "Checking internet connectivity..."
    if ping -c 1 github.com &> /dev/null; then
        success_msg "Internet connection OK"
    else
        error_msg "No internet connection detected!"
        exit 1
    fi
}

# Fungsi cek port
check_port() {
    if netstat -tuln 2>/dev/null | grep -q ":$PORT "; then
        warning_msg "Port $PORT is already in use!"
        echo -e "${YELLOW}Current service using port $PORT:${NC}"
        netstat -tulpn 2>/dev/null | grep ":$PORT " || ss -tulpn | grep ":$PORT "
        read -p "Continue anyway? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        success_msg "Port $PORT is available"
    fi
}

# Fungsi backup existing
backup_existing() {
    if [ -d "$INSTALL_DIR" ]; then
        warning_msg "Existing installation found at $INSTALL_DIR"
        local backup_name="${INSTALL_DIR}-backup-$(date +%Y%m%d-%H%M%S)"
        info_msg "Creating backup: $backup_name"
        mv "$INSTALL_DIR" "$backup_name"
        success_msg "Backup created successfully"
    fi
    
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        warning_msg "Existing service is running. Stopping..."
        systemctl stop "$SERVICE_NAME"
        systemctl disable "$SERVICE_NAME" 2>/dev/null || true
        success_msg "Old service stopped"
    fi
}

# Fungsi install dependencies
install_deps() {
    show_progress 1 3 "Updating package lists..."
    apt-get update -qq
    
    show_progress 2 3 "Upgrading packages..."
    apt-get upgrade -y -qq
    
    show_progress 3 3 "Installing required packages..."
    apt-get install -y -qq git python3 python3-pip python3-venv curl wget net-tools
    
    success_msg "System dependencies installed"
}

# Fungsi setup python
setup_python() {
    cd "$INSTALL_DIR"
    
    show_progress 1 4 "Cleaning unnecessary files..."
    rm -rf README.md .git .github 2>/dev/null || true
    
    show_progress 2 4 "Creating virtual environment..."
    python3 -m venv venv
    
    show_progress 3 4 "Activating virtual environment..."
    source venv/bin/activate
    
    show_progress 4 4 "Installing Python packages..."
    pip install --quiet --upgrade pip
    pip install --quiet flask psutil requests routeros_api icmplib flask-compress gunicorn
    
    success_msg "Python environment configured"
}

# Fungsi create service
create_service() {
    show_progress 1 2 "Creating systemd service file..."
    
    cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=Peycell NMS Monitoring Service
Documentation=https://github.com/Skysurfer007/NMS
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
Environment=PATH=${INSTALL_DIR}/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=PYTHONUNBUFFERED=1
Environment=FLASK_ENV=production

ExecStart=${INSTALL_DIR}/venv/bin/gunicorn \\
    --workers 1 \\
    --threads 4 \\
    --bind 0.0.0.0:${PORT} \\
    --timeout 120 \\
    --access-logfile /var/log/${SERVICE_NAME}-access.log \\
    --error-logfile /var/log/${SERVICE_NAME}-error.log \\
    --capture-output \\
    --enable-stdio-inheritance \\
    app:app

ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s TERM \$MAINPID

Restart=always
RestartSec=10
StartLimitInterval=60s
StartLimitBurst=3

StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

[Install]
WantedBy=multi-user.target
EOF

    show_progress 2 2 "Setting permissions..."
    chmod 644 /etc/systemd/system/${SERVICE_NAME}.service
    
    success_msg "Systemd service created"
}

# Fungsi create logrotate
setup_logrotate() {
    info_msg "Configuring log rotation..."
    
    cat > /etc/logrotate.d/${SERVICE_NAME} << EOF
/var/log/${SERVICE_NAME}-*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    sharedscripts
    postrotate
        systemctl reload ${SERVICE_NAME} > /dev/null 2>&1 || true
    endscript
}
EOF

    success_msg "Log rotation configured (14 days retention)"
}

# Fungsi create firewall rules
setup_firewall() {
    if command -v ufw &> /dev/null; then
        info_msg "Configuring UFW firewall..."
        ufw allow ${PORT}/tcp comment "NMS Monitoring" 2>/dev/null || true
        success_msg "UFW rule added for port ${PORT}"
    elif command -v firewall-cmd &> /dev/null; then
        info_msg "Configuring Firewalld..."
        firewall-cmd --permanent --add-port=${PORT}/tcp 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
        success_msg "Firewalld rule added for port ${PORT}"
    else
        warning_msg "No supported firewall detected. Please manually open port ${PORT}"
    fi
}

# Fungsi start service
start_service() {
    show_progress 1 3 "Reloading systemd daemon..."
    systemctl daemon-reload
    
    show_progress 2 3 "Enabling service..."
    systemctl enable ${SERVICE_NAME}.service
    
    show_progress 3 3 "Starting service..."
    systemctl start ${SERVICE_NAME}.service
    
    sleep 2
    
    if systemctl is-active --quiet ${SERVICE_NAME}.service; then
        success_msg "Service is running"
    else
        error_msg "Service failed to start!"
        systemctl status ${SERVICE_NAME}.service --no-pager
        exit 1
    fi
}

# Fungsi verifikasi
verify_installation() {
    info_msg "Verifying installation..."
    
    # Cek service status
    local status=$(systemctl is-active ${SERVICE_NAME}.service)
    if [ "$status" = "active" ]; then
        success_msg "Service status: ACTIVE"
    else
        error_msg "Service status: $status"
    fi
    
    # Cek port listening
    if netstat -tuln 2>/dev/null | grep -q ":$PORT " || ss -tuln 2>/dev/null | grep -q ":$PORT "; then
        success_msg "Port $PORT is listening"
    else
        warning_msg "Port $PORT not detected yet (may need few seconds)"
    fi
    
    # Cek files
    if [ -f "${INSTALL_DIR}/app.py" ] || [ -f "${INSTALL_DIR}/app.pyc" ]; then
        success_msg "Application files found"
    else
        warning_msg "Application entry point not found (app.py)"
    fi
}

# Fungsi create management script
create_management_script() {
    info_msg "Creating management helper script..."
    
    cat > /usr/local/bin/nmsctl << 'EOF'
#!/bin/bash
# NMS Control Script

SERVICE_NAME="monitoring-wifi"
INSTALL_DIR="/root/monitoring-wifi"

case "$1" in
    status)
        systemctl status ${SERVICE_NAME}.service
        ;;
    start)
        systemctl start ${SERVICE_NAME}.service
        echo "✔ Service started"
        ;;
    stop)
        systemctl stop ${SERVICE_NAME}.service
        echo "✔ Service stopped"
        ;;
    restart)
        systemctl restart ${SERVICE_NAME}.service
        echo "✔ Service restarted"
        ;;
    logs)
        journalctl -u ${SERVICE_NAME}.service -f
        ;;
    update)
        cd ${INSTALL_DIR}
        git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || echo "Git pull failed"
        systemctl restart ${SERVICE_NAME}.service
        echo "✔ Update completed"
        ;;
    shell)
        cd ${INSTALL_DIR}
        source venv/bin/activate
        bash
        ;;
    backup)
        BACKUP_NAME="${INSTALL_DIR}-backup-$(date +%Y%m%d-%H%M%S)"
        cp -r ${INSTALL_DIR} ${BACKUP_NAME}
        echo "✔ Backup created: ${BACKUP_NAME}"
        ;;
    *)
        echo "NMS Control - Usage: nmsctl [command]"
        echo ""
        echo "Commands:"
        echo "  status    - Show service status"
        echo "  start     - Start service"
        echo "  stop      - Stop service"
        echo "  restart   - Restart service"
        echo "  logs      - View realtime logs"
        echo "  update    - Update from git and restart"
        echo "  shell     - Enter virtual environment shell"
        echo "  backup    - Create backup of installation"
        echo ""
        ;;
esac
EOF

    chmod +x /usr/local/bin/nmsctl
    success_msg "Management script created: nmsctl"
}

# Fungsi print summary
print_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    local ip_address=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo -e "${GREEN}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════════════╗
    ║                    INSTALLATION COMPLETE!                        ║
    ╚══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo -e "${BOLD}⏱  Duration:${NC} ${minutes}m ${seconds}s"
    echo -e "${BOLD}📁 Installation Directory:${NC} ${INSTALL_DIR}"
    echo -e "${BOLD}🔧 Service Name:${NC} ${SERVICE_NAME}.service"
    echo -e "${BOLD}🌐 Access URL:${NC} ${CYAN}http://${ip_address}:${PORT}${NC}"
    echo -e "${BOLD}📝 Log Files:${NC} /var/log/${SERVICE_NAME}-*.log"
    echo -e "${BOLD}📊 Log File:${NC} ${LOG_FILE}"
    echo ""
    
    echo -e "${YELLOW}────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${BOLD}🚀 Management Commands:${NC}"
    echo ""
    echo -e "  ${CYAN}nmsctl status${NC}     - Check service status"
    echo -e "  ${CYAN}nmsctl start${NC}      - Start service"
    echo -e "  ${CYAN}nmsctl stop${NC}       - Stop service"
    echo -e "  ${CYAN}nmsctl restart${NC}    - Restart service"
    echo -e "  ${CYAN}nmsctl logs${NC}       - View realtime logs"
    echo -e "  ${CYAN}nmsctl update${NC}     - Update from GitHub"
    echo -e "  ${CYAN}nmsctl backup${NC}     - Create backup"
    echo ""
    
    echo -e "${YELLOW}────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${BOLD}🔍 Systemd Commands:${NC}"
    echo ""
    echo -e "  ${CYAN}systemctl status ${SERVICE_NAME}${NC}"
    echo -e "  ${CYAN}journalctl -u ${SERVICE_NAME} -f${NC}"
    echo ""
    
    echo -e "${YELLOW}────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${BOLD}🔥 Quick Test:${NC}"
    echo -e "  ${CYAN}curl -I http://localhost:${PORT}${NC}"
    echo ""
    
    # Test koneksi
    echo -e "${PURPLE}Testing local connection...${NC}"
    sleep 1
    
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:${PORT} | grep -q "200\|302\|401"; then
        echo -e "${GREEN}✔ Application is responding!${NC}"
    else
        echo -e "${YELLOW}⚠ Application may still be starting. Wait 10-20 seconds...${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Thank you for using Peycell NMS Monitoring System!${NC}"
    echo ""
    
    log "Installation completed successfully in ${duration} seconds"
}

# Fungsi cleanup on error
cleanup() {
    if [ $? -ne 0 ]; then
        echo ""
        error_msg "Installation failed! Check log: ${LOG_FILE}"
        echo -e "${YELLOW}For debugging:${NC}"
        echo -e "  tail -n 50 ${LOG_FILE}"
        echo -e "  systemctl status ${SERVICE_NAME}.service"
    fi
}
trap cleanup EXIT

#-------------------------------------------------------------------------------
# MAIN EXECUTION
#-------------------------------------------------------------------------------

main() {
    # Inisialisasi log
    touch "$LOG_FILE"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
    
    print_header
    check_root
    check_os
    check_internet
    check_port
    
    # Backup existing
    next_step "Backing up existing installation (if any)"
    backup_existing
    
    # Install dependencies
    next_step "Installing system dependencies"
    install_deps
    
    # Clone repository
    next_step "Cloning repository from GitHub"
    info_msg "Source: ${GIT_REPO}"
    git clone --depth 1 "$GIT_REPO" NMS
    mv NMS monitoring-wifi
    success_msg "Repository cloned to ${INSTALL_DIR}"
    
    # Setup Python
    next_step "Setting up Python virtual environment"
    setup_python
    
    # Create service
    next_step "Creating systemd service"
    create_service
    
    # Setup logrotate
    next_step "Configuring log rotation"
    setup_logrotate
    
    # Setup firewall
    next_step "Configuring firewall"
    setup_firewall
    
    # Start service
    next_step "Starting monitoring service"
    start_service
    
    # Verifikasi
    next_step "Verifying installation"
    verify_installation
    
    # Create management script
    next_step "Creating management utilities"
    create_management_script
    
    # Summary
    print_summary
}

# Jalankan main
main "$@"
