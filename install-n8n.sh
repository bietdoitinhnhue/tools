#!/bin/bash

# Ubuntu Server Manager Installer
# Quick install: curl -sSL https://raw.githubusercontent.com/bietdoitinhnhue/server-manager/main/install-n8n.sh | sudo bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Configuration
SCRIPT_NAME="server-manager"
INSTALL_DIR="/usr/local/bin"
SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Lỗi: Script cần quyền root để cài đặt${NC}"
        echo -e "${YELLOW}Vui lòng chạy: sudo $0${NC}"
        exit 1
    fi
}

# Check Ubuntu version
check_ubuntu() {
    if [ ! -f /etc/os-release ]; then
        echo -e "${RED}Không thể xác định hệ điều hành${NC}"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        echo -e "${YELLOW}Cảnh báo: Script được tối ưu cho Ubuntu${NC}"
        echo -e "${YELLOW}Hệ điều hành hiện tại: $PRETTY_NAME${NC}"
        read -p "Bạn có muốn tiếp tục? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo -e "${GREEN}Đã xác nhận Ubuntu $VERSION_ID${NC}"
    fi
}

# Install dependencies
install_dependencies() {
    echo -e "${BLUE}Đang cài đặt dependencies...${NC}"
    apt update -qq
    apt install -y curl wget git nano htop unzip > /dev/null 2>&1
    echo -e "${GREEN}✓ Dependencies đã được cài đặt${NC}"
}

# Create main script
create_main_script() {
    echo -e "${BLUE}Đang tạo Server Manager...${NC}"
    
    cat > "$SCRIPT_PATH" << 'MAIN_SCRIPT_EOF'
#!/bin/bash

# Server Manager for bietdoitinhnhue.com
# Version: 1.0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Clear screen function
clear_screen() {
    clear
}

# Draw border
draw_border() {
    echo -e "${CYAN}+===================================================================================+${NC}"
}

# Show header
show_header() {
    clear_screen
    draw_border
    echo -e "${CYAN}|                              Server Manager                                      |${NC}"
    echo -e "${CYAN}|                   Powered by bietdoitinhnhue.com                               |${NC}"
    draw_border
    echo ""
    echo -e "${YELLOW}Phim tat: Nhan Ctrl + C hoac nhap 0 de thoat${NC}"
    echo -e "${GREEN}Xem huong dan: https://bietdoitinhnhue.com/docs${NC}"
    echo "--------------------------------------------------------------------------------"
}

# Check system resources
check_system() {
    echo -e "${BLUE}Thông tin hệ thống:${NC}"
    echo -e "${WHITE}OS:${NC} $(lsb_release -d | cut -f2)"
    echo -e "${WHITE}Kernel:${NC} $(uname -r)"
    echo -e "${WHITE}CPU:${NC} $(nproc) cores"
    echo -e "${WHITE}RAM:${NC} $(free -h | awk '/^Mem:/ {print $2}') (Available: $(free -h | awk '/^Mem:/ {print $7}'))"
    echo -e "${WHITE}Disk:${NC} $(df -h / | awk 'NR==2 {print $4}') free"
    echo -e "${WHITE}Uptime:${NC} $(uptime -p)"
    echo ""
}

# Install N8N
install_n8n() {
    echo -e "${GREEN}=== Cài đặt N8N Workflow Automation ===${NC}"
    check_system
    
    # Check if already installed
    if command -v n8n &> /dev/null; then
        echo -e "${YELLOW}N8N đã được cài đặt. Phiên bản: $(n8n --version)${NC}"
        read -p "Bạn có muốn cài đặt lại? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    echo -e "${BLUE}Đang cập nhật hệ thống...${NC}"
    apt update && apt upgrade -y
    
    echo -e "${BLUE}Đang cài đặt Node.js 18...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    
    echo -e "${BLUE}Đang cài đặt N8N...${NC}"
    npm install n8n -g
    
    echo -e "${BLUE}Đang tạo systemd service...${NC}"
    tee /etc/systemd/system/n8n.service > /dev/null <<EOF
[Unit]
Description=n8n workflow automation
Documentation=https://docs.n8n.io
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
Environment=N8N_BASIC_AUTH_ACTIVE=true
Environment=N8N_BASIC_AUTH_USER=admin
Environment=N8N_BASIC_AUTH_PASSWORD=bietdoitinhnhue123
Environment=N8N_HOST=0.0.0.0
Environment=N8N_PORT=5678
Environment=N8N_PROTOCOL=http
ExecStart=/usr/bin/n8n start
Restart=on-failure
RestartSec=5
StandardOutput=syslog
StandardError=syslog

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable n8n
    systemctl start n8n
    
    # Configure firewall
    if command -v ufw &> /dev/null; then
        ufw allow 5678/tcp
        echo -e "${GREEN}✓ Firewall đã được cấu hình${NC}"
    fi
    
    echo -e "${GREEN}✓ N8N đã được cài đặt thành công!${NC}"
    echo -e "${CYAN}URL:${NC} http://$(curl -s ifconfig.me):5678"
    echo -e "${CYAN}Username:${NC} admin"
    echo -e "${CYAN}Password:${NC} bietdoitinhnhue123"
    echo -e "${YELLOW}Lưu ý: Hãy đổi password sau khi đăng nhập lần đầu!${NC}"
}

# Change domain name
change_domain() {
    echo -e "${GREEN}=== Cập nhật tên miền ===${NC}"
    
    read -p "Nhập tên miền mới (ví dụ: example.com): " new_domain
    
    if [ -z "$new_domain" ]; then
        echo -e "${RED}Tên miền không được để trống!${NC}"
        return
    fi
    
    # Install nginx if not exists
    if ! command -v nginx &> /dev/null; then
        echo -e "${BLUE}Đang cài đặt Nginx...${NC}"
        apt install nginx -y
        systemctl enable nginx
    fi
    
    # Create nginx config
    tee /etc/nginx/sites-available/$new_domain > /dev/null <<EOF
server {
    listen 80;
    server_name $new_domain www.$new_domain;
    
    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/$new_domain /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test and reload nginx
    nginx -t && systemctl reload nginx
    
    echo -e "${GREEN}✓ Tên miền $new_domain đã được cấu hình${NC}"
    echo -e "${YELLOW}Hãy trỏ DNS của $new_domain về IP: $(curl -s ifconfig.me)${NC}"
}

# Update N8N version
update_n8n() {
    echo -e "${GREEN}=== Cập nhật N8N ===${NC}"
    
    if ! command -v n8n &> /dev/null; then
        echo -e "${RED}N8N chưa được cài đặt!${NC}"
        return
    fi
    
    current_version=$(n8n --version)
    echo -e "${BLUE}Phiên bản hiện tại: $current_version${NC}"
    
    echo -e "${BLUE}Đang dừng N8N service...${NC}"
    systemctl stop n8n
    
    echo -e "${BLUE}Đang cập nhật N8N...${NC}"
    npm update n8n -g
    
    echo -e "${BLUE}Đang khởi động lại N8N...${NC}"
    systemctl start n8n
    
    new_version=$(n8n --version)
    echo -e "${GREEN}✓ N8N đã được cập nhật lên phiên bản: $new_version${NC}"
}

# Setup 2FA/MFA
setup_2fa() {
    echo -e "${GREEN}=== Thiết lập xác thực 2 bước (2FA) ===${NC}"
    
    echo -e "${BLUE}Đang cài đặt Google Authenticator...${NC}"
    apt install libpam-google-authenticator -y
    
    echo -e "${BLUE}Đang cấu hình SSH 2FA...${NC}"
    
    # Backup SSH config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Configure SSH
    sed -i 's/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/@include common-auth/#@include common-auth/' /etc/pam.d/sshd
    
    # Add 2FA to PAM
    echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd
    echo "@include common-auth" >> /etc/pam.d/sshd
    
    systemctl restart sshd
    
    echo -e "${GREEN}✓ 2FA đã được cấu hình cho SSH${NC}"
    echo -e "${YELLOW}Chạy lệnh sau để thiết lập 2FA cho user hiện tại:${NC}"
    echo -e "${CYAN}google-authenticator${NC}"
    echo -e "${YELLOW}Sau đó quét QR code bằng ứng dụng Google Authenticator${NC}"
}

# Reset login credentials
reset_credentials() {
    echo -e "${GREEN}=== Đặt lại thông tin đăng nhập N8N ===${NC}"
    
    echo -e "${RED}CẢNH BÁO: Thao tác này sẽ xóa tất cả dữ liệu N8N!${NC}"
    read -p "Bạn có chắc chắn muốn tiếp tục? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo -e "${YELLOW}Đã hủy thao tác.${NC}"
        return
    fi
    
    echo -e "${BLUE}Đang dừng N8N service...${NC}"
    systemctl stop n8n
    
    echo -e "${BLUE}Đang xóa database...${NC}"
    rm -rf ~/.n8n/database.sqlite
    rm -rf ~/.n8n/nodes.json
    
    echo -e "${BLUE}Đang khởi động lại N8N...${NC}"
    systemctl start n8n
    
    echo -e "${GREEN}✓ Thông tin đăng nhập đã được reset!${NC}"
    echo -e "${CYAN}Truy cập http://$(curl -s ifconfig.me):5678 để thiết lập tài khoản mới${NC}"
}

# Export all data
export_data() {
    echo -e "${GREEN}=== Xuất dữ liệu N8N ===${NC}"
    
    if [ ! -d ~/.n8n ]; then
        echo -e "${RED}Không tìm thấy dữ liệu N8N!${NC}"
        return
    fi
    
    backup_dir="/root/n8n_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    echo -e "${BLUE}Đang tạo backup...${NC}"
    cp -r ~/.n8n/* "$backup_dir/" 2>/dev/null || true
    
    # Create info file
    cat > "$backup_dir/backup_info.txt" << EOF
N8N Backup Information
======================
Backup Date: $(date)
Server IP: $(curl -s ifconfig.me)
N8N Version: $(n8n --version 2>/dev/null || echo "Unknown")
Domain: bietdoitinhnhue.com
EOF
    
    # Create compressed archive
    tar -czf "$backup_dir.tar.gz" -C "$backup_dir" .
    rm -rf "$backup_dir"
    
    echo -e "${GREEN}✓ Backup đã được tạo: $backup_dir.tar.gz${NC}"
    echo -e "${CYAN}Kích thước: $(du -h "$backup_dir.tar.gz" | cut -f1)${NC}"
}

# Import workflow & credentials
import_data() {
    echo -e "${GREEN}=== Nhập dữ liệu N8N ===${NC}"
    
    read -p "Nhập đường dẫn file backup (.tar.gz): " backup_file
    
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}File backup không tồn tại: $backup_file${NC}"
        return
    fi
    
    echo -e "${RED}CẢNH BÁO: Thao tác này sẽ ghi đè dữ liệu hiện tại!${NC}"
    read -p "Bạn có chắc chắn muốn tiếp tục? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo -e "${YELLOW}Đã hủy thao tác.${NC}"
        return
    fi
    
    echo -e "${BLUE}Đang dừng N8N service...${NC}"
    systemctl stop n8n
    
    echo -e "${BLUE}Đang khôi phục dữ liệu...${NC}"
    temp_dir="/tmp/n8n_restore_$$"
    mkdir -p "$temp_dir"
    
    tar -xzf "$backup_file" -C "$temp_dir"
    
    # Backup current data
    if [ -d ~/.n8n ]; then
        mv ~/.n8n ~/.n8n.backup.$(date +%s)
    fi
    
    # Restore data
    mkdir -p ~/.n8n
    cp -r "$temp_dir"/* ~/.n8n/ 2>/dev/null || true
    
    # Cleanup
    rm -rf "$temp_dir"
    
    echo -e "${BLUE}Đang khởi động lại N8N...${NC}"
    systemctl start n8n
    
    echo -e "${GREEN}✓ Dữ liệu đã được khôi phục thành công!${NC}"
}

# Get Redis info
get_redis_info() {
    echo -e "${GREEN}=== Thông tin Redis ===${NC}"
    
    if ! command -v redis-cli &> /dev/null; then
        echo -e "${YELLOW}Redis chưa được cài đặt. Đang cài đặt...${NC}"
        apt update
        apt install redis-server -y
        systemctl enable redis-server
        systemctl start redis-server
        echo -e "${GREEN}✓ Redis đã được cài đặt${NC}"
    fi
    
    echo -e "${CYAN}Redis Status:${NC}"
    systemctl status redis-server --no-pager -l | head -10
    
    echo -e "\n${CYAN}Redis Configuration:${NC}"
    echo -e "${WHITE}Version:${NC} $(redis-cli --version)"
    echo -e "${WHITE}Memory Usage:${NC} $(redis-cli info memory | grep used_memory_human | cut -d: -f2)"
    echo -e "${WHITE}Connected Clients:${NC} $(redis-cli info clients | grep connected_clients | cut -d: -f2)"
    echo -e "${WHITE}Total Commands Processed:${NC} $(redis-cli info stats | grep total_commands_processed | cut -d: -f2)"
}

# Delete N8N and reset
delete_n8n() {
    echo -e "${RED}=== XÓA N8N VÀ RESET HỆ THỐNG ===${NC}"
    echo -e "${RED}CẢNH BÁO: Thao tác này sẽ xóa hoàn toàn N8N và tất cả dữ liệu!${NC}"
    echo -e "${YELLOW}Bao gồm: N8N, workflows, credentials, nginx config${NC}"
    
    read -p "Gõ 'DELETE' để xác nhận xóa: " confirm
    
    if [ "$confirm" != "DELETE" ]; then
        echo -e "${YELLOW}Đã hủy thao tác xóa.${NC}"
        return
    fi
    
    echo -e "${BLUE}Đang xóa N8N...${NC}"
    
    # Stop and disable services
    systemctl stop n8n 2>/dev/null || true
    systemctl disable n8n 2>/dev/null || true
    
    # Remove service file
    rm -f /etc/systemd/system/n8n.service
    systemctl daemon-reload
    
    # Uninstall N8N
    npm uninstall n8n -g 2>/dev/null || true
    
    # Remove data directories
    rm -rf ~/.n8n
    rm -rf ~/.n8n.backup.*
    
    # Remove nginx configs
    rm -f /etc/nginx/sites-available/bietdoitinhnhue.com
    rm -f /etc/nginx/sites-enabled/bietdoitinhnhue.com
    systemctl reload nginx 2>/dev/null || true
    
    echo -e "${GREEN}✓ N8N đã được xóa hoàn toàn!${NC}"
}

# System information
show_system_info() {
    echo -e "${GREEN}=== Thông tin hệ thống ===${NC}"
    check_system
    
    echo -e "${CYAN}Network Information:${NC}"
    echo -e "${WHITE}Public IP:${NC} $(curl -s ifconfig.me)"
    echo -e "${WHITE}Private IP:${NC} $(hostname -I | awk '{print $1}')"
    echo -e "${WHITE}Hostname:${NC} $(hostname)"
    
    echo -e "\n${CYAN}Service Status:${NC}"
    services=("n8n" "nginx" "redis-server")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet $service; then
            echo -e "${WHITE}$service:${NC} ${GREEN}Running${NC}"
        else
            echo -e "${WHITE}$service:${NC} ${RED}Stopped${NC}"
        fi
    done
    
    echo -e "\n${CYAN}Port Usage:${NC}"
    netstat -tlnp 2>/dev/null | grep -E ":(80|443|5678|6379)" | while read line; do
        port=$(echo $line | awk '{print $4}' | cut -d: -f2)
        echo -e "${WHITE}Port $port:${NC} ${GREEN}Open${NC}"
    done
}

# Main menu
show_menu() {
    show_header
    echo -e "${WHITE}1)${NC}  Cai dat N8N                          ${WHITE}6)${NC}  ${YELLOW}Export tat ca (workflow & credentials)${NC}"
    echo -e "${WHITE}2)${NC}  Thay doi ten mien                    ${WHITE}7)${NC}  Import workflow & credentials"
    echo -e "${WHITE}3)${NC}  Nang cap phien ban N8N               ${WHITE}8)${NC}  ${GREEN}Lay thong tin Redis${NC}"
    echo -e "${WHITE}4)${NC}  Tat xac thuc 2 buoc (2FA/MFA)        ${WHITE}9)${NC}  ${RED}Xoa N8N va cai dat lai${NC}"
    echo -e "${WHITE}5)${NC}  Dat lai thong tin dang nhap          ${WHITE}10)${NC} ${BLUE}Thong tin he thong${NC}"
    echo "--------------------------------------------------------------------------------"
    echo -n -e "${WHITE}Nhap lua chon cua ban (1-10) [ 0 = Thoat ]:${NC} "
}

# Main loop
main() {
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Vui lòng chạy với quyền root: sudo server-manager${NC}"
        exit 1
    fi
    
    while true; do
        show_menu
        read choice
        
        case $choice in
            1) install_n8n ;;
            2) change_domain ;;
            3) update_n8n ;;
            4) setup_2fa ;;
            5) reset_credentials ;;
            6) export_data ;;
            7) import_data ;;
            8) get_redis_info ;;
            9) delete_n8n ;;
            10) show_system_info ;;
            0)
                echo -e "${GREEN}Cảm ơn bạn đã sử dụng Server Manager!${NC}"
                echo -e "${CYAN}Visit: https://bietdoitinhnhue.com${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Lựa chọn không hợp lệ. Vui lòng thử lại.${NC}"
                ;;
        esac
        
        echo ""
        read -p "Nhấn Enter để tiếp tục..."
    done
}

# Start main program
main "$@"
MAIN_SCRIPT_EOF

    chmod +x "$SCRIPT_PATH"
    echo -e "${GREEN}✓ Server Manager đã được tạo${NC}"
}

# Create uninstaller
create_uninstaller() {
    cat > "/usr/local/bin/server-manager-uninstall" << 'UNINSTALL_EOF'
#!/bin/bash

echo "Đang gỡ bỏ Server Manager..."

# Remove main script
rm -f /usr/local/bin/server-manager

# Remove uninstaller
rm -f /usr/local/bin/server-manager-uninstall

echo "✓ Server Manager đã được gỡ bỏ hoàn toàn"
echo "Lưu ý: Dữ liệu N8N và các service vẫn được giữ lại"
UNINSTALL_EOF

    chmod +x "/usr/local/bin/server-manager-uninstall"
}

# Main installation function
main() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                        Chúc mừng bạn đã cài đặt thành công n8n                 ║${NC}"
    echo -e "${CYAN}║                          Powered by bietdoitinhnhue.com                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    check_root
    check_ubuntu
    install_dependencies
    create_main_script
    create_uninstaller
    
    echo ""
    echo -e "${GREEN}✓ Cài đặt hoàn tất!${NC}"
    echo ""
    echo -e "${CYAN}Cách sử dụng:${NC}"
    echo -e "${WHITE}  • Chạy Server Manager:${NC} ${YELLOW}server-manager${NC}"
    echo -e "${WHITE}  • Gỡ bỏ hoàn toàn:${NC} ${YELLOW}server-manager-uninstall${NC}"
    echo ""
    echo -e "${BLUE}Khởi chạy ngay bây giờ? (y/n):${NC} "
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        exec "$SCRIPT_PATH"
    fi
}

# Run main function
main "$@"
