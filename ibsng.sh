#!/bin/bash

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

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

# Function to check Docker installation
function check_docker_installation() {
    if ! command -v docker &> /dev/null || ! command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}[!] Docker and Docker Compose not found. Installing...${NC}"
        
        # Try initial installation
        if ! bash <(curl -sSL https://get.docker.com); then
            echo -e "${RED}[!] Docker installation failed - possible sanctions issue${NC}"
            
            read -p "Do you want to use Shecan DNS for installation? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                set_shecan_dns
                
                # Retry installation with Shecan DNS
                if ! bash <(curl -sSL https://get.docker.com); then
                    restore_old_dns
                    echo -e "${RED}[!] Docker installation failed even with Shecan DNS. Please install manually.${NC}"
                    exit 1
                fi
                
                restore_old_dns
            else
                echo -e "${RED}[!] Installation aborted. Please install manually.${NC}"
                exit 1
            fi
        fi
        
        # Verify installation
        if ! command -v docker &> /dev/null || ! command -v docker-compose &> /dev/null; then
            echo -e "${RED}[!] Docker installation failed. Please install manually.${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}[✓] Docker installed successfully.${NC}"
    else
        echo -e "${GREEN}[✓] Docker and Docker Compose are already installed.${NC}"
    fi
}

# Function to set Shecan DNS
function set_shecan_dns() {
    echo -e "${YELLOW}[!] Temporarily setting Shecan DNS...${NC}"
    OLD_RESOLV=$(cat /etc/resolv.conf)
    echo "nameserver 178.22.122.100" > /etc/resolv.conf
    echo "nameserver 185.51.200.2" >> /etc/resolv.conf
}

# Function to restore original DNS
function restore_old_dns() {
    echo -e "${YELLOW}[!] Restoring original DNS...${NC}"
    echo "$OLD_RESOLV" > /etc/resolv.conf
}

# Function to get public IP
function get_public_ip() {
    PUBLIC_IP=$(curl -s ifconfig.me)
    if [ -z "$PUBLIC_IP" ]; then
        PUBLIC_IP="localhost"
    fi
    echo -e "${BLUE}[i] Server Public IP: ${PUBLIC_IP}${NC}"
}

# Function to get ports from user
function get_ports() {
    read -p "Web Port (default 80): " WEB_PORT
    WEB_PORT=${WEB_PORT:-80}
    
    read -p "RADIUS Authentication Port (default 1812): " RADIUS_AUTH_PORT
    RADIUS_AUTH_PORT=${RADIUS_AUTH_PORT:-1812}
    
    read -p "RADIUS Accounting Port (default 1813): " RADIUS_ACCT_PORT
    RADIUS_ACCT_PORT=${RADIUS_ACCT_PORT:-1813}
}

# Function to create docker-compose file
function create_docker_compose() {
    mkdir -p /opt/ibsng
    cat > /opt/ibsng/docker-compose.yml <<EOL
version: '3.8'

services:
  ibsng:
    image: epsil0n/ibsng:latest
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
    
    echo -e "${GREEN}[✓] docker-compose file created at /opt/ibsng/docker-compose.yml${NC}"
}

# Function to run container and show info
function run_container_and_show_info() {
    cd /opt/ibsng
    
    # Start container
    echo -e "${YELLOW}[!] Starting IBSng container...${NC}"
    if ! docker-compose up -d; then
        echo -e "${RED}[!] Container startup failed.${NC}"
        
        read -p "Do you want to use Shecan DNS to download the image? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            set_shecan_dns
            
            # Remove failed container and retry
            docker-compose down
            docker rmi epsil0n/ibsng:latest
            
            if ! docker-compose up -d; then
                restore_old_dns
                echo -e "${RED}[!] Container startup failed even with Shecan DNS.${NC}"
                exit 1
            fi
            
            restore_old_dns
        else
            echo -e "${RED}[!] Container startup aborted.${NC}"
            exit 1
        fi
    fi
    
    # Show access information
    echo -e "${GREEN}[✓] IBSng container started successfully.${NC}"
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║           IBSng Access Information          ║"
    echo "╠══════════════════════════════════════════════╣"
    echo "║ Management Panel: http://${PUBLIC_IP}:${WEB_PORT}/IBSng/admin/"
    echo "║ Username: system                             "
    echo "║ Password: admin                              "
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Function for backup
function backup() {
    echo -e "${YELLOW}[!] Creating backup...${NC}"
    
    # Execute commands in container
    docker exec -it ibsng /bin/bash -c "service IBSng stop"
    docker exec -it ibsng /bin/bash -c "/usr/bin/psql -d IBSng -U ibs -c \"Truncate Table connection_log_details , internet_bw_snapshot , connection_log , internet_onlines_snapshot\""
    docker exec -it ibsng /bin/bash -c "service IBSng start"
    docker exec -it ibsng /bin/bash -c "rm -rf /var/lib/pgsql/IBSng.bak"
    docker exec -it ibsng /bin/bash -c "rm -rf /var/www/html/IBSng.bak"
    docker exec -it ibsng /bin/bash -c "su - postgres -c 'pg_dump IBSng > IBSng.bak'"
    
    # Copy backup to host
    docker cp ibsng:/var/lib/pgsql/IBSng.bak /root/
    
    # Compress backup
    gzip /root/IBSng.bak
    BACKUP_FILE="/root/IBSng_$(date +%Y%m%d_%H%M%S).bak.gz"
    mv /root/IBSng.bak.gz "$BACKUP_FILE"
    
    echo -e "${GREEN}[✓] Backup created successfully: ${BACKUP_FILE}${NC}"
}

# Function for restore
function restore() {
    read -p "Backup file path (e.g., /root/IBSng_20230101_120000.bak.gz): " BACKUP_FILE
    
    if [ ! -f "$BACKUP_FILE" ]; then
        echo -e "${RED}[!] Backup file not found!${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}[!] Restoring backup...${NC}"
    
    # Decompress backup
    gunzip -c "$BACKUP_FILE" > /root/IBSng_restore.bak
    
    # Copy to container
    docker cp /root/IBSng_restore.bak ibsng:/var/lib/pgsql/IBSng.bak
    
    # Execute restore commands in container
    docker exec -it ibsng /bin/bash -c "service IBSng stop"
    docker exec -it ibsng /bin/bash -c "su - postgres -c 'dropdb IBSng'"
    docker exec -it ibsng /bin/bash -c "su - postgres -c 'createdb IBSng'"
    docker exec -it ibsng /bin/bash -c "su - postgres -c 'createlang plpgsql IBSng'"
    docker exec -it ibsng /bin/bash -c "su - postgres -c 'psql IBSng < /var/lib/pgsql/IBSng.bak'"
    docker exec -it ibsng /bin/bash -c "service IBSng start"
    
    # Cleanup
    rm -f /root/IBSng_restore.bak
    
    echo -e "${GREEN}[✓] Restore completed successfully.${NC}"
}

# Function to remove container and image
function remove() {
    echo -e "${YELLOW}[!] Removing container and image...${NC}"
    
    cd /opt/ibsng
    docker-compose down
    docker rmi epsil0n/ibsng:latest
    
    echo -e "${GREEN}[✓] Container and image removed successfully.${NC}"
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
