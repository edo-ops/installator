#!/bin/bash

#=============================================================================
# Script d'installation automatique de GLPI
# Version: 1.0
# Description: Installe GLPI avec Apache, MariaDB et PHP sur Ubuntu/Debian
#=============================================================================

set -euo pipefail  # Arrêt du script en cas d'erreur

#-----------------------------------------------------------------------------
# Configuration des couleurs pour l'affichage
#-----------------------------------------------------------------------------
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly RED='\033[0;31m'
readonly BOLD='\033[1m'
readonly RESET='\033[0m'

#-----------------------------------------------------------------------------
# Configuration par défaut
#-----------------------------------------------------------------------------
readonly GLPI_VERSION="10.0.11"
readonly WEB_ROOT="/var/www/html/glpi"
readonly GLPI_URL="https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tgz"

#-----------------------------------------------------------------------------
# Fonctions utilitaires
#-----------------------------------------------------------------------------
print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "=================================================="
    echo "  Installation automatique de GLPI ${GLPI_VERSION}"
    echo "=================================================="
    echo -e "${RESET}"
}

print_step() {
    echo -e "${CYAN}${BOLD}➤ $1${RESET}"
}

print_success() {
    echo -e "${GREEN}✓ $1${RESET}"
}

print_error() {
    echo -e "${RED}✗ Erreur: $1${RESET}" >&2
}

#-----------------------------------------------------------------------------
# Collecte des informations utilisateur
#-----------------------------------------------------------------------------
collect_database_info() {
    print_step "Configuration de la base de données"
    echo
    
    read -p "$(echo -e "${YELLOW}Nom de la base de données: ${RESET}")" db_name
    while [[ -z "$db_name" ]]; do
        echo -e "${RED}Le nom de la base de données ne peut pas être vide${RESET}"
        read -p "$(echo -e "${YELLOW}Nom de la base de données: ${RESET}")" db_name
    done
    
    read -p "$(echo -e "${YELLOW}Nom d'utilisateur MySQL: ${RESET}")" db_user
    while [[ -z "$db_user" ]]; do
        echo -e "${RED}Le nom d'utilisateur ne peut pas être vide${RESET}"
        read -p "$(echo -e "${YELLOW}Nom d'utilisateur MySQL: ${RESET}")" db_user
    done
    
    while true; do
        read -sp "$(echo -e "${YELLOW}Mot de passe MySQL: ${RESET}")" db_pass
        echo
        if [[ -n "$db_pass" ]]; then
            break
        fi
        echo -e "${RED}Le mot de passe ne peut pas être vide${RESET}"
    done
    
    echo
}

#-----------------------------------------------------------------------------
# Vérification des prérequis
#-----------------------------------------------------------------------------
check_prerequisites() {
    print_step "Vérification des prérequis"
    
    # Vérifier si le script est exécuté avec les privilèges sudo
    if [[ $EUID -eq 0 ]]; then
        print_error "Ce script ne doit pas être exécuté en tant que root"
        exit 1
    fi
    
    # Vérifier la disponibilité de sudo
    if ! command -v sudo &> /dev/null; then
        print_error "sudo n'est pas installé"
        exit 1
    fi
    
    print_success "Prérequis vérifiés"
}

#-----------------------------------------------------------------------------
# Mise à jour du système
#-----------------------------------------------------------------------------
update_system() {
    print_step "Mise à jour du système"
    
    sudo apt update -qq
    sudo apt upgrade -y -qq
    
    print_success "Système mis à jour"
}

#-----------------------------------------------------------------------------
# Installation des dépendances
#-----------------------------------------------------------------------------
install_dependencies() {
    print_step "Installation des dépendances"
    
    local packages=(
        apache2
        mariadb-server
        php
        php-curl
        php-gd
        php-intl
        php-mbstring
        php-xml
        php-zip
        php-bz2
        php-mysql
        php-apcu
        php-cli
        php-ldap
        unzip
        tar
        libapache2-mod-php
        wget
    )
    
    sudo apt install -y "${packages[@]}" > /dev/null 2>&1
    
    print_success "Dépendances installées"
}

#-----------------------------------------------------------------------------
# Téléchargement et installation de GLPI
#-----------------------------------------------------------------------------
install_glpi() {
    print_step "Téléchargement et installation de GLPI ${GLPI_VERSION}"
    
    # Création du répertoire web
    sudo mkdir -p "$WEB_ROOT"
    
    # Téléchargement de GLPI
    if ! wget -q "$GLPI_URL" -O /tmp/glpi.tgz; then
        print_error "Échec du téléchargement de GLPI"
        exit 1
    fi
    
    # Extraction et installation
    tar -xzf /tmp/glpi.tgz -C /tmp > /dev/null
    sudo cp -r /tmp/glpi/* "$WEB_ROOT/"
    
    # Nettoyage
    rm -rf /tmp/glpi /tmp/glpi.tgz
    
    # Configuration des permissions
    sudo chown -R www-data:www-data "$WEB_ROOT"
    sudo chmod -R 755 "$WEB_ROOT"
    
    print_success "GLPI installé dans $WEB_ROOT"
}

#-----------------------------------------------------------------------------
# Configuration de la base de données
#-----------------------------------------------------------------------------
configure_database() {
    print_step "Configuration de MariaDB"
    
    # Démarrage et activation de MariaDB
    sudo systemctl enable mariadb > /dev/null 2>&1
    sudo systemctl start mariadb
    
    # Configuration de la base de données
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`${db_name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null
    sudo mysql -e "CREATE USER IF NOT EXISTS '${db_user}'@'localhost' IDENTIFIED BY '${db_pass}';" 2>/dev/null
    sudo mysql -e "GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'localhost';" 2>/dev/null
    sudo mysql -e "FLUSH PRIVILEGES;" 2>/dev/null
    
    print_success "Base de données configurée"
}

#-----------------------------------------------------------------------------
# Configuration d'Apache
#-----------------------------------------------------------------------------
configure_apache() {
    print_step "Configuration d'Apache"
    
    # Activation du module rewrite
    sudo a2enmod rewrite > /dev/null 2>&1
    
    # Redémarrage d'Apache
    sudo systemctl restart apache2
    
    print_success "Apache configuré"
}

#-----------------------------------------------------------------------------
# Affichage des informations finales
#-----------------------------------------------------------------------------
display_final_info() {
    local server_ip
    server_ip=$(ip -o -4 addr show | awk '!/127.0.0.1/ && /inet/ {print $4}' | cut -d/ -f1 | head -n1)
    
    echo
    echo -e "${GREEN}${BOLD}=================================================="
    echo "  Installation terminée avec succès !"
    echo -e "==================================================${RESET}"
    echo
    echo -e "${GREEN}📌 Informations de connexion:${RESET}"
    echo -e "   ${BOLD}URL d'accès:${RESET} http://${server_ip}/glpi"
    echo -e "   ${BOLD}Base de données:${RESET} ${db_name}"
    echo -e "   ${BOLD}Utilisateur DB:${RESET} ${db_user}"
    echo
    echo -e "${YELLOW}⚠️  Prochaines étapes:${RESET}"
    echo "   1. Ouvrez votre navigateur à l'adresse ci-dessus"
    echo "   2. Suivez l'assistant d'installation de GLPI"
    echo "   3. Utilisez les informations de base de données ci-dessus"
    echo
}

#-----------------------------------------------------------------------------
# Fonction principale
#-----------------------------------------------------------------------------
main() {
    print_header
    
    check_prerequisites
    collect_database_info
    update_system
    install_dependencies
    install_glpi
    configure_database
    configure_apache
    display_final_info
}

#-----------------------------------------------------------------------------
# Gestion des erreurs
#-----------------------------------------------------------------------------
trap 'print_error "Installation interrompue"; exit 1' ERR INT TERM

#-----------------------------------------------------------------------------
# Exécution du script principal
#-----------------------------------------------------------------------------
main "$@"
