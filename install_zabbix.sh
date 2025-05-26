#!/bin/bash

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
