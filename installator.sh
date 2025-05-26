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
sudo chmod +x install_xivo.sh
sudo ./install_xivo.sh
}

# Fonction d'installation sambaAD
function install_sambaAD() {
sudo chmod +x install_sambaAD.sh
sudo ./install_sambaAD
}

# Fonction d'installation Wordpress
function install_wordpress() {
sudo chmod +x install_wordpress.sh
sudo ./install_wordpress
}

# Boucle principale
while true; do
    show_banner

    echo -e "${GREEN}Que souhaitez-vous installer ?${RESET}"
    echo "1) GLPI"
    echo "2) Zabbix"
    echo "3) Xivo"
    echo "4) SambaAD"
    echo "5) Wordpress"
    echo "6) Quitter"
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
            install_sambaAD
            read -p "${GREEN}Appuyez sur Entrée pour revenir au menu...${RESET}"
            ;;
        5)
            install_wordpress
            read -p "${GREEN}Appuyez sur Entrée pour revenir au menu...${RESET}"
            ;;
        6)
            echo -e "${YELLOW}Au revoir !${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}Choix invalide, veuillez réessayer.${RESET}"
            sleep 2
            ;;
    esac
done
