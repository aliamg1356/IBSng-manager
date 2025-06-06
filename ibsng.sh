#!/bin/bash

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to display progress bar
function show_progress() {
    local current=$1
    local total=$2
    local message=$3
    local width=50
    local percent=$((current * 100 / total))
    local progress=$((current * width / total))
    
    # Calculate remaining time (simple estimation)
    local elapsed=$((SECONDS - start_time))
    local remaining=$(( (elapsed * (total - current)) / (current > 0 ? current : 1) ))
    local mins=$((remaining / 60))
    local secs=$((remaining % 60))
    
    printf "\r${CYAN}[${PURPLE}%-${width}s${CYAN}] ${GREEN}%3d%%${CYAN} - %s ${YELLOW}(%02d:%02d remaining)${NC}" \
        "$(printf '#%.0s' $(seq 1 $progress))" \
        "$percent" \
        "$message" \
        "$mins" "$secs"
}

# Function to display logo
function show_logo() {
    clear
    echo -e "${PURPLE}"
    echo " ██╗   ██╗███████╗██╗  ██╗██╗  ██╗ █████╗ ██╗   ██╗ █████╗ "
    echo " ██║   ██║██╔════╝██║  ██║██║ ██╔╝██╔══██╗╚██╗ ██╔╝██╔══██╗"
    echo " ██║   ██║███████╗███████║█████╔╝ ███████║ ╚████╔╝ ███████║"
    echo " ██║   ██║╚════██║██╔══██║██╔═██╗ ██╔══██║  ╚██╔╝  ██╔══██║"
    echo " ╚██████╔╝███████║██║  ██║██║  ██╗██║  ██║   ██║   ██║  ██║"
    echo "  ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝"
    echo -e "${CYAN}          USHKAYA NET IBSng manager           ${NC}"
    echo -e "${BLUE}===================================================${NC}"
    echo
}

# Function to set Electro DNS
function set_electro_dns() {
    echo -e "${YELLOW}[!] Temporarily setting Electro DNS...${NC}"
    OLD_RESOLV=$(cat /etc/resolv.conf)
    echo "nameserver 78.157.42.100" > /etc/resolv.conf
    echo "nameserver 78.157.42.101" >> /etc/resolv.conf
}

# Function to restore original DNS
function restore_old_dns() {
    if [ -n "$OLD_RESOLV" ]; then
        echo -e "${YELLOW}[!] Restoring original DNS...${NC}"
        echo "$OLD_RESOLV" > /etc/resolv.conf
    fi
}

# Function to try Docker installation normally
function try_normal_install() {
    echo -e "${BLUE}[i] Trying normal Docker installation...${NC}"
    if bash <(curl -sSL https://get.docker.com); then
        return 0
    else
        return 1
    fi
}

# Function to install Docker with Electro DNS
function install_with_electro() {
    set_electro_dns
    echo -e "${BLUE}[i] Trying Docker installation with Electro DNS...${NC}"
    if bash <(curl -sSL https://get.docker.com); then
        restore_old_dns
        return 0
    else
        restore_old_dns
        return 1
    fi
}

# Function to install Docker manually
function install_docker_manual() {
    start_time=$SECONDS
    total_steps=10
    
    # Try normal installation first
    show_progress 1 $total_steps "Attempting normal Docker install..."
    if try_normal_install; then
        echo -e "\n${GREEN}[✓] Docker installed successfully without Electro DNS${NC}"
        return 0
    fi
    
    # If normal install failed, ask to use Electro
    echo -e "\n${RED}[!] Docker installation failed - possible sanctions issue${NC}"
    read -p "Do you want to use Electro DNS for installation? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}[!] Installation aborted. Please install manually.${NC}"
        exit 1
    fi
    
    # Proceed with Electro DNS
    show_progress 2 $total_steps "Installing with Electro DNS..."
    if install_with_electro; then
        echo -e "\n${GREEN}[✓] Docker installed successfully with Electro DNS${NC}"
    else
        echo -e "\n${RED}[!] Docker installation failed even with Electro DNS.${NC}"
        exit 1
    fi
    
    # Install Docker Compose
    show_progress 3 $total_steps "Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Start and enable Docker
    show_progress 4 $total_steps "Starting Docker service..."
    systemctl start docker
    
    show_progress 5 $total_steps "Enabling Docker on boot..."
    systemctl enable docker
    
    echo -e "\n${GREEN}[✓] Docker installed and configured successfully.${NC}"
}

# Function to check Docker installation and service
function check_docker_installation() {
    start_time=$SECONDS
    total_steps=4
    
    # Check if Docker is installed
    if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
        show_progress 1 $total_steps "Checking Docker installation..."
        echo -e "\n${GREEN}[✓] Docker and Docker Compose are already installed.${NC}"
        
        # Check if Docker service is running
        show_progress 2 $total_steps "Checking Docker service status..."
        if systemctl is-active --quiet docker; then
            echo -e "\n${GREEN}[✓] Docker service is already running.${NC}"
            return 0
        else
            show_progress 3 $total_steps "Starting Docker service..."
            if sudo systemctl start docker; then
                echo -e "\n${GREEN}[✓] Docker service started successfully.${NC}"
                return 0
            else
                echo -e "\n${RED}[!] Failed to start Docker service.${NC}"
                exit 1
            fi
        fi
    fi
    
    # If Docker is not installed, proceed with installation
    install_docker_manual
}

# Function to get public IP
function get_public_ip() {
    start_time=$SECONDS
    total_steps=1
    show_progress 1 $total_steps "Getting server IP address..."
    
    MAIN_IP=$(ip route get 1 | awk '{print $7; exit}' 2>/dev/null)
    
    if [[ -z "$MAIN_IP" || "$MAIN_IP" =~ ^(127.|172.17.) ]]; then
        MAIN_IP=$(hostname -I | awk '{print $1}' 2>/dev/null)
    fi
    
    if [[ -z "$MAIN_IP" || "$MAIN_IP" =~ ^(127.|172.17.) ]]; then
        MAIN_IP=$(ip addr show | grep -E 'inet (192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)' | awk '{print $2}' | cut -d/ -f1 | head -n1)
    fi
    
    if [[ -z "$MAIN_IP" ]]; then
        echo -e "\n${YELLOW}[!] Could not determine server IP, using 'localhost'${NC}"
        MAIN_IP="localhost"
    else
        echo -e "\n${BLUE}[i] Server Main IP: ${MAIN_IP}${NC}"
    fi
    
    PUBLIC_IP=$MAIN_IP
}

# Function to get ports from user
function get_ports() {
    start_time=$SECONDS
    total_steps=3
    
    show_progress 1 $total_steps "Getting web port..."
    read -p "Web Port (default 80): " WEB_PORT
    WEB_PORT=${WEB_PORT:-80}
    
    show_progress 2 $total_steps "Getting RADIUS auth port..."
    read -p "RADIUS Authentication Port (default 1812): " RADIUS_AUTH_PORT
    RADIUS_AUTH_PORT=${RADIUS_AUTH_PORT:-1812}
    
    show_progress 3 $total_steps "Getting RADIUS accounting port..."
    read -p "RADIUS Accounting Port (default 1813): " RADIUS_ACCT_PORT
    RADIUS_ACCT_PORT=${RADIUS_ACCT_PORT:-1813}
}

# Function to download and import Docker image
function download_and_import_image() {
    start_time=$SECONDS
    total_steps=3
    
    show_progress 1 $total_steps "Downloading IBSng Docker image..."
    IMAGE_URL="https://github.com/aliamg1356/IBSng-manager/releases/download/v1.24/ushkayanet-ibsng.tar"
    TEMP_FILE="/tmp/ushkayanet-ibsng.tar"
    
    # Try normal download first
    if ! curl -L -o "$TEMP_FILE" "$IMAGE_URL"; then
        echo -e "\n${RED}[!] Download failed - trying with Electro DNS...${NC}"
        set_electro_dns
        if ! curl -L -o "$TEMP_FILE" "$IMAGE_URL"; then
            restore_old_dns
            echo -e "\n${RED}[!] Failed to download image even with Electro DNS.${NC}"
            exit 1
        fi
        restore_old_dns
    fi
    
    show_progress 2 $total_steps "Importing Docker image..."
    if ! docker load -i "$TEMP_FILE"; then
        echo -e "\n${RED}[!] Failed to import Docker image.${NC}"
        exit 1
    fi
    
    show_progress 3 $total_steps "Cleaning up..."
    rm -f "$TEMP_FILE"
    
    echo -e "\n${GREEN}[✓] Docker image imported successfully.${NC}"
}

# Function to create docker-compose file
function create_docker_compose() {
    start_time=$SECONDS
    total_steps=2
    
    show_progress 1 $total_steps "Creating IBSng directory..."
    mkdir -p /opt/ibsng
    
    show_progress 2 $total_steps "Generating docker-compose file..."
    cat > /opt/ibsng/docker-compose.yml <<EOL
version: '3.8'

services:
  ibsng:
    image: ushkayanet-ibsng
    container_name: ibsng
    ports:
      - "${WEB_PORT}:80"           # Web Port (HTTP)
      - "${RADIUS_AUTH_PORT}:1812/udp"      # RADIUS Authentication Port
      - "${RADIUS_ACCT_PORT}:1813/udp"      # RADIUS Accounting Port
    restart: unless-stopped  # Auto-restart on unexpected stop
    networks:
      - ibsng_net

networks:
  ibsng_net:
    driver: bridge
EOL
    
    echo -e "\n${GREEN}[✓] docker-compose file created at /opt/ibsng/docker-compose.yml${NC}"
}

# Function to create backup (improved version)
function backup() {
    start_time=$SECONDS
    total_steps=7
    
    show_progress 1 $total_steps "Checking if IBSng container exists..."
    if ! docker ps -a --format '{{.Names}}' | grep -q '^ibsng$'; then
        echo -e "\n${RED}[!] IBSng container not found!${NC}"
        exit 1
    fi
    
    BACKUP_FILE="/root/ibsng_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    show_progress 2 $total_steps "Entering container shell..."
    docker exec -it ibsng /bin/bash -c "\
        service IBSng stop && \
        /usr/bin/psql -d IBSng -U ibs -c \"Truncate Table connection_log_details, internet_bw_snapshot, connection_log, internet_onlines_snapshot\" && \
        service IBSng start && \
        rm -rf /var/lib/pgsql/IBSng.bak && \
        rm -rf /var/www/html/IBSng.bak && \
        su - postgres -c 'pg_dump IBSng > /var/lib/pgsql/IBSng.bak' && \
        tar czf /tmp/ibsng_backup.tar.gz /var/lib/pgsql/IBSng.bak"
    
    show_progress 3 $total_steps "Copying backup from container..."
    docker cp ibsng:/tmp/ibsng_backup.tar.gz $BACKUP_FILE
    
    show_progress 4 $total_steps "Cleaning up inside container..."
    docker exec ibsng /bin/bash -c "rm -f /tmp/ibsng_backup.tar.gz /var/lib/pgsql/IBSng.bak"
    
    if [ -f "$BACKUP_FILE" ]; then
        echo -e "\n${GREEN}[✓] Backup created successfully at: $BACKUP_FILE${NC}"
        echo -e "${BLUE}Backup size: $(du -h $BACKUP_FILE | cut -f1)${NC}"
        echo -e "${BLUE}Backup date: $(date -r $BACKUP_FILE)${NC}"
    else
        echo -e "\n${RED}[!] Backup failed!${NC}"
        exit 1
    fi
}

# Function to restore backup (improved version)
function restore() {
    start_time=$SECONDS
    total_steps=6
    
    show_progress 1 $total_steps "Finding latest backup..."
    BACKUP_FILE=$(ls -t /root/ibsng_backup_*.tar.gz 2>/dev/null | head -n 1)
    
    if [ -z "$BACKUP_FILE" ]; then
        echo -e "\n${RED}[!] No backup files found in /root!${NC}"
        echo -e "${YELLOW}Backup files should start with 'ibsng_backup_' and be in /root directory.${NC}"
        exit 1
    fi
    
    echo -e "\n${BLUE}[i] Selected backup file: $BACKUP_FILE${NC}"
    echo -e "${BLUE}Backup date: $(stat -c %y $BACKUP_FILE)${NC}"
    echo -e "${BLUE}Backup size: $(du -h $BACKUP_FILE | cut -f1)${NC}"
    
    read -p "Are you sure you want to restore this backup? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}[!] Restoration canceled.${NC}"
        exit 0
    fi
    
    show_progress 2 $total_steps "Extracting backup file..."
    TEMP_DIR=$(mktemp -d)
    tar xzf $BACKUP_FILE -C $TEMP_DIR
    
    show_progress 3 $total_steps "Copying backup to container..."
    docker cp $TEMP_DIR/var/lib/pgsql/IBSng.bak ibsng:/var/lib/pgsql/IBSng.bak
    
    show_progress 4 $total_steps "Cleaning up temp files..."
    rm -rf $TEMP_DIR
    
    show_progress 5 $total_steps "Restoring database inside container..."
    docker exec -it ibsng /bin/bash -c "\
        service IBSng stop && \
        su - postgres -c '\
            dropdb IBSng && \
            createdb IBSng && \
            createlang plpgsql IBSng && \
            psql IBSng < /var/lib/pgsql/IBSng.bak' && \
        service IBSng start"
    
    show_progress 6 $total_steps "Final cleanup..."
    docker exec ibsng rm -f /var/lib/pgsql/IBSng.bak
    
    echo -e "\n${GREEN}[✓] Backup restored successfully from: $BACKUP_FILE${NC}"
}

# Function to remove container (improved version)
function remove() {
    start_time=$SECONDS
    total_steps=4
    
    show_progress 1 $total_steps "Checking if IBSng container exists..."
    if ! docker ps -a --format '{{.Names}}' | grep -q '^ibsng$'; then
        echo -e "\n${RED}[!] IBSng container not found!${NC}"
        exit 1
    fi
    
    read -p "Are you sure you want to completely remove IBSng container? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}[!] Removal canceled.${NC}"
        exit 0
    fi
    
    show_progress 2 $total_steps "Stopping and removing container..."
    cd /opt/ibsng
    docker compose down
    
    show_progress 3 $total_steps "Removing network..."
    docker network rm ibsng_net 2>/dev/null || true
    
    show_progress 4 $total_steps "Removing Docker image..."
    docker rmi ushkayanet-ibsng 2>/dev/null || true
    
    echo -e "\n${GREEN}[✓] IBSng container, network and image removed successfully!${NC}"
}

# Function to run container and show info
function run_container_and_show_info() {
    start_time=$SECONDS
    total_steps=2
    
    cd /opt/ibsng
    
    show_progress 1 $total_steps "Starting IBSng container..."
    if ! docker compose up -d; then
        echo -e "\n${RED}[!] Container startup failed.${NC}"
        exit 1
    fi
    
    # Show access information
    echo -e "\n${GREEN}[✓] IBSng container started successfully.${NC}"
    echo -e "${CYAN}"
    echo "=============================================="
    echo "         IBSng Access Information"
    echo "=============================================="
    echo -e "Management Panel: ${BLUE}http://${MAIN_IP}:${WEB_PORT}/IBSng/admin/${NC}"
    echo -e "Username: ${YELLOW}system${NC}"
    echo -e "Password: ${YELLOW}admin${NC}"
    echo "=============================================="
    echo -e "${NC}"
}

# Main function
function main() {
    show_logo
    
    echo -e "${BLUE}Please select an option:${NC}"
    echo "1) Install IBSng"
    echo "2) Create Backup"
    echo "3) Restore Backup"
    echo "4) Remove Container"
    echo "5) Exit"
    
    read -p "Your choice (1-5): " choice
    
    case $choice in
        1)
            check_docker_installation
            get_public_ip
            get_ports
            download_and_import_image
            create_docker_compose
            run_container_and_show_info
            ;;
        2)
            backup
            ;;
        3)
            restore
            ;;
        4)
            remove
            ;;
        5)
            echo -e "${GREEN}[✓] Exiting script.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}[!] Invalid option!${NC}"
            exit 1
            ;;
    esac
}

# Execute main function
main
