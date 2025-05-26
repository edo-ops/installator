#!/bin/bash

# ═══════════════════════════════════════════════════════════════════
#                    INSTALLATEUR MULTI-SERVICES
#                      Version 2.0 - Debian 12
# ═══════════════════════════════════════════════════════════════════

# Couleurs et styles
declare -r RED="\e[31m"
declare -r GREEN="\e[32m"
declare -r YELLOW="\e[33m"
declare -r BLUE="\e[34m"
declare -r MAGENTA="\e[35m"
declare -r CYAN="\e[36m"
declare -r WHITE="\e[37m"
declare -r BOLD="\e[1m"
declare -r DIM="\e[2m"
declare -r RESET="\e[0m"

# Caractères spéciaux
declare -r CHECK="✓"
declare -r CROSS="✗"
declare -r ARROW="→"
declare -r STAR="★"
declare -r GEAR="⚙"
declare -r ROCKET="🚀"
declare -r LOCK="🔐"

# ═══════════════════════════════════════════════════════════════════
#                           FONCTIONS UTILITAIRES
# ═══════════════════════════════════════════════════════════════════

# Fonction pour afficher la bannière
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
....####.##....##..######..########....###....##.......##.........
.....##..###...##.##....##....##......##.##...##.......##.........
.....##..####..##.##..........##.....##...##..##.......##.........
.....##..##.##.##..######.....##....##.....##.##.......##.........
.....##..##..####.......##....##....#########.##.......##.........
.....##..##...###.##....##....##....##.....##.##.......##.........
....####.##....##..######.....##....##.....##.########.########...

                  INSTALLATEUR MULTI-SERVICES                   
                         Version 2.0                     
                                                                   
EOF
    echo -e "${RESET}"
    echo -e "${DIM}${CYAN}┌─────────────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${DIM}${CYAN}│ ${GEAR} Compatible avec Debian 12                                     │${RESET}"
    echo -e "${DIM}${CYAN}│ ${ROCKET} Installation automatisée et optimisée                        │${RESET}"
    echo -e "${DIM}${CYAN}└─────────────────────────────────────────────────────────────────┘${RESET}"
    echo
}

# Fonctions d'affichage améliorées
print_success() {
    echo -e "${GREEN}${BOLD}${CHECK} $1${RESET}"
}

print_error() {
    echo -e "${RED}${BOLD}${CROSS} $1${RESET}"
}

print_warning() {
    echo -e "${YELLOW}${BOLD}⚠ $1${RESET}"
}

print_info() {
    echo -e "${BLUE}${BOLD}ℹ $1${RESET}"
}

print_step() {
    echo -e "${MAGENTA}${BOLD}${ARROW} $1${RESET}"
}

print_header() {
    echo
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║ $1${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════╝${RESET}"
    echo
}

# Barre de progression
show_progress() {
    local duration=$1
    local message=$2
    local progress=0
    local width=50
    
    echo -ne "${BLUE}${BOLD}${message}${RESET} "
    
    while [ $progress -le $duration ]; do
        local percent=$((progress * 100 / duration))
        local filled=$((progress * width / duration))
        local empty=$((width - filled))
        
        printf "\r${BLUE}${BOLD}${message}${RESET} ["
        printf "%*s" $filled | tr ' ' '='
        printf "%*s" $empty | tr ' ' '-'
        printf "] %d%%" $percent
        
        sleep 0.1
        ((progress++))
    done
    echo -e " ${GREEN}${CHECK}${RESET}"
}

# Fonction pour corriger l'heure système
fix_system_time() {
    print_step "Correction automatique de l'heure système..."
    
    if ! command -v ntpdate &> /dev/null; then
        print_info "Installation de ntpdate..."
        sudo apt-get update -qq
        sudo apt-get install -y ntpdate > /dev/null 2>&1
    fi
    
    if sudo ntpdate -u pool.ntp.org > /dev/null 2>&1; then
        print_success "Heure système synchronisée"
    else
        print_warning "Impossible de synchroniser l'heure"
    fi
}

# ═══════════════════════════════════════════════════════════════════
#                       FONCTIONS D'INSTALLATION
# ═══════════════════════════════════════════════════════════════════

# Installation GLPI
install_glpi() {
    print_header "INSTALLATION DE GLPI"
    
    # Collecte des informations
    echo -e "${CYAN}${BOLD}Configuration de la base de données :${RESET}"
    echo -e "${DIM}┌─────────────────────────────────────┐${RESET}"
    read -p "${YELLOW}${BOLD}${LOCK} Nom de la base de données : ${RESET}" db_name
    read -p "${YELLOW}${BOLD}${LOCK} Utilisateur MariaDB : ${RESET}" db_user
    read -sp "${YELLOW}${BOLD}${LOCK} Mot de passe MariaDB : ${RESET}" db_pass
    echo -e "${DIM}└─────────────────────────────────────┘${RESET}"
    echo
    
    # Variables
    web_root="/var/www/glpi"
    glpi_version="10.0.11"
    glpi_url="https://github.com/glpi-project/glpi/releases/download/${glpi_version}/glpi-${glpi_version}.tgz"
    ip=$(ip -o -4 addr show | awk '!/127.0.0.1/ {print $4}' | cut -d/ -f1 | head -n1)

    fix_system_time

    print_step "Mise à jour du système..."
    show_progress 30 "Mise à jour en cours"
    sudo apt update -qq && sudo apt upgrade -y > /dev/null 2>&1

    print_step "Installation des dépendances..."
    show_progress 40 "Installation des paquets"
    sudo apt install -y apache2 mariadb-server php php-curl php-gd php-intl php-mbstring php-xml php-zip php-bz2 php-mysql php-apcu php-cli php-ldap libapache2-mod-php unzip tar > /dev/null 2>&1

    print_step "Téléchargement et installation de GLPI..."
    sudo mkdir -p "$web_root"
    if wget -q "$glpi_url" -O /tmp/glpi.tgz; then
        print_success "GLPI téléchargé"
    else
        print_error "Échec du téléchargement"
        return 1
    fi
    
    sudo tar -xzf /tmp/glpi.tgz -C /var/www/
    sudo mv /var/www/glpi-${glpi_version}/* "$web_root"
    sudo rm -rf /var/www/glpi-${glpi_version} /tmp/glpi.tgz
    sudo chown -R www-data:www-data "$web_root"
    sudo chmod -R 755 "$web_root"

    print_step "Configuration de MariaDB..."
    sudo systemctl enable --now mariadb > /dev/null 2>&1
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS ${db_name} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null
    sudo mysql -e "CREATE USER IF NOT EXISTS '${db_user}'@'localhost' IDENTIFIED BY '${db_pass}';" 2>/dev/null
    sudo mysql -e "GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_user}'@'localhost';" 2>/dev/null
    sudo mysql -e "FLUSH PRIVILEGES;" 2>/dev/null

    print_step "Configuration d'Apache..."
    sudo tee /etc/apache2/sites-available/glpi.conf > /dev/null <<EOF
Alias /glpi $web_root

<Directory $web_root>
    Options FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
EOF

    sudo a2enmod rewrite > /dev/null 2>&1
    sudo a2ensite glpi.conf > /dev/null 2>&1
    sudo a2dissite 000-default.conf > /dev/null 2>&1
    sudo systemctl reload apache2 > /dev/null 2>&1

    echo
    print_success "Installation de GLPI terminée avec succès !"
    echo -e "${GREEN}${BOLD}┌─────────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${GREEN}${BOLD}│ ${ROCKET} Accès : http://$ip/glpi                              │${RESET}"
    echo -e "${GREEN}${BOLD}│ ${STAR} Finalisez la configuration via l'interface web      │${RESET}"
    echo -e "${GREEN}${BOLD}└─────────────────────────────────────────────────────────────┘${RESET}"
    echo
}

# Installation Zabbix
install_zabbix() {
    print_header "INSTALLATION DE ZABBIX"
    
    echo -e "${CYAN}${BOLD}${LOCK} Configuration MySQL pour Zabbix :${RESET}"
    echo -e "${DIM}┌─────────────────────────────────────┐${RESET}"
    read -p "${YELLOW}${BOLD}Nom de la base de données : ${RESET}" DB_NAME
    read -p "${YELLOW}${BOLD}Utilisateur MySQL : ${RESET}" DB_USER
    read -sp "${YELLOW}${BOLD}Mot de passe MySQL : ${RESET}" DB_PASS
    echo -e "${DIM}└─────────────────────────────────────┘${RESET}"
    echo

    fix_system_time

    print_step "Installation du dépôt Zabbix..."
    if wget -q https://repo.zabbix.com/zabbix/7.2/release/debian/pool/main/z/zabbix-release/zabbix-release_latest_7.2+debian12_all.deb; then
        sudo dpkg -i zabbix-release_latest_7.2+debian12_all.deb > /dev/null 2>&1
        rm -f zabbix-release_latest_7.2+debian12_all.deb
        print_success "Dépôt Zabbix ajouté"
    fi
    
    sudo apt update -qq

    print_step "Installation des paquets Zabbix..."
    show_progress 50 "Installation en cours"
    sudo apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf \
                   zabbix-sql-scripts zabbix-agent mariadb-server > /dev/null 2>&1

    print_step "Configuration de MariaDB..."
    sudo systemctl enable --now mariadb > /dev/null 2>&1
    sudo mysql -e "CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;" 2>/dev/null
    sudo mysql -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';" 2>/dev/null
    sudo mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';" 2>/dev/null
    sudo mysql -e "FLUSH PRIVILEGES;" 2>/dev/null

    print_step "Importation du schéma Zabbix..."
    show_progress 60 "Importation en cours"
    zcat /usr/share/zabbix/sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -u ${DB_USER} -p${DB_PASS} ${DB_NAME} 2>/dev/null

    print_step "Configuration de Zabbix..."
    sudo sed -i "s/^#\?DBName=.*/DBName=${DB_NAME}/" /etc/zabbix/zabbix_server.conf
    sudo sed -i "s/^#\?DBUser=.*/DBUser=${DB_USER}/" /etc/zabbix/zabbix_server.conf
    sudo sed -i "s/^#\s*DBPassword=.*/DBPassword=${DB_PASS}/" /etc/zabbix/zabbix_server.conf

    print_step "Configuration Apache..."
    sudo tee /etc/apache2/sites-available/zabbix.conf > /dev/null <<EOF
Alias /zabbix /usr/share/zabbix

<Directory /usr/share/zabbix>
    Options FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
EOF

    sudo a2ensite zabbix.conf > /dev/null 2>&1
    sudo systemctl reload apache2 > /dev/null 2>&1

    print_step "Démarrage des services..."
    sudo systemctl restart zabbix-server zabbix-agent apache2 > /dev/null 2>&1
    sudo systemctl enable zabbix-server zabbix-agent apache2 > /dev/null 2>&1

    ip=$(ip -o -4 addr show | awk '!/127.0.0.1/ {print $4}' | cut -d/ -f1 | head -n1)
    
    echo
    print_success "Installation de Zabbix terminée avec succès !"
    echo -e "${GREEN}${BOLD}┌─────────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${GREEN}${BOLD}│ ${ROCKET} Accès : http://${ip}/zabbix                          │${RESET}"
    echo -e "${GREEN}${BOLD}│ ${LOCK} Login : Admin   │   Password : zabbix                │${RESET}"
    echo -e "${GREEN}${BOLD}└─────────────────────────────────────────────────────────────┘${RESET}"
    echo
}

# Installation XiVO
install_xivo() {
    print_header "INSTALLATION DE XIVO"
    
    if [[ -f "install_xivo.sh" ]]; then
        sudo chmod +x install_xivo.sh
        print_step "Lancement de l'installation XiVO..."
        sudo ./install_xivo.sh
        print_success "Installation XiVO terminée"
    else
        print_error "Fichier install_xivo.sh non trouvé"
        print_info "Assurez-vous que le fichier se trouve dans le même répertoire"
    fi
}

# Installation SambaAD
install_sambaAD() {
    print_header "INSTALLATION DE SAMBA AD"
    
    if [[ -f "install_sambaAD.sh" ]]; then
        sudo chmod +x install_sambaAD.sh
        print_step "Lancement de l'installation Samba AD..."
        sudo ./install_sambaAD.sh
        print_success "Installation Samba AD terminée"
    else
        print_error "Fichier install_sambaAD.sh non trouvé"
        print_info "Assurez-vous que le fichier se trouve dans le même répertoire"
    fi
}

# Installation WordPress
install_wordpress() {
    print_header "INSTALLATION DE WORDPRESS"
    
    if [[ -f "install_wordpress.sh" ]]; then
        sudo chmod +x install_wordpress.sh
        print_step "Lancement de l'installation WordPress..."
        sudo ./install_wordpress.sh
        print_success "Installation WordPress terminée"
    else
        print_error "Fichier install_wordpress.sh non trouvé"
        print_info "Assurez-vous que le fichier se trouve dans le même répertoire"
    fi
}

# Menu d'affichage
show_menu() {
    echo -e "${BOLD}${WHITE}┌─────────────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${BOLD}${WHITE}│                  QUE SOUHAITEZ-VOUS INSTALLER ?                 │${RESET}"
    echo -e "${BOLD}${WHITE}└─────────────────────────────────────────────────────────────────┘${RESET}"
    echo
    echo -e "${GREEN}${BOLD}  1)${RESET} ${STAR} GLPI          ${DIM}│ Gestion d'inventaire et helpdesk${RESET}"
    echo -e "${BLUE}${BOLD}  2)${RESET} ${STAR} Zabbix        ${DIM}│ Supervision et monitoring${RESET}"
    echo -e "${YELLOW}${BOLD}  3)${RESET} ${STAR} XiVO          ${DIM}│ Solution de téléphonie IP${RESET}"
    echo -e "${MAGENTA}${BOLD}  4)${RESET} ${STAR} Samba AD      ${DIM}│ Contrôleur de domaine Active Directory${RESET}"
    echo -e "${CYAN}${BOLD}  5)${RESET} ${STAR} WordPress     ${DIM}│ CMS et création de sites web${RESET}"
    echo
    echo -e "${RED}${BOLD}  6)${RESET} ${CROSS} Quitter"
    echo
    echo
    echo -ne "${BOLD}${WHITE} Votre choix : ${RESET}"
}

# Confirmation d'installation
confirm_installation() {
    local service=$1
    echo
    echo -e "${YELLOW}${BOLD}⚠ Vous êtes sur le point d'installer : ${service}${RESET}"
    echo -e "${DIM}Cette opération peut prendre plusieurs minutes.${RESET}"
    echo
    read -p "${BOLD}Confirmer l'installation ? (o/N) : ${RESET}" confirm
    [[ "$confirm" =~ ^[oO]$ ]]
}

# ═══════════════════════════════════════════════════════════════════
#                              MAIN LOOP
# ═══════════════════════════════════════════════════════════════════

# Boucle principale
while true; do
    show_banner
    show_menu
    read choice

    
    case "$choice" in
        1)
            if confirm_installation "GLPI"; then
                install_glpi
            else
                print_warning "Installation annulée"
            fi
            echo
            read -p "${GREEN}${BOLD}Appuyez sur Entrée pour revenir au menu...${RESET}"
            ;;
        2)
            if confirm_installation "Zabbix"; then
                install_zabbix
            else
                print_warning "Installation annulée"
            fi
            echo
            read -p "${GREEN}${BOLD}Appuyez sur Entrée pour revenir au menu...${RESET}"
            ;;
        3)
            if confirm_installation "XiVO"; then
                install_xivo
            else
                print_warning "Installation annulée"
            fi
            echo
            read -p "${GREEN}${BOLD}Appuyez sur Entrée pour revenir au menu...${RESET}"
            ;;
        4)
            if confirm_installation "Samba AD"; then
                install_sambaAD
            else
                print_warning "Installation annulée"
            fi
            echo
            read -p "${GREEN}${BOLD}Appuyez sur Entrée pour revenir au menu...${RESET}"
            ;;
        5)
            if confirm_installation "WordPress"; then
                install_wordpress
            else
                print_warning "Installation annulée"
            fi
            echo
            read -p "${GREEN}${BOLD}Appuyez sur Entrée pour revenir au menu...${RESET}"
            ;;
        6)
            echo
            print_success "Merci d'avoir utilisé l'installateur !"
            echo -e "${CYAN}${BOLD}Au revoir ! 👋${RESET}"
            echo
            exit 0
            ;;
        *)
            print_error "Choix invalide, veuillez réessayer"
            sleep 2
            ;;
    esac
done
