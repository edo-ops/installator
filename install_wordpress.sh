#!/bin/bash

echo "📦 Installation interactive de WordPress sur Debian 12"
echo "--------------------------------------------------------"

# === Saisie des informations ===
read -p "📛 Nom de la base de données : " DB_NAME
read -p "👤 Nom de l'utilisateur MariaDB : " DB_USER
read -s -p "🔑 Mot de passe MariaDB de l'utilisateur : " DB_PASSWORD
echo
read -s -p "🔑 Mot de passe root MariaDB (laisser vide si aucun) : " DB_ROOT_PASS
echo

# === Variables système ===
WP_DIR="/var/www/html"
SERVER_IP=$(hostname -I | awk '{print $1}')

# === Vérification et installation d'Apache ===
if ! command -v apache2 > /dev/null; then
  echo "❗ Apache n'est pas installé. Installation en cours..."
  apt update && apt install -y apache2
  if [ $? -ne 0 ]; then
    echo "❌ Échec de l'installation d'Apache. Abandon."
    exit 1
  fi
else
  echo "✅ Apache est déjà installé."
fi

# === Installation des paquets PHP et MariaDB ===
echo "🚀 Installation des dépendances PHP et MariaDB..."
apt install -y mariadb-server php php-mysql libapache2-mod-php php-cli php-curl php-zip php-gd php-xml php-mbstring wget unzip tar
if [ $? -ne 0 ]; then
  echo "❌ Échec de l'installation des paquets PHP/MariaDB. Abandon."
  exit 1
fi

# === Création du dossier web si manquant ===
if [ ! -d "$WP_DIR" ]; then
  echo "📁 Création du dossier $WP_DIR"
  mkdir -p $WP_DIR
fi

# === Sécurisation de MariaDB ===
echo "🔒 Sécurisation de MariaDB (manuel recommandé après installation)"
echo "   Commande : sudo mysql_secure_installation"

# === Création de la base de données et de l'utilisateur ===
echo "🛠️ Configuration de la base de données..."
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
  echo "❌ Échec de la configuration MariaDB. Vérifiez le mot de passe root."
  exit 1
fi

# === Téléchargement et extraction de WordPress ===
echo "⬇️ Téléchargement de WordPress..."
cd $WP_DIR
rm -f index.html
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
mv wordpress/* .
rm -rf latest.tar.gz wordpress

# === Attribution des droits ===
echo "🔐 Attribution des droits à www-data..."
chown -R www-data:www-data $WP_DIR
chmod -R 755 $WP_DIR

# === Configuration du fichier wp-config.php ===
echo "⚙️ Configuration de wp-config.php..."
cp wp-config-sample.php wp-config.php
sed -i "s/database_name_here/$DB_NAME/" wp-config.php
sed -i "s/username_here/$DB_USER/" wp-config.php
sed -i "s/password_here/$DB_PASSWORD/" wp-config.php

# === Insertion des clés secrètes ===
echo "🔑 Insertion des clés secrètes WordPress..."
SECRET_KEYS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
if [ -z "$SECRET_KEYS" ]; then
  echo "❌ Échec de la récupération des clés secrètes WordPress."
else
  sed -i '/AUTH_KEY/d;/SECURE_AUTH_KEY/d;/LOGGED_IN_KEY/d;/NONCE_KEY/d;/AUTH_SALT/d;/SECURE_AUTH_SALT/d;/LOGGED_IN_SALT/d;/NONCE_SALT/d' wp-config.php
  echo "$SECRET_KEYS" >> wp-config.php
fi

# === Redémarrage du service Apache ===
echo "🔁 Redémarrage d'Apache..."
systemctl restart apache2
if [ $? -ne 0 ]; then
  echo "❌ Apache n'a pas pu redémarrer. Vérifiez l'installation."
  exit 1
fi

# === Résultat final ===
echo
echo "✅ Installation de WordPress terminée avec succès !"
echo "🌍 Accédez à : http://$SERVER_IP"

