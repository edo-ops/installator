#!/bin/bash

# Couleurs
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

# Fonction de la bannière
function show_banner() {
    clear
    echo -e "${BLUE}"
    echo "
.####.##....##..######..########....###....##.......##......
..##..###...##.##....##....##......##.##...##.......##......
..##..####..##.##..........##.....##...##..##.......##......
..##..##.##.##..######.....##....##.....##.##.......##......
..##..##..####.......##....##....#########.##.......##......
..##..##...###.##....##....##....##.....##.##.......##......
.####.##....##..######.....##....##.....##.########.########
"
    echo -e "${RESET}"
    echo -e "${YELLOW}Bienvenue dans l'installator !${RESET}"
    echo -e "${YELLOW}Fonctionne sous Debian 12${RESET}\n"
}

# Fonction pour corriger l'heure système
function fix_system_time() {
    echo -e "${YELLOW}Correction automatique de l'heure système...${RESET}"
    if ! command -v ntpdate &> /dev/null; then
        echo -e "${YELLOW}Installation de ntpdate...${RESET}"
        sudo apt-get update
        sudo apt-get install -y ntpdate
    fi
    sudo ntpdate -u pool.ntp.org
}

# Fonction d'installation GLPI
function install_glpi() {
    # Demande des variables nécessaires
    read -p "Donner un nom à la base de données : " db_name
    read -p "Donner un nom d'utilisateur MariaDB : " db_user
    read -sp "Donner un mot de passe pour MariaDB : " db_pass
    echo
    web_root="/var/www/glpi"
    glpi_version="10.0.11"
    glpi_url="https://github.com/glpi-project/glpi/releases/download/${glpi_version}/glpi-${glpi_version}.tgz"
    ip=$(ip -o -4 addr show | awk '!/127.0.0.1/ {print $4}' | cut -d/ -f1 | head -n1)

    fix_system_time

    echo -e "${YELLOW}Mise à jour du système...${RESET}"
    sudo apt update && sudo apt upgrade -y

    echo -e "${YELLOW}Installation des dépendances...${RESET}"
    sudo apt install -y apache2 mariadb-server php php-curl php-gd php-intl php-mbstring php-xml php-zip php-bz2 php-mysql php-apcu php-cli php-ldap libapache2-mod-php unzip tar

    echo -e "${YELLOW}Téléchargement et installation de GLPI...${RESET}"
    sudo mkdir -p "$web_root"
    wget -q "$glpi_url" -O /tmp/glpi.tgz
    sudo tar -xzf /tmp/glpi.tgz -C /var/www/
    sudo mv /var/www/glpi-${glpi_version}/* "$web_root"
    sudo rm -rf /var/www/glpi-${glpi_version} /tmp/glpi.tgz
    sudo chown -R www-data:www-data "$web_root"
    sudo chmod -R 755 "$web_root"

    echo -e "${YELLOW}Configuration de MariaDB...${RESET}"
    sudo systemctl enable --now mariadb
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS ${db_name} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    sudo mysql -e "CREATE USER IF NOT EXISTS '${db_user}'@'localhost' IDENTIFIED BY '${db_pass}';"
    sudo mysql -e "GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_user}'@'localhost';"
    sudo mysql -e "FLUSH PRIVILEGES;"

    echo -e "${YELLOW}Configuration d'Apache pour GLPI...${RESET}"
    sudo tee /etc/apache2/sites-available/glpi.conf > /dev/null <<EOF
Alias /glpi $web_root

<Directory $web_root>
    Options FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
EOF

    sudo a2enmod rewrite
    sudo a2ensite glpi.conf
    sudo a2dissite 000-default.conf
    sudo systemctl reload apache2

    echo -e "${GREEN}Installation terminée ! Accédez à GLPI via http://$ip/glpi${RESET}"
    echo -e "${YELLOW}N'oubliez pas de finir la configuration via l'interface web.${RESET}"
}

# Fonction d'installation Zabbix
function install_zabbix() {
    echo "🔐 Configuration MySQL pour Zabbix"
    read -p "Nom de la base de données : " DB_NAME
    read -p "Nom de l'utilisateur MySQL : " DB_USER
    read -s -p "Mot de passe MySQL : " DB_PASS
    echo ""

    fix_system_time

    echo -e "${YELLOW}1. Installation du dépôt Zabbix${RESET}"
    wget -q https://repo.zabbix.com/zabbix/7.2/release/debian/pool/main/z/zabbix-release/zabbix-release_latest_7.2+debian12_all.deb \
      && sudo dpkg -i zabbix-release_latest_7.2+debian12_all.deb >/dev/null \
      && rm -f zabbix-release_latest_7.2+debian12_all.deb
    sudo apt update -qq

    echo -e "${YELLOW}2. Installation des paquets Zabbix et MariaDB${RESET}"
    sudo apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf \
                   zabbix-sql-scripts zabbix-agent mariadb-server

    echo -e "${YELLOW}3. Démarrage de MariaDB${RESET}"
    sudo systemctl enable --now mariadb

    echo -e "${YELLOW}4. Création de la base de données Zabbix${RESET}"
    sudo mysql -e "CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;"
    sudo mysql -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
    sudo mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
    sudo mysql -e "FLUSH PRIVILEGES;"

    echo -e "${YELLOW}5. Importation du schéma Zabbix${RESET}"
    zcat /usr/share/zabbix/sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -u ${DB_USER} -p${DB_PASS} ${DB_NAME}

    echo -e "${YELLOW}6. Configuration de zabbix_server.conf${RESET}"
    sudo sed -i "s/^#\?DBName=.*/DBName=${DB_NAME}/" /etc/zabbix/zabbix_server.conf
    sudo sed -i "s/^#\?DBUser=.*/DBUser=${DB_USER}/" /etc/zabbix/zabbix_server.conf
    sudo sed -i "s/^#\s*DBPassword=.*/DBPassword=${DB_PASS}/" /etc/zabbix/zabbix_server.conf

    echo -e "${YELLOW}7. Configuration Apache pour Zabbix sur /zabbix${RESET}"
    # Créer un alias /zabbix pointant vers le dossier Zabbix frontend
    sudo tee /etc/apache2/sites-available/zabbix.conf > /dev/null <<EOF
Alias /zabbix /usr/share/zabbix

<Directory /usr/share/zabbix>
    Options FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
EOF

    sudo a2ensite zabbix.conf
    sudo systemctl reload apache2

    echo -e "${YELLOW}8. Démarrage et activation des services Zabbix${RESET}"
    sudo systemctl restart zabbix-server zabbix-agent apache2
    sudo systemctl enable zabbix-server zabbix-agent apache2

    ip=$(ip -o -4 addr show | awk '!/127.0.0.1/ {print $4}' | cut -d/ -f1 | head -n1)
    echo -e "${GREEN}Installation terminée ! Accédez à Zabbix via http://${ip}/zabbix${RESET}"
    echo -e "${GREEN}Login : Admin   Password : zabbix${RESET}"
}

# Fonction d'installation XiVO
function install_xivo() {
    sudo systemctl stop apache2 nginx
    set -e

    mirror_xivo="http://mirror.xivo.solutions"
    update='sudo apt-get update'
    install='sudo apt-get install --assume-yes'
    download='sudo apt-get install --assume-yes --download-only'
    dcomp='/usr/bin/xivo-dcomp'

    distribution='xivo-orion'
    dev_lts='orion'
    repo='debian'
    debian_codename='bookworm'
    debian_version='12'
    debian_codename_dev='bookworm'
    debian_version_dev='12'
    not_installable_message='This version of XiVO is not installable on 32-bit systems.'

    declare -A lts_version_table=([2017.03]="Five" [2017.11]="Polaris" [2018.05]="Aldebaran" [2018.16]="Borealis" [2019.05]="Callisto" [2019.12]="Deneb" [2020.07]="Electra" [2020.18]="Freya" [2021.07]="Gaia" [2021.15]="Helios" [2022.05]="Izar" [2022.10]="Jabbah" [2023.05]="Kuma" [2023.10]="Luna" [2024.05]="Maia" [2024.10]="Naos" [2025.05]="Orion")

    if ! grep --quiet "inet4_only = on" /etc/wgetrc 2>/dev/null; then
        echo "inet4_only = on" | sudo tee -a /etc/wgetrc > /dev/null
    fi

    get_system_architecture() {
        architecture=$(uname -m)
        echo "Architecture détectée: $architecture"
        
        # Vérifier si l'architecture est supportée
        if [[ "$architecture" == "i386" || "$architecture" == "i686" ]]; then
            echo "$not_installable_message"
            exit 1
        fi
    }

    check_system() {
        local version_file='/etc/debian_version'
        if [ ! -f $version_file ]; then
            echo "Vous devez installer XiVO sur un système Debian $debian_version (\"$debian_codename\")"
            echo "Vous ne semblez pas être sur un système Debian"
            exit 1
        else
            your_version=$(cut -d '.' -f 1 "$version_file")
        fi

        if [ "$your_version" != $debian_version ]; then
            echo "Vous devez installer XiVO sur un système Debian $debian_version (\"$debian_codename\")"
            echo "Vous êtes actuellement sur un système Debian $your_version"
            exit 1
        fi
        
        echo "Système Debian $your_version détecté - Compatible"
    }

    add_dependencies() {
        echo "Installation des dépendances..."
        $update
        $install wget \
            dirmngr \
            gnupg \
            curl \
            ca-certificates \
            apt-transport-https \
            software-properties-common
    }

    add_xivo_key() {
        local xivo_keyring_file="/etc/apt/trusted.gpg.d/mirror.xivo.solutions.gpg"
        echo "Ajout de la clé GPG XiVO..."
        add_key_in_keyring "http://mirror.xivo.solutions/xivo_current.key" "${xivo_keyring_file}"
    }

    is_key_in_keyring() {
        local keyid="${1}"; shift
        local keyringfile="${1}"; shift

        if [ -f "${keyringfile}" ] && gpg --batch --no-tty --keyring "${keyringfile}" --list-keys --with-colons 2>/dev/null | grep -q "${keyid}"; then
            return 0
        else
            return 1
        fi
    }

    add_key_in_keyring() {
        local keyurl="${1}"; shift
        local keyringfile="${1}"; shift

        echo "Suppression du fichier ${keyringfile}"
        sudo rm -rf "${keyringfile}"
        sudo touch "${keyringfile}"
        echo "Ajout de la clé GPG depuis ${keyurl} vers ${keyringfile}..."
        
        # Retry logic pour la récupération de clé
        local max_attempts=3
        local attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            if curl -fsSL "${keyurl}" | gpg --dearmor | sudo tee "${keyringfile}" >/dev/null 2>&1; then
                echo "Clé GPG ajoutée avec succès"
                break
            else
                echo "Tentative $attempt/$max_attempts échouée pour récupérer la clé"
                if [ $attempt -eq $max_attempts ]; then
                    echo "Erreur: Impossible de récupérer la clé GPG après $max_attempts tentatives"
                    exit 1
                fi
                attempt=$((attempt + 1))
                sleep 2
            fi
        done
    }

    add_docker_key() {
        local docker_keyring_file="/etc/apt/trusted.gpg.d/download.docker.com.gpg"
        local docker_keyid="0EBFCD88"

        echo "Vérification de la clé Docker..."
        if ! is_key_in_keyring "${docker_keyid}" "${docker_keyring_file}"; then
            echo "Ajout de la clé GPG Docker..."
            add_key_in_keyring "https://download.docker.com/linux/debian/gpg" "${docker_keyring_file}"
        else
            echo "Clé Docker déjà présente"
        fi
    }

    add_xivo_apt_conf() {
        echo "Installation du fichier de configuration APT: /etc/apt/apt.conf.d/90xivo"
        sudo tee /etc/apt/apt.conf.d/90xivo > /dev/null <<-EOF
Aptitude::Recommends-Important "false";
APT::Install-Recommends "false";
APT::Install-Suggests "false";
EOF
    }

    add_mirror() {
        echo "Ajout des miroirs XiVO..."
        local mirror="deb $mirror_xivo/$repo $distribution main"
        apt_dir="/etc/apt"
        sources_list_dir="$apt_dir/sources.list.d"
        
        if ! grep -qr "$mirror" "$apt_dir" 2>/dev/null; then
            echo "$mirror" | sudo tee $sources_list_dir/tmp-pf.sources.list > /dev/null
        fi
        
        add_xivo_key
        add_xivo_apt_conf

        export DEBIAN_FRONTEND=noninteractive
        echo "Mise à jour des paquets..."
        $update
        
        echo "Installation de xivo-dist..."
        $install xivo-dist
        
        add_docker_key
        
        echo "Configuration de la distribution XiVO..."
        xivo-dist "$distribution"

        sudo rm -f "$sources_list_dir/tmp-pf.sources.list"
        
        echo "Mise à jour finale des paquets..."
        $update
    }

    add_pgdg_mirror() {
        echo "Ajout du miroir PostgreSQL..."
        $install ca-certificates lsb-release
        add_key_in_keyring "https://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc" "/etc/apt/trusted.gpg.d/apt.postgresql.org.gpg"
        echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
        $update
    }

    check_source_exists() {
        local type="$1"; shift
        local distribution="$1"; shift
        local component="$1"; shift
        local list="$1"; shift

        grep -Prq "^\s*${type}\s.+\s${distribution}\s+${component}\b" "${list}" 2>/dev/null
    }

    add_backports_in_sources_list() {
        local distribution=${1}; shift

        echo "Ajout de la source ${distribution}-backports"
        if ! check_source_exists deb ${distribution}-backports main "/etc/apt/sources.list*"; then
            sudo tee -a /etc/apt/sources.list > /dev/null <<-EOF

# ${distribution}-backports, previously on backports.debian.org
deb http://ftp.fr.debian.org/debian ${distribution}-backports main
EOF
        fi
        if ! check_source_exists deb-src ${distribution}-backports main "/etc/apt/sources.list*"; then
            sudo tee -a /etc/apt/sources.list > /dev/null <<-EOF
deb-src http://ftp.fr.debian.org/debian ${distribution}-backports main
EOF
        fi
    }

    install_dahdi_modules() {
        echo "Installation des modules DAHDI..."
        flavour=$(echo $(uname -r) | cut -d\- -f3)
        kernel_release=$(ls /lib/modules/ | grep ${flavour} 2>/dev/null || echo "")
        
        if [ -z "$kernel_release" ]; then
            echo "Aucun module kernel trouvé pour $flavour"
            return
        fi
        
        for kr in ${kernel_release}; do
            echo "Installation de dahdi-linux-modules-${kr}..."
            if $download dahdi-linux-modules-${kr} 2>/dev/null; then
                $install dahdi-linux-modules-${kr}
            else
                echo "Avertissement: Impossible d'installer dahdi-linux-modules-${kr}"
            fi
        done
    }

    configure_nginx_ports() {
        echo "Configuration des ports NGINX personnalisés pour éviter les conflits (8080/8443)..."

        local override_file="/etc/xivo-dcomp/docker-compose.override.yml"
        sudo mkdir -p /etc/xivo-dcomp/

        sudo tee "$override_file" > /dev/null <<EOF
version: '2.1'

services:
  nginx:
    ports:
      - "8080:80"
      - "8443:443"
EOF
    }

    install_rabbitmq() {
        echo "Installation de RabbitMQ..."
        $download xivo-docker-components
        $install xivo-docker-components

        if [ -f "$dcomp" ]; then
            echo "Téléchargement de l'image RabbitMQ..."
            sudo $dcomp pull rabbitmq
            echo "Démarrage du conteneur RabbitMQ..."
            sudo $dcomp up -d rabbitmq
            
            # Attendre que RabbitMQ soit prêt
            echo "Attente du démarrage de RabbitMQ..."
            local max_wait=60
            local wait_time=0
            while [ $wait_time -lt $max_wait ]; do
                if sudo $dcomp ps rabbitmq | grep -q "Up"; then
                    echo "RabbitMQ démarré avec succès"
                    break
                fi
                sleep 2
                wait_time=$((wait_time + 2))
            done
            
            if [ $wait_time -ge $max_wait ]; then
                echo "Avertissement: RabbitMQ met du temps à démarrer"
            fi
        else
            echo "Erreur: xivo-dcomp non trouvé à $dcomp"
            exit 1
        fi
    }

    check_docker_service() {
        echo "Vérification du service Docker..."
        if ! systemctl is-active --quiet docker; then
            echo "Démarrage du service Docker..."
            sudo systemctl start docker
            sudo systemctl enable docker
        fi
        
        # Vérifier que Docker fonctionne
        if ! docker info >/dev/null 2>&1; then
            echo "Erreur: Docker ne semble pas fonctionner correctement"
            exit 1
        fi
        echo "Docker est actif et fonctionnel"
    }

    get_key_in_env() {
        local key_name="${1}"; shift
        local compose_path="${1}"; shift
        local custom_env_file="${1}"; shift
        local key_value

        if [ -f "${compose_path}/${custom_env_file}" ] && key_value=$(grep -oP -m 1 "${key_name}=\K.*" ${compose_path}/${custom_env_file} 2>/dev/null); then
            echo "${key_value}"
        else
            echo ""
        fi
    }

    get_usm_backend_token() {
        local usm_backend_url="${1}"; shift
        local xivo_uuid
        
        if [ -f "/etc/default/xivo" ]; then
            xivo_uuid=$(grep -oP 'XIVO_UUID=(.*)$' /etc/default/xivo | tail -n 1 | cut -d '=' -f 2)
        else
            echo "error"
            return
        fi
        
        if token=$(curl --fail --connect-timeout 10 --max-time 20 "${usm_backend_url}/usm/token?xivo_uuid=${xivo_uuid}" 2>/dev/null); then
            echo "${token}"
        else
            echo "error"
        fi
    }

    add_key_in_env() {
        local key_name="${1}"; shift
        local key_value="${1}"; shift
        local compose_path="${1}"; shift
        local custom_env_file="${1}"; shift

        if [ ! -f "${compose_path}/${custom_env_file}" ]; then
            sudo mkdir -p "${compose_path}"
            sudo touch "${compose_path}/${custom_env_file}"
        fi

        if grep -q "^${key_name}=" ${compose_path}/${custom_env_file} 2>/dev/null; then
            sudo sed -i "s/^${key_name}=.*/${key_name}=${key_value}/" ${compose_path}/${custom_env_file}
        else
            echo "${key_name}=${key_value}" | sudo tee -a ${compose_path}/${custom_env_file} >/dev/null
        fi
    }

    check_port_conflicts() {
        echo "Vérification des conflits de ports..."
        
        # Vérifier si les ports 80 et 443 sont utilisés
        if netstat -tuln 2>/dev/null | grep -q ":80 \|:443 "; then
            echo "⚠ Ports 80/443 déjà utilisés. Configuration des ports alternatifs..."
            
            # Créer un fichier de configuration pour des ports alternatifs
            local override_file="/etc/xivo-docker/docker-compose.override.yml"
            sudo mkdir -p /etc/xivo-docker
            
            sudo tee "$override_file" > /dev/null <<-EOF
version: '3.7'
services:
  nginx:
    ports:
      - "8080:80"
      - "8443:443"
  proxy:
    ports:
      - "8080:80"
      - "8443:443"
EOF
            echo "✓ Configuration ports alternatifs: 8080 (HTTP) et 8443 (HTTPS)"
            return 0
        else
            echo "✓ Ports 80/443 disponibles"
            return 1
        fi
    }

    enable_xivo_service() {
        echo "Activation du service xivo-service..."
        
        # D'abord, vérifier si le service existe
        if systemctl list-unit-files | grep -q xivo-service; then
            sudo systemctl enable xivo-service
            sudo systemctl start xivo-service
            echo "✓ Service xivo-service activé et démarré"
        else
            echo "⚠ Service xivo-service non trouvé, les conteneurs gèrent les services"
        fi
    }

    fix_nginx_issues() {
        echo "Diagnostic et correction des problèmes Nginx..."
        
        # Vérifier les conflits de ports
        if netstat -tuln 2>/dev/null | grep -q ":80 \|:443 "; then
            echo "⚠ Ports 80/443 occupés - configuration des ports alternatifs pour nginx"
            
            # Forcer la recréation du override avec nginx spécifique
            local override_file="/etc/xivo-docker/docker-compose.override.yml"
            sudo mkdir -p /etc/xivo-docker
            
            sudo tee "$override_file" > /dev/null <<-EOF
version: '3.7'
services:
  nginx:
    ports:
      - "8080:80"
      - "8443:443"
    restart: unless-stopped
  proxy:
    ports:
      - "8081:80"
    restart: unless-stopped
EOF
            
            echo "✓ Configuration nginx sur ports alternatifs créée"
            
            # Redémarrer nginx avec la nouvelle configuration
            echo "Redémarrage de nginx avec les nouveaux ports..."
            sudo $dcomp up -d nginx
            
            return 0
        else
            echo "✓ Ports 80/443 disponibles"
            
            # Essayer de redémarrer nginx normalement
            echo "Redémarrage de nginx..."
            sudo $dcomp up -d nginx
            
            return 1
        fi
    }

    start_all_xivo_services() {
        echo "Démarrage de tous les services XiVO requis..."
        
        if [ ! -f "$dcomp" ]; then
            echo "Erreur: xivo-dcomp non trouvé à $dcomp"
            exit 1
        fi
        
        # Lister tous les services disponibles
        echo "Services XiVO disponibles:"
        sudo $dcomp config --services
        
        # Arrêter tous les conteneurs existants
        echo "Arrêt des conteneurs existants..."
        sudo $dcomp down
        
        # Démarrer tous les services un par un pour identifier les problèmes
        local services=(
            "db"
            "rabbitmq" 
            "nginx"
            "proxy"
            "webi"
            "confgend"
            "config_mgt"
            "ctid"
            "agid"
            "outcall"
            "usage_collector"
            "usage_writer"
            "switchboard_reports"
        )
        
        echo "Démarrage séquentiel des services..."
        for service in "${services[@]}"; do
            echo "Démarrage de $service..."
            if sudo $dcomp up -d "$service" 2>/dev/null; then
                echo "✓ $service démarré"
                sleep 2
            else
                echo "⚠ Échec du démarrage de $service"
                echo "Logs de $service:"
                sudo $dcomp logs --tail=5 "$service" 2>/dev/null || echo "Pas de logs disponibles"
            fi
        done
        
        # Attendre un peu pour la stabilisation
        sleep 10
        
        # Vérifier l'état final
        echo "État final de tous les conteneurs:"
        sudo $dcomp ps
        
        # Compter les conteneurs actifs
        local running_containers=$(sudo $dcomp ps | grep -c "Up" || echo "0")
        local total_services=${#services[@]}
        
        echo "Conteneurs actifs: $running_containers/$total_services"
        
        if [ "$running_containers" -lt 3 ]; then
            echo "⚠ Peu de conteneurs actifs. Tentative de correction..."
            
            # Essayer de corriger le problème nginx
            fix_nginx_issues
            
            # Attendre et vérifier à nouveau
            sleep 5
            echo "Nouvel état après correction:"
            sudo $dcomp ps
            
            # Recompter
            running_containers=$(sudo $dcomp ps | grep -c "Up" || echo "0")
            echo "Conteneurs actifs après correction: $running_containers/$total_services"
            
            if [ "$running_containers" -lt 3 ]; then
                echo "Logs détaillés des services en erreur:"
                sudo $dcomp logs --tail=20
            fi
        fi
    }

    main_install() {
        echo "=== Début de l'installation XiVO ==="

        get_system_architecture
        check_system
        check_docker_service
        add_dependencies
        add_mirror

        echo "Installation des paquets principaux..."
        $download xivo
        $install xivo

        echo "Installation des paquets MOH Asterisk supplémentaires..."
        $install asterisk-moh-opsound-g722 asterisk-moh-opsound-gsm asterisk-moh-opsound-wav || echo "Avertissement: Certains paquets MOH n'ont pas pu être installés"

        # Vérifier les conflits de ports
        local ports_changed=0
        if check_port_conflicts; then
            ports_changed=1
        fi

        echo "Téléchargement de toutes les images Docker..."
        sudo $dcomp pull

        # Activer le service xivo si disponible
        enable_xivo_service
        
        # Démarrer tous les services XiVO
        start_all_xivo_services

        # Attendre que la base de données soit prête
        echo "Attente de la disponibilité de la base de données..."
        local max_wait=120
        local wait_time=0
        while [ $wait_time -lt $max_wait ]; do
            if sudo $dcomp exec db pg_isready -U postgres >/dev/null 2>&1; then
                echo "✓ Base de données PostgreSQL prête"
                break
            fi
            sleep 2
            wait_time=$((wait_time + 2))
            if [ $((wait_time % 20)) -eq 0 ]; then
                echo "Attente de la DB... ($wait_time/$max_wait secondes)"
            fi
        done
        
        if [ $wait_time -ge $max_wait ]; then
            echo "⚠ La base de données met du temps à être disponible"
        fi

        # Déterminer l'URL d'accès
        local web_ip=$(hostname -I | awk '{print $1}')
        local web_url
        local proxy_url="http://${web_ip}:8081"
        
        if [ $ports_changed -eq 1 ]; then
            web_url="https://${web_ip}:8443"
            echo "Test de connectivité web sur port alternatif..."
            if curl -k -s --connect-timeout 5 "${web_url}" >/dev/null 2>&1; then
                echo "✓ Interface web accessible sur port 8443"
            elif curl -s --connect-timeout 5 "${proxy_url}" >/dev/null 2>&1; then
                echo "✓ Interface web accessible via proxy sur port 8081"
                web_url="$proxy_url"
            else
                echo "⚠ Interface web pas encore accessible (peut prendre quelques minutes)"
                echo "  Essayez aussi: $proxy_url"
            fi
        else
            web_url="https://${web_ip}"
            echo "Test de connectivité web..."
            if curl -k -s --connect-timeout 5 "${web_url}" >/dev/null 2>&1; then
                echo "✓ Interface web accessible"
            elif curl -s --connect-timeout 5 "${proxy_url}" >/dev/null 2>&1; then
                echo "✓ Interface web accessible via proxy sur port 8081"
                web_url="$proxy_url"
            else
                echo "⚠ Interface web pas encore accessible (peut prendre quelques minutes)"
                echo "  Essayez aussi: $proxy_url"
            fi
        fi

        echo ""
        echo "=========================================="
        echo "=== Installation XiVO terminée! ==="
        echo "=========================================="
        echo ""
        echo "🌐 Interface web: $web_url"
        if [ $ports_changed -eq 1 ]; then
            echo "⚠  Ports alternatifs utilisés (8080/8443) car 80/443 occupés"
        fi
        echo ""
        echo "📋 Commandes utiles:"
        echo "   Voir l'état:     sudo $dcomp ps"
        echo "   Voir les logs:   sudo $dcomp logs"
        echo "   Redémarrer:      sudo $dcomp restart"
        echo "   Arrêter:         sudo $dcomp down"
        echo "   Démarrer:        sudo $dcomp up -d"
        echo ""
        
        local running_containers=$(sudo $dcomp ps | grep -c "Up" || echo "0")
        if [ "$running_containers" -ge 8 ]; then
            echo "✅ Installation réussie! ($running_containers conteneurs actifs)"
            echo "🔧 Connectez-vous à l'interface web pour finaliser la configuration"
        elif [ "$running_containers" -ge 3 ]; then
            echo "⚠️  Installation partielle ($running_containers conteneurs actifs)"
            echo "🔍 Vérifiez les logs: sudo $dcomp logs"
        else
            echo "❌ Problème d'installation ($running_containers conteneurs actifs)"
            echo "🔍 Vérifiez les logs: sudo $dcomp logs"
            echo "🔧 Essayez: sudo $dcomp up -d"
        fi
    }

    # Point d'entrée principal
    main_install
}

# Boucle principale
while true; do
    show_banner

    echo -e "${GREEN}Que souhaitez-vous installer ?${RESET}"
    echo "1) GLPI"
    echo "2) Zabbix"
    echo "3) Xivo"
    echo "4) Quitter"
    echo
    read -p "Votre choix : " choice

    case "$choice" in
        1)
            install_glpi
            read -p "${GREEN}Appuyez sur Entrée pour revenir au menu...${RESET}"
            ;;
        2)
            install_zabbix
            read -p "${GREEN}Appuyez sur Entrée pour revenir au menu...${RESET}"
            ;;
        3)
            install_xivo
            read -p "${GREEN}Appuyez sur Entrée pour revenir au menu...${RESET}"
            ;;
        4)
            echo -e "${YELLOW}Au revoir !${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}Choix invalide, veuillez réessayer.${RESET}"
            sleep 2
            ;;
    esac
done
