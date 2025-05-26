#!/bin/bash

# --- FONCTIONS UTILES --- #
success() { echo -e "✅ $1"; }
error()   { echo -e "❌ $1" >&2; exit 1; }

step() {
  echo -e "\n🔷 $1"
}

# --- DÉMARRAGE DU SCRIPT --- #
set -e

# --- 0. Demander les informations --- #
echo "🔐 Configuration MySQL pour Zabbix"
read -p "Nom de la base de données : " DB_NAME
read -p "Nom de l'utilisateur MySQL : " DB_USER
read -s -p "Mot de passe MySQL : " DB_PASS
echo ""

# --- 1. Installer le dépôt Zabbix --- #
step "1. Installation du dépôt Zabbix"
wget -q https://repo.zabbix.com/zabbix/7.2/release/debian/pool/main/z/zabbix-release/zabbix-release_latest_7.2+debian12_all.deb \
  && sudo dpkg -i zabbix-release_latest_7.2+debian12_all.deb >/dev/null \
  && success "Dépôt Zabbix installé" || error "Échec de l'installation du dépôt"

# --- 2. Mise à jour --- #
step "2. Mise à jour des paquets"
sudo apt update -qq && success "Mise à jour OK" || error "Échec de mise à jour"

# --- 3. Installation paquets --- #
step "3. Installation des paquets Zabbix + MariaDB"
sudo apt install -y -qq zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf \
               zabbix-sql-scripts zabbix-agent mariadb-server \
  && success "Paquets installés" || error "Échec de l'installation des paquets"

# --- 4. Démarrage de MariaDB --- #
step "4. Démarrage de MariaDB"
sudo systemctl enable --now mariadb >/dev/null && success "MariaDB démarrée" || error "MariaDB non démarrée"

# --- 5. Création de la base --- #
step "5. Création de la base de données"
sudo mysql -e "CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;" \
  && sudo mysql -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';" \
  && sudo mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';" \
  && sudo mysql -e "FLUSH PRIVILEGES;" \
  && success "Base de données et utilisateur créés" || error "Erreur lors de la configuration de la base"

# --- 6. Importer le schéma Zabbix --- #
step "6. Importation du schéma Zabbix"
zcat /usr/share/zabbix/sql-scripts/mysql/server.sql.gz | \
  sudo mysql --default-character-set=utf8mb4 -u "${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" \
  && success "Schéma importé" || error "Échec de l'import du schéma"

# --- 7. Sécurité MySQL --- #
step "7. Sécurisation MySQL"
sudo mysql -e "SET GLOBAL log_bin_trust_function_creators = 0;" \
  && success "Restriction MySQL réactivée" || error "Erreur sécurité MySQL"

# --- 8. Configurer zabbix_server.conf --- #
step "8. Configuration de zabbix_server.conf"
sudo sed -i 's/\r//' /etc/zabbix/zabbix_server.conf
sudo sed -i "s/^#\?[[:space:]]*DBName[[:space:]]*=.*/DBName=${DB_NAME}/" /etc/zabbix/zabbix_server.conf
sudo sed -i "s/^#\?[[:space:]]*DBUser[[:space:]]*=.*/DBUser=${DB_USER}/" /etc/zabbix/zabbix_server.conf
sudo sed -i "s/^#\?[[:space:]]*DBPassword[[:space:]]*=.*/DBPassword=${DB_PASS}/" /etc/zabbix/zabbix_server.conf \
  && success "Fichier zabbix_server.conf mis à jour" || error "Échec configuration de zabbix_server.conf"

# --- 9. Redémarrage des services --- #
step "9. Démarrage et activation des services"
sudo systemctl restart zabbix-server zabbix-agent apache2
sudo systemctl enable zabbix-server zabbix-agent apache2 \
  && success "Services démarrés et activés" || error "Erreur lors du démarrage des services"

# --- 10. Affichage de l'IP --- #
IP_ADDR=$(hostname -I | awk '{print $1}')
echo -e "\n🎉 Installation terminée avec succès !"
echo -e "➡️ Accédez à l'interface web : http://${IP_ADDR}/zabbix"
