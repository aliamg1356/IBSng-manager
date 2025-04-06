#!/bin/bash

# Terminal Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global Variables
PROGRESS_WIDTH=50
START_TIME=$(date +%s)
LAST_SIZE=0
LAST_TIME=$START_TIME

# ========================
# PROGRESS FUNCTIONS
# ========================

function show_progress() {
    local current=$1
    local total=$2
    local speed=$3
    local elapsed=$(( $(date +%s) - START_TIME ))
    local remaining=$(( (total - current) * elapsed / current )) 2>/dev/null || remaining=0
    
    # Progress percentage
    local percent=$(( 100 * current / total ))
    [ $percent -gt 100 ] && percent=100
    
    # Progress bar
    local filled=$(( PROGRESS_WIDTH * percent / 100 ))
    local empty=$(( PROGRESS_WIDTH - filled ))
    local bar=$(printf "%${filled}s" | tr ' ' '=')
    local bar_empty=$(printf "%${empty}s")
    
    # Time formatting
    local elapsed_str=$(printf "%02d:%02d" $((elapsed/60)) $((elapsed%60)))
    local remaining_str=$(printf "%02d:%02d" $((remaining/60)) $((remaining%60)))
    
    echo -ne "\r[${CYAN}${bar}${bar_empty}${NC}] ${percent}% "
    echo -ne "| ${YELLOW}⬇ ${speed}MB/s${NC} "
    echo -ne "| ⏱️ ${elapsed_str}<${remaining_str} "
}

function calculate_speed() {
    local current_size=$1
    local current_time=$(date +%s)
    
    if [ $LAST_TIME -ne $START_TIME ]; then
        local size_diff=$(( current_size - LAST_SIZE ))
        local time_diff=$(( current_time - LAST_TIME ))
        
        if [ $time_diff -gt 0 ]; then
            echo $(echo "scale=2; $size_diff / 1024 / 1024 / $time_diff" | bc)
            return
        fi
    fi
    
    echo "0.00"
}

# ========================
# DNS MANAGEMENT
# ========================

function set_shecan_dns() {
    OLD_RESOLV=$(cat /etc/resolv.conf)
    echo -e "${YELLOW}[!] Setting Shecan DNS...${NC}"
    echo "nameserver 178.22.122.100" > /etc/resolv.conf
    echo "nameserver 185.51.200.2" >> /etc/resolv.conf
}

function restore_old_dns() {
    echo -e "${YELLOW}[!] Restoring original DNS...${NC}"
    echo "$OLD_RESOLV" > /etc/resolv.conf
}

# ========================
# DOCKER INSTALLATION
# ========================

function install_docker() {
    echo -e "${BLUE}[*] Starting Docker installation...${NC}"
    
    # Create log file
    LOG_FILE="/tmp/docker_install_$(date +%Y%m%d_%H%M%S).log"
    touch "$LOG_FILE"
    
    # Download with progress tracking
    echo -e "${CYAN}[*] Downloading Docker installer...${NC}"
    curl -#SLo /tmp/get-docker.sh https://get.docker.com &
    
    # Track download progress
    while ps -p $! >/dev/null; do
        CURRENT_SIZE=$(stat -c %s /tmp/get-docker.sh 2>/dev/null || echo 0)
        TOTAL_SIZE=$(curl -sI https://get.docker.com | grep -i content-length | awk '{print $2}' | tr -d '\r')
        [ -z "$TOTAL_SIZE" ] && TOTAL_SIZE=1000000
        
        SPEED=$(calculate_speed $CURRENT_SIZE)
        show_progress $CURRENT_SIZE $TOTAL_SIZE $SPEED
        
        LAST_SIZE=$CURRENT_SIZE
        LAST_TIME=$(date +%s)
        sleep 1
    done
    
    echo -e "\n${CYAN}[*] Executing installer...${NC}"
    chmod +x /tmp/get-docker.sh
    
    # Run installer with logging
    if ! bash /tmp/get-docker.sh 2>&1 | tee -a "$LOG_FILE"; then
        handle_install_error "$LOG_FILE"
        return 1
    fi
    
    echo -e "\n${GREEN}[✓] Docker installed successfully${NC}"
    return 0
}

function handle_install_error() {
    local log_file=$1
    
    echo -e "\n${RED}[!] Docker installation failed${NC}"
    
    # Handle rootless mode warning
    if grep -q "rootless mode" "$log_file"; then
        echo -e "${YELLOW}[!] Configuring rootless mode...${NC}"
        if ! dockerd-rootless-setuptool.sh install; then
            echo -e "${RED}[!] Failed to setup rootless mode${NC}"
            return 1
        fi
        echo -e "${GREEN}[✓] Rootless mode configured${NC}"
        return 0
    fi
    
    # Handle network issues
    if grep -q "connection timed out" "$log_file" || 
       grep -q "Failed to download" "$log_file"; then
        echo -e "${YELLOW}[!] Network issue detected. Retrying with Shecan DNS...${NC}"
        set_shecan_dns
        if ! install_docker; then
            restore_old_dns
            return 1
        fi
        restore_old_dns
        return 0
    fi
    
    echo -e "${RED}[!] Unknown installation error. Check log: $log_file${NC}"
    return 1
}

# ========================
# DOCKER POST-INSTALL
# ========================

function configure_docker() {
    echo -e "${BLUE}[*] Configuring Docker...${NC}"
    
    # Add user to docker group
    if ! grep -q docker /etc/group; then
        groupadd docker
    fi
    
    if [ "$(id -u)" -ne 0 ]; then
        usermod -aG docker "$(whoami)"
        echo -e "${YELLOW}[!] User added to docker group. You may need to logout/login${NC}"
    fi
    
    # Enable service
    systemctl enable docker.service
    systemctl enable containerd.service
    
    echo -e "${GREEN}[✓] Docker configured${NC}"
}

# ========================
# MAIN EXECUTION
# ========================

function main() {
    clear
    
    # Show banner
    echo -e "${CYAN}"
    echo "=============================================="
    echo "           Docker Installation Script         "
    echo "=============================================="
    echo -e "${NC}"
    
    # Check if Docker is already installed
    if command -v docker &>/dev/null; then
        echo -e "${GREEN}[✓] Docker is already installed${NC}"
        docker --version
        return 0
    fi
    
    # Installation process
    if ! install_docker; then
        echo -e "${RED}[!] Docker installation failed. See logs for details${NC}"
        return 1
    fi
    
    # Post-install configuration
    configure_docker
    
    # Verify installation
    echo -e "\n${BLUE}[*] Verifying installation...${NC}"
    docker run --rm hello-world
    
    echo -e "\n${GREEN}[✓] Docker setup completed successfully${NC}"
    echo -e "Start with: ${CYAN}docker info${NC}"
}

main "$@"
