#!/bin/bash

#=============================================================================
# Script d'installation automatique de Zabbix Server
# Version: 1.0
# Description: Installe Zabbix 7.2 avec Apache, MariaDB et PHP sur Debian 12
#=============================================================================

set -euo pipefail  # Arrêt du script en cas d'erreur

#-----------------------------------------------------------------------------
# Configuration des couleurs pour l'affichage
#-----------------------------------------------------------------------------
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly RESET='\033[0m'

#-----------------------------------------------------------------------------
# Configuration par défaut
#-----------------------------------------------------------------------------
readonly ZABBIX_VERSION="7.2"
readonly DEBIAN_VERSION="debian12"
readonly ZABBIX_REPO_URL="https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/debian/pool/main/z/zabbix-release/zabbix-release_latest_${ZABBIX_VERSION}+${DEBIAN_VERSION}_all.deb"
readonly ZABBIX_CONFIG="/etc/zabbix/zabbix_server.conf"

#-----------------------------------------------------------------------------
# Variables globales
#-----------------------------------------------------------------------------
DB_NAME=""
DB_USER=""
DB_PASS=""

#-----------------------------------------------------------------------------
# Fonctions utilitaires
#-----------------------------------------------------------------------------
print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "=================================================="
    echo "  Installation automatique de Zabbix ${ZABBIX_VERSION}"
    echo "=================================================="
    echo -e "${RESET}"
}

print_step() {
    echo -e "\n${BLUE}${BOLD}➤ $1${RESET}"
}

print_success() {
    echo -e "${GREEN}✅ $1${RESET}"
}

print_error() {
    echo -e "${RED}❌ Erreur: $1${RESET}" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${RESET}"
}

#-----------------------------------------------------------------------------
# Vérification des prérequis système
#-----------------------------------------------------------------------------
check_prerequisites() {
    print_step "Vérification des prérequis système"
    
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
    
    # Vérifier la version de Debian
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        if [[ "$ID" != "debian" ]] || [[ "$VERSION_ID" != "12" ]]; then
            print_warning "Ce script est optimisé pour Debian 12"
            read -p "Continuer quand même ? (y/N): " continue_install
            if [[ "$continue_install" != "y" && "$continue_install" != "Y" ]]; then
                exit 0
            fi
        fi
    fi
    
    print_success "Prérequis vérifiés"
}

#-----------------------------------------------------------------------------
# Collecte des informations de base de données
#-----------------------------------------------------------------------------
collect_database_info() {
    print_step "Configuration de la base de données MySQL"
    echo -e "${CYAN}Veuillez fournir les informations pour la base de données Zabbix${RESET}"
    echo
    
    # Nom de la base de données
    read -p "$(echo -e "${YELLOW}Nom de la base de données: ${RESET}")" DB_NAME
    while [[ -z "$DB_NAME" ]]; do
        print_error "Le nom de la base de données ne peut pas être vide"
        read -p "$(echo -e "${YELLOW}Nom de la base de données: ${RESET}")" DB_NAME
    done
    
    # Nom d'utilisateur
    read -p "$(echo -e "${YELLOW}Nom d'utilisateur MySQL: ${RESET}")" DB_USER
    while [[ -z "$DB_USER" ]]; do
        print_error "Le nom d'utilisateur ne peut pas être vide"
        read -p "$(echo -e "${YELLOW}Nom d'utilisateur MySQL: ${RESET}")" DB_USER
    done
    
    # Mot de passe
    read -sp "$(echo -e "${YELLOW}Mot de passe MySQL: ${RESET}")" DB_PASS
    echo
    while [[ -z "$DB_PASS" ]]; do
        print_error "Le mot de passe ne peut pas être vide"
        read -sp "$(echo -e "${YELLOW}Mot de passe MySQL: ${RESET}")" DB_PASS
        echo
    done
    
    # Confirmation des paramètres
    echo
    echo -e "${CYAN}Récapitulatif de la configuration:${RESET}"
    echo -e "  ${BOLD}Base de données:${RESET} $DB_NAME"
    echo -e "  ${BOLD}Utilisateur:${RESET} $DB_USER"
    echo -e "  ${BOLD}Mot de passe:${RESET} [masqué]"
    echo
    
    read -p "$(echo -e "${YELLOW}Confirmer ces paramètres ? (Y/n): ${RESET}")" confirm
    if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
        print_error "Installation annulée par l'utilisateur"
        exit 0
    fi
}

#-----------------------------------------------------------------------------
# Installation du dépôt Zabbix
#-----------------------------------------------------------------------------
install_zabbix_repository() {
    print_step "Installation du dépôt officiel Zabbix"
    
    local temp_file="/tmp/zabbix-release.deb"
    
    # Téléchargement du paquet de dépôt
    if ! wget -q "$ZABBIX_REPO_URL" -O "$temp_file"; then
        print_error "Échec du téléchargement du dépôt Zabbix"
        exit 1
    fi
    
    # Installation du paquet de dépôt
    sudo dpkg -i "$temp_file" > /dev/null 2>&1
    
    # Nettoyage
    rm -f "$temp_file"
    
    print_success "Dépôt Zabbix configuré"
}

#-----------------------------------------------------------------------------
# Mise à jour des paquets système
#-----------------------------------------------------------------------------
update_system() {
    print_step "Mise à jour de la liste des paquets"
    
    sudo apt update -qq
    
    print_success "Liste des paquets mise à jour"
}

#-----------------------------------------------------------------------------
# Installation des paquets Zabbix et dépendances
#-----------------------------------------------------------------------------
install_zabbix_packages() {
    print_step "Installation des paquets Zabbix et dépendances"
    
    local packages=(
        zabbix-server-mysql
        zabbix-frontend-php
        zabbix-apache-conf
        zabbix-sql-scripts
        zabbix-agent
        mariadb-server
    )
    
    sudo apt install -y "${packages[@]}" > /dev/null 2>&1
    
    print_success "Paquets Zabbix installés"
}

#-----------------------------------------------------------------------------
# Configuration et démarrage de MariaDB
#-----------------------------------------------------------------------------
setup_mariadb() {
    print_step "Configuration et démarrage de MariaDB"
    
    # Activation et démarrage du service
    sudo systemctl enable mariadb > /dev/null 2>&1
    sudo systemctl start mariadb
    
    # Vérification du statut
    if ! sudo systemctl is-active --quiet mariadb; then
        print_error "MariaDB n'a pas pu être démarré"
        exit 1
    fi
    
    print_success "MariaDB configuré et démarré"
}

#-----------------------------------------------------------------------------
# Création de la base de données Zabbix
#-----------------------------------------------------------------------------
create_database() {
    print_step "Création de la base de données et de l'utilisateur"
    
    # Création de la base de données
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;" 2>/dev/null
    
    # Création de l'utilisateur
    sudo mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';" 2>/dev/null
    
    # Attribution des privilèges
    sudo mysql -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';" 2>/dev/null
    
    # Application des modifications
    sudo mysql -e "FLUSH PRIVILEGES;" 2>/dev/null
    
    print_success "Base de données et utilisateur créés"
}

#-----------------------------------------------------------------------------
# Importation du schéma Zabbix
#-----------------------------------------------------------------------------
import_zabbix_schema() {
    print_step "Importation du schéma de base de données Zabbix"
    
    # Activation temporaire de log_bin_trust_function_creators pour l'import
    sudo mysql -e "SET GLOBAL log_bin_trust_function_creators = 1;" 2>/dev/null
    
    # Import du schéma
    if ! zcat /usr/share/zabbix/sql-scripts/mysql/server.sql.gz | \
         mysql --default-character-set=utf8mb4 -u "${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" 2>/dev/null; then
        print_error "Échec de l'importation du schéma Zabbix"
        exit 1
    fi
    
    # Désactivation de log_bin_trust_function_creators
    sudo mysql -e "SET GLOBAL log_bin_trust_function_creators = 0;" 2>/dev/null
    
    print_success "Schéma Zabbix importé avec succès"
}

#-----------------------------------------------------------------------------
# Configuration du serveur Zabbix
#-----------------------------------------------------------------------------
configure_zabbix_server() {
    print_step "Configuration du serveur Zabbix"
    
    # Sauvegarde du fichier de configuration original
    sudo cp "$ZABBIX_CONFIG" "${ZABBIX_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Nettoyage des caractères de retour chariot (Windows)
    sudo sed -i 's/\r$//' "$ZABBIX_CONFIG"
    
    # Configuration des paramètres de base de données
    sudo sed -i "s/^#\?[[:space:]]*DBName[[:space:]]*=.*/DBName=${DB_NAME}/" "$ZABBIX_CONFIG"
    sudo sed -i "s/^#\?[[:space:]]*DBUser[[:space:]]*=.*/DBUser=${DB_USER}/" "$ZABBIX_CONFIG"
    sudo sed -i "s/^#\?[[:space:]]*DBPassword[[:space:]]*=.*/DBPassword=${DB_PASS}/" "$ZABBIX_CONFIG"
    
    # Validation de la configuration
    if ! sudo zabbix_server -c "$ZABBIX_CONFIG" -t > /dev/null 2>&1; then
        print_warning "La validation de la configuration a échoué, mais l'installation continue"
    fi
    
    print_success "Configuration du serveur Zabbix terminée"
}

#-----------------------------------------------------------------------------
# Démarrage et activation des services
#-----------------------------------------------------------------------------
start_services() {
    print_step "Démarrage et activation des services"
    
    local services=(
        zabbix-server
        zabbix-agent
        apache2
    )
    
    # Redémarrage des services
    for service in "${services[@]}"; do
        sudo systemctl restart "$service"
        sudo systemctl enable "$service" > /dev/null 2>&1
        
        # Vérification du statut
        if ! sudo systemctl is-active --quiet "$service"; then
            print_error "Le service $service n'a pas pu être démarré"
            exit 1
        fi
    done
    
    print_success "Tous les services sont actifs et configurés pour démarrer automatiquement"
}

#-----------------------------------------------------------------------------
# Affichage des informations finales
#-----------------------------------------------------------------------------
display_final_info() {
    local server_ip
    server_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    echo
    echo -e "${GREEN}${BOLD}=================================================="
    echo "  Installation Zabbix terminée avec succès !"
    echo -e "==================================================${RESET}"
    echo
    echo -e "${GREEN}🌐 Informations de connexion:${RESET}"
    echo -e "   ${BOLD}Interface web:${RESET} http://${server_ip}/zabbix"
    echo -e "   ${BOLD}Identifiants par défaut:${RESET}"
    echo -e "     ${CYAN}Utilisateur:${RESET} Admin"
    echo -e "     ${CYAN}Mot de passe:${RESET} zabbix"
    echo
    echo -e "${GREEN}📊 Informations de la base de données:${RESET}"
    echo -e "   ${BOLD}Base de données:${RESET} ${DB_NAME}"
    echo -e "   ${BOLD}Utilisateur:${RESET} ${DB_USER}"
    echo
    echo -e "${YELLOW}⚠️  Prochaines étapes importantes:${RESET}"
    echo "   1. Ouvrez votre navigateur à l'adresse ci-dessus"
    echo "   2. Terminez la configuration via l'interface web"
    echo "   3. ${BOLD}CHANGEZ le mot de passe par défaut${RESET} Admin/zabbix"
    echo "   4. Configurez vos premiers hôtes à surveiller"
    echo
    echo -e "${CYAN}💡 Conseils:${RESET}"
    echo "   • Sauvegarde de configuration: ${ZABBIX_CONFIG}.backup.*"
    echo "   • Logs du serveur: /var/log/zabbix/zabbix_server.log"
    echo "   • Documentation: https://www.zabbix.com/documentation/${ZABBIX_VERSION}"
    echo
}

#-----------------------------------------------------------------------------
# Fonction de nettoyage en cas d'erreur
#-----------------------------------------------------------------------------
cleanup_on_error() {
    print_error "Installation interrompue"
    echo -e "${YELLOW}Nettoyage en cours...${RESET}"
    
    # Arrêt des services si ils ont été démarrés
    for service in zabbix-server zabbix-agent; do
        if sudo systemctl is-enabled --quiet "$service" 2>/dev/null; then
            sudo systemctl stop "$service" 2>/dev/null || true
            sudo systemctl disable "$service" 2>/dev/null || true
        fi
    done
    
    exit 1
}

#-----------------------------------------------------------------------------
# Fonction principale
#-----------------------------------------------------------------------------
main() {
    print_header
    
    check_prerequisites
    collect_database_info
    install_zabbix_repository
    update_system
    install_zabbix_packages
    setup_mariadb
    create_database
    import_zabbix_schema
    configure_zabbix_server
    start_services
    display_final_info
}

#-----------------------------------------------------------------------------
# Gestion des erreurs et signaux
#-----------------------------------------------------------------------------
trap cleanup_on_error ERR INT TERM

#-----------------------------------------------------------------------------
# Exécution du script principal
#-----------------------------------------------------------------------------
main "$@"
