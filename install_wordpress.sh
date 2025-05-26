#!/bin/bash

#-----------------------------------------------------------------------------
# Configuration des couleurs pour l'affichage
#-----------------------------------------------------------------------------
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly RED='\033[0;31m'
readonly BOLD='\033[1m'
readonly RESET='\033[0m'

echo -e "${CYAN}${BOLD}======================================================"
echo "  Installation interactive de WordPress sur Debian 12"
echo -e "======================================================${RESET}"

# === Saisie des informations ===
read -p "$(echo -e "${YELLOW}📛 Nom de la base de données: ${RESET}")" DB_NAME
read -p "$(echo -e "${YELLOW}👤 Nom de l'utilisateur MariaDB: ${RESET}")" DB_USER
read -s -p "$(echo -e "${YELLOW}🔑 Mot de passe MariaDB de l'utilisateur: ${RESET}")" DB_PASSWORD
echo
read -s -p "$(echo -e "${YELLOW}🔑 Mot de passe root MariaDB (laisser vide si aucun): ${RESET}")" DB_ROOT_PASS
echo

# === Variables système ===
WP_DIR="/var/www/html"
SERVER_IP=$(hostname -I | awk '{print $1}')

# === Vérification et installation d'Apache ===
if ! command -v apache2 > /dev/null; then
  echo -e "${YELLOW}❗ Apache n'est pas installé. Installation en cours...${RESET}"
  apt update && apt install -y apache2
  if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Échec de l'installation d'Apache. Abandon.${RESET}"
    exit 1
  fi
else
  echo -e "${GREEN}✅ Apache est déjà installé.${RESET}"
fi

# === Installation des paquets PHP et MariaDB ===
echo -e "${CYAN}🚀 Installation des dépendances PHP et MariaDB...${RESET}"
apt install -y mariadb-server php php-mysql libapache2-mod-php php-cli php-curl php-zip php-gd php-xml php-mbstring wget unzip tar
if [ $? -ne 0 ]; then
  echo -e "${RED}❌ Échec de l'installation des paquets PHP/MariaDB. Abandon.${RESET}"
  exit 1
fi

# === Création du dossier web si manquant ===
if [ ! -d "$WP_DIR" ]; then
  echo -e "${CYAN}📁 Création du dossier $WP_DIR${RESET}"
  mkdir -p $WP_DIR
fi

# === Sécurisation de MariaDB ===
echo -e "${YELLOW}🔒 Sécurisation de MariaDB (manuel recommandé après installation)${RESET}"
echo -e "   ${BOLD}Commande:${RESET} sudo mysql_secure_installation"

# === Création de la base de données et de l'utilisateur ===
echo -e "${CYAN}🛠️ Configuration de la base de données...${RESET}"
if [ -z "$DB_ROOT_PASS" ]; then
  mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
else
  mysql -u root -p"$DB_ROOT_PASS" <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
fi
if [ $? -ne 0 ]; then
  echo -e "${RED}❌ Échec de la configuration MariaDB. Vérifiez le mot de passe root.${RESET}"
  exit 1
fi

# === Téléchargement et extraction de WordPress ===
echo -e "${CYAN}⬇️ Téléchargement de WordPress...${RESET}"
cd $WP_DIR
rm -f index.html
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
mv wordpress/* .
rm -rf latest.tar.gz wordpress

# === Attribution des droits ===
echo -e "${CYAN}🔐 Attribution des droits à www-data...${RESET}"
chown -R www-data:www-data $WP_DIR
chmod -R 755 $WP_DIR

# === Configuration du fichier wp-config.php ===
echo -e "${CYAN}⚙️ Configuration de wp-config.php...${RESET}"
cp wp-config-sample.php wp-config.php
sed -i "s/database_name_here/$DB_NAME/" wp-config.php
sed -i "s/username_here/$DB_USER/" wp-config.php
sed -i "s/password_here/$DB_PASSWORD/" wp-config.php

# === Insertion des clés secrètes ===
echo -e "${CYAN}🔑 Insertion des clés secrètes WordPress...${RESET}"
SECRET_KEYS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
if [ -z "$SECRET_KEYS" ]; then
  echo -e "${RED}❌ Échec de la récupération des clés secrètes WordPress.${RESET}"
else
  sed -i '/AUTH_KEY/d;/SECURE_AUTH_KEY/d;/LOGGED_IN_KEY/d;/NONCE_KEY/d;/AUTH_SALT/d;/SECURE_AUTH_SALT/d;/LOGGED_IN_SALT/d;/NONCE_SALT/d' wp-config.php
  echo "$SECRET_KEYS" >> wp-config.php
fi

# === Redémarrage du service Apache ===
echo -e "${CYAN}🔁 Redémarrage d'Apache...${RESET}"
systemctl restart apache2
if [ $? -ne 0 ]; then
  echo -e "${RED}❌ Apache n'a pas pu redémarrer. Vérifiez l'installation.${RESET}"
  exit 1
fi

# === Résultat final ===
echo
echo -e "${GREEN}${BOLD}=================================================="
echo "  Installation terminée avec succès !"
echo -e "==================================================${RESET}"
echo
echo -e "${GREEN}📌 Informations de connexion:${RESET}"
echo -e "   ${BOLD}URL d'accès:${RESET} http://$SERVER_IP"
echo -e "   ${BOLD}Base de données:${RESET} $DB_NAME"
echo -e "   ${BOLD}Utilisateur DB:${RESET} $DB_USER"
echo
