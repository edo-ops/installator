#!/bin/bash

# Couleurs pour les messages
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"
BOLD="\033[1m"

# Lecture des paramètres utilisateur
echo -e "${CYAN}${BOLD}Configuration de la base de données :${RESET}"
read -p "${YELLOW}Nom de la base de données : ${RESET}" db_name
read -p "${YELLOW}Nom d'utilisateur MySQL : ${RESET}" db_user
read -sp "${YELLOW}Mot de passe MySQL : ${RESET}" db_pass
echo

# Variables
web_root="/var/www/html/glpi"
glpi_version="10.0.11"
glpi_url="https://github.com/glpi-project/glpi/releases/download/${glpi_version}/glpi-${glpi_version}.tgz"
ip=$(ip -o -4 addr show | awk '!/127.0.0.1/ {print $4}' | cut -d/ -f1 | head -n1)

# Mise à jour du système
echo -e "${CYAN}Mise à jour du système...${RESET}"
sudo apt update && sudo apt upgrade -y

# Installation des paquets nécessaires
echo -e "${CYAN}Installation des dépendances...${RESET}"
sudo apt install -y apache2 mariadb-server php php-curl php-gd php-intl php-mbstring php-xml \
php-zip php-bz2 php-mysql php-apcu php-cli php-ldap unzip tar libapache2-mod-php

# Téléchargement et installation de GLPI
echo -e "${CYAN}Téléchargement de GLPI ${glpi_version}...${RESET}"
sudo mkdir -p "$web_root"
wget -q "$glpi_url" -O /tmp/glpi.tgz
sudo tar -xvzf /tmp/glpi.tgz -C /tmp > /dev/null
sudo mv /tmp/glpi/* "$web_root"
sudo rm -rf /tmp/glpi /tmp/glpi.tgz
sudo chown -R www-data:www-data "$web_root"
sudo chmod -R 755 "$web_root"

# Configuration de MariaDB
echo -e "${CYAN}Configuration de la base de données...${RESET}"
sudo systemctl enable --now mariadb
sudo mysql -e "CREATE DATABASE ${db_name} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE USER '${db_user}'@'localhost' IDENTIFIED BY '${db_pass}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_user}'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Activer le module Apache rewrite et redémarrer Apache
echo -e "${CYAN}Configuration d'Apache...${RESET}"
sudo a2enmod rewrite
sudo systemctl restart apache2

# Message final
echo -e "\n${GREEN}${BOLD}Installation terminée avec succès !${RESET}"
echo -e "${GREEN}Accédez à GLPI via : http://${ip}/glpi${RESET}"
