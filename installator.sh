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
    echo -e "${DIM}${CYAN}│                    Compatible avec Debian 12                     │${RESET}"
    echo -e "${DIM}${CYAN}│                Installation automatisée et optimisée             │${RESET}"
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
    
    if [[ -f "install_glpi.sh" ]]; then
        sudo chmod +x install_glpi.sh
        print_step "Lancement de l'installation glpi..."
        ./install_glpi.sh
        print_success "Installation glpi terminée"
    else
        print_error "Fichier install_glpi.sh non trouvé"
        print_info "Assurez-vous que le fichier se trouve dans le même répertoire"
    fi
}

# Installation Zabbix
install_zabbix() {
    print_header "INSTALLATION DE ZABBIX"
    
    if [[ -f "install_zabbix.sh" ]]; then
        sudo chmod +x install_zabbix.sh
        print_step "Lancement de l'installation Zabbix..."
        ./install_zabbix.sh
        print_success "Installation Zabbix terminée"
    else
        print_error "Fichier install_zabbix.sh non trouvé"
        print_info "Assurez-vous que le fichier se trouve dans le même répertoire"
    fi
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
    read -p "Confirmer l'installation ? (o/N) : " confirm
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
            read -p "Appuyez sur Entrée pour revenir au menu..."
            ;;
        2)
            if confirm_installation "Zabbix"; then
                install_zabbix
            else
                print_warning "Installation annulée"
            fi
            echo
            read -p "Appuyez sur Entrée pour revenir au menu..."
            ;;
        3)
            if confirm_installation "XiVO"; then
                install_xivo
            else
                print_warning "Installation annulée"
            fi
            echo
            read -p "Appuyez sur Entrée pour revenir au menu..."
            ;;
        4)
            if confirm_installation "Samba AD"; then
                install_sambaAD
            else
                print_warning "Installation annulée"
            fi
            echo
            read -p "Appuyez sur Entrée pour revenir au menu..."
            ;;
        5)
            if confirm_installation "WordPress"; then
                install_wordpress
            else
                print_warning "Installation annulée"
            fi
            echo
            read -p "Appuyez sur Entrée pour revenir au menu..."
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
