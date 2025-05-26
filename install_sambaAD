#!/bin/bash

# Script d'installation et configuration de Samba AD
# Compatible avec Ubuntu/Debian et CentOS/RHEL

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction d'affichage
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[ATTENTION]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERREUR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Vérification des privilèges root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Ce script doit être exécuté en tant que root"
        exit 1
    fi
}

# Détection de la distribution
detect_os() {
    if [[ -f /etc/redhat-release ]]; then
        OS="centos"
        print_status "Distribution détectée: CentOS/RHEL"
    elif [[ -f /etc/debian_version ]]; then
        OS="debian"
        print_status "Distribution détectée: Ubuntu/Debian"
    else
        print_error "Distribution non supportée"
        exit 1
    fi
}

# Collecte des informations
collect_info() {
    print_header "COLLECTE DES INFORMATIONS"
    
    # Nom du domaine
    while true; do
        read -p "Nom du domaine (ex: exemple.local): " DOMAIN_NAME
        if [[ $DOMAIN_NAME =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]*\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            print_error "Format de domaine invalide. Utilisez le format: nom.extension"
        fi
    done
    
    # Nom NetBIOS
    NETBIOS_NAME=$(echo $DOMAIN_NAME | cut -d'.' -f1 | tr '[:lower:]' '[:upper:]')
    read -p "Nom NetBIOS [$NETBIOS_NAME]: " input
    NETBIOS_NAME=${input:-$NETBIOS_NAME}
    
    # Mot de passe administrateur
    while true; do
        read -s -p "Mot de passe administrateur du domaine: " ADMIN_PASSWORD
        echo
        read -s -p "Confirmez le mot de passe: " ADMIN_PASSWORD_CONFIRM
        echo
        if [[ "$ADMIN_PASSWORD" == "$ADMIN_PASSWORD_CONFIRM" ]]; then
            if [[ ${#ADMIN_PASSWORD} -ge 8 ]]; then
                break
            else
                print_error "Le mot de passe doit contenir au moins 8 caractères"
            fi
        else
            print_error "Les mots de passe ne correspondent pas"
        fi
    done
    
    # Adresses DNS
    read -p "Serveur DNS primaire (laissez vide pour 8.8.8.8): " DNS1
    DNS1=${DNS1:-8.8.8.8}
    
    read -p "Serveur DNS secondaire (laissez vide pour 8.8.4.4): " DNS2
    DNS2=${DNS2:-8.8.4.4}
    
    # Interface réseau
    echo "Interfaces réseau disponibles:"
    ip link show | grep -E '^[0-9]+: ' | cut -d' ' -f2 | tr -d ':' | grep -v lo
    read -p "Interface réseau à utiliser: " INTERFACE
    
    # Récupération de l'IP
    IP_ADDRESS=$(ip addr show $INTERFACE | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1 | head -n1)
    read -p "Adresse IP du serveur [$IP_ADDRESS]: " input
    IP_ADDRESS=${input:-$IP_ADDRESS}
    
    # Résumé des informations
    print_header "RÉSUMÉ DE LA CONFIGURATION"
    echo "Domaine: $DOMAIN_NAME"
    echo "NetBIOS: $NETBIOS_NAME"
    echo "IP du serveur: $IP_ADDRESS"
    echo "Interface: $INTERFACE"
    echo "DNS primaire: $DNS1"
    echo "DNS secondaire: $DNS2"
    echo
    
    read -p "Confirmer la configuration? (o/N): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[oO]$ ]]; then
        print_error "Installation annulée"
        exit 1
    fi
}

# Installation des paquets
install_packages() {
    print_header "INSTALLATION DES PAQUETS"
    
    if [[ "$OS" == "debian" ]]; then
        print_status "Mise à jour des paquets..."
        apt update
        
        print_status "Installation des paquets Samba..."
        apt install -y samba samba-dsdb-modules samba-vfs-modules winbind libpam-winbind libnss-winbind libpam-krb5 krb5-config krb5-user dnsutils chrony
        
    elif [[ "$OS" == "centos" ]]; then
        print_status "Mise à jour des paquets..."
        yum update -y
        
        print_status "Installation des paquets Samba..."
        yum install -y samba samba-dc samba-winbind-clients krb5-workstation bind-utils chrony
    fi
}

# Configuration du nom d'hôte
configure_hostname() {
    print_header "CONFIGURATION DU NOM D'HÔTE"
    
    HOSTNAME="dc1.${DOMAIN_NAME}"
    print_status "Configuration du hostname: $HOSTNAME"
    
    hostnamectl set-hostname $HOSTNAME
    
    # Mise à jour de /etc/hosts
    if ! grep -q "$IP_ADDRESS $HOSTNAME" /etc/hosts; then
        echo "$IP_ADDRESS $HOSTNAME dc1" >> /etc/hosts
    fi
}

# Configuration de Chrony/NTP
configure_time() {
    print_header "CONFIGURATION DE LA SYNCHRONISATION TEMPORELLE"
    
    if [[ "$OS" == "debian" ]]; then
        systemctl enable chrony
        systemctl start chrony
    elif [[ "$OS" == "centos" ]]; then
        systemctl enable chronyd
        systemctl start chronyd
    fi
    
    print_status "Synchronisation temporelle activée"
}

# Arrêt des services existants
stop_services() {
    print_header "ARRÊT DES SERVICES EXISTANTS"
    
    print_status "Arrêt des services Samba..."
    systemctl stop smbd nmbd winbind 2>/dev/null || true
    systemctl disable smbd nmbd winbind 2>/dev/null || true
}

# Sauvegarde de la configuration existante
backup_config() {
    print_header "SAUVEGARDE DE LA CONFIGURATION"
    
    if [[ -f /etc/samba/smb.conf ]]; then
        print_status "Sauvegarde de smb.conf..."
        cp /etc/samba/smb.conf /etc/samba/smb.conf.backup.$(date +%Y%m%d_%H%M%S)
    fi
}

# Provisioning du domaine
provision_domain() {
    print_header "PROVISIONING DU DOMAINE"
    
    print_status "Création du domaine Active Directory..."
    
    # Suppression de l'ancien smb.conf
    rm -f /etc/samba/smb.conf
    
    # Provisioning
    samba-tool domain provision \
        --use-rfc2307 \
        --server-role=dc \
        --function-level=2008_R2 \
        --realm="$DOMAIN_NAME" \
        --domain="$NETBIOS_NAME" \
        --adminpass="$ADMIN_PASSWORD" \
        --dns-backend=SAMBA_INTERNAL
    
    print_status "Domaine provisionné avec succès"
}

# Configuration DNS
configure_dns() {
    print_header "CONFIGURATION DNS"
    
    # Configuration de resolv.conf
    print_status "Configuration de resolv.conf..."
    
    cat > /etc/resolv.conf << EOF
search $DOMAIN_NAME
nameserver $IP_ADDRESS
nameserver $DNS1
nameserver $DNS2
EOF
    
    # Protection contre les modifications automatiques
    chattr +i /etc/resolv.conf 2>/dev/null || true
}

# Configuration de Kerberos
configure_kerberos() {
    print_header "CONFIGURATION KERBEROS"
    
    print_status "Copie de la configuration Kerberos..."
    cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
}

# Démarrage des services
start_services() {
    print_header "DÉMARRAGE DES SERVICES"
    
    print_status "Activation et démarrage de Samba AD..."
    systemctl enable samba-ad-dc
    systemctl start samba-ad-dc
    
    print_status "Vérification du statut..."
    sleep 5
    
    if systemctl is-active --quiet samba-ad-dc; then
        print_status "Service Samba AD démarré avec succès"
    else
        print_error "Échec du démarrage du service Samba AD"
        print_error "Vérifiez les logs: journalctl -u samba-ad-dc"
        exit 1
    fi
}

# Tests de validation
run_tests() {
    print_header "TESTS DE VALIDATION"
    
    print_status "Test de résolution DNS..."
    if nslookup $DOMAIN_NAME localhost; then
        print_status "✓ Résolution DNS OK"
    else
        print_warning "⚠ Problème de résolution DNS"
    fi
    
    print_status "Test d'authentification Kerberos..."
    if echo "$ADMIN_PASSWORD" | kinit administrator@$(echo $DOMAIN_NAME | tr '[:lower:]' '[:upper:]'); then
        print_status "✓ Authentification Kerberos OK"
        klist
    else
        print_warning "⚠ Problème d'authentification Kerberos"
    fi
    
    print_status "Test de connectivité LDAP..."
    if samba-tool domain level show; then
        print_status "✓ Connectivité LDAP OK"
    else
        print_warning "⚠ Problème de connectivité LDAP"
    fi
}

# Affichage des informations finales
show_final_info() {
    print_header "INSTALLATION TERMINÉE"
    
    echo -e "${GREEN}Le domaine Active Directory a été configuré avec succès!${NC}"
    echo
    echo "Informations du domaine:"
    echo "- Domaine: $DOMAIN_NAME"
    echo "- NetBIOS: $NETBIOS_NAME"
    echo "- Serveur: $IP_ADDRESS"
    echo "- Administrateur: administrator@$DOMAIN_NAME"
    echo
    echo "Commandes utiles:"
    echo "- Lister les utilisateurs: samba-tool user list"
    echo "- Créer un utilisateur: samba-tool user create <nom>"
    echo "- Lister les groupes: samba-tool group list"
    echo "- Vérifier la réplication: samba-tool drs showrepl"
    echo "- Logs: journalctl -u samba-ad-dc -f"
    echo
    echo "Prochaines étapes:"
    echo "1. Configurer les clients pour utiliser ce serveur DNS ($IP_ADDRESS)"
    echo "2. Joindre les machines au domaine"
    echo "3. Créer des utilisateurs et groupes selon vos besoins"
    echo
    print_warning "N'oubliez pas de configurer votre firewall si nécessaire!"
    print_warning "Ports à ouvrir: 53 (DNS), 88 (Kerberos), 135 (RPC), 139/445 (SMB), 389/636 (LDAP), 464 (Kerberos passwd), 3268/3269 (Global Catalog)"
    print_warning "Redémarrer votre serveur"
}

# Fonction principale
main() {
    print_header "INSTALLATION SAMBA ACTIVE DIRECTORY"
    
    check_root
    detect_os
    collect_info
    install_packages
    configure_hostname
    configure_time
    stop_services
    backup_config
    provision_domain
    configure_dns
    configure_kerberos
    start_services
    run_tests
    show_final_info
}

# Gestion des erreurs
trap 'print_error "Une erreur est survenue. Vérifiez les logs ci-dessus."' ERR

# Exécution du script
main "$@"
