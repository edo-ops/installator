#!/bin/bash

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
