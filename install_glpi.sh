#!/bin/bash

# Variables
read -p "Donner un nom à la DB : " db_name
read -p "Donner un nom d'utilisateur : " db_user
read -p "Donner un mot de passe : " db_pass
web_root="/var/www/glpi"
glpi_version="10.0.11"
glpi_url="https://github.com/glpi-project/glpi/releases/download/${glpi_version}/glpi-${glpi_version}.tgz"
ip=$(ip -o -4 addr show | awk '!/127.0.0.1/ {print $4}' | cut -d/ -f1)

# Mettre à jour le système
sudo apt update && sudo apt upgrade -y

# Installer les dépendances
sudo apt install -y nginx mariadb-server php php-fpm php-curl php-gd php-intl php-mbstring php-xml php-zip php-bz2 php-mysql php-apcu php-cli php-ldap unzip tar

# Télécharger et installer GLPI
sudo mkdir -p "$web_root"
wget "$glpi_url" -O /tmp/glpi.tgz
sudo tar -xvzf /tmp/glpi.tgz -C /var/www/
sudo mv /var/www/glpi-${glpi_version}/* "$web_root"
sudo rm -rf /var/www/glpi-${glpi_version}
sudo chown -R www-data:www-data "$web_root"
sudo chmod -R 755 "$web_root"

# Configurer MariaDB
sudo systemctl enable --now mariadb
sudo mysql -e "CREATE DATABASE ${db_name};"
sudo mysql -e "CREATE USER '${db_user}'@'localhost' IDENTIFIED BY '${db_pass}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_user}'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Configurer Nginx
sudo tee /etc/nginx/sites-available/glpi > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    root $web_root;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/glpi /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm

# Afficher les informations d'installation
echo "Installation terminée ! Accédez à GLPI via http://$ip/glpi"
