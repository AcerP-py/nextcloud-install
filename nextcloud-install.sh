#!/bin/bash

echo -e "*************************************************\nWELCOME TO NEXTCLOUD INSTALLATION\n*************************************************"
echo "Please sit tite as we get under way..."
echo "First we will do some initial setup..."
sleep 2

# set up firewall
echo ">>> SETING UP FIREWALL..."
sleep 1
sudo ufw allow OpenSSH
sudo ufw default deny
sudo ufw enable
sleep 2

# update & upgrade
echo ">>> UPDATE & UPGRADE..."
sleep 1
sudo timedatectl set-timezone America/Chicago
sudo apt update
sudo apt dist-upgrade -y
sudo apt install libdigest-sha-perl -y
sleep 2

# download nextcloud
echo ">>> DOWNLOADING NEXTCLOUD..."
sleep 1
wget https://download.nextcloud.com/server/releases/latest.zip
wget https://download.nextcloud.com/server/releases/latest.zip.sha256
dlg=$(cat latest.zip.sha256 | shasum -a 256 --check)
if [[ "$dlg" == "latest.zip: OK" ]]; then
    echo "Download was succsessful!"; else
    echo "Sorry download faild!"; exit;
fi
sleep 2

# install dependencies
echo ">>> INSTALLING & SETTING UP DEPENDENCIES..."
sleep 1
sudo apt install apache2 mariadb-server php libapache2-mod-php php-mysql php-curl php-dom php-gd php-json php-bcmath php-mbstring php-posix php-xml php-zip php-bz2 php-intl php-ldap php-imap php-gmp php-apcu unzip certbot python3-certbot-apache -y
sudo mysql_secure_installation
sudo ufw allow 'Apache Full'
sleep 2

# unzip nextcloud
echo ">>> UNPACKING NEXTCLOUD..."
sleep 1
unzip latest.zip
sleep 2

# gather user preferences for installation
echo ">>> WE NEED SOME INFO..."
read -p "Enter name of installation: " install_name
read -p "Enter your domain name: " install_domain
sleep 2

# configure apache with nextcloud
echo ">>> SETTING UP APACHE & NEXTCLOUD..."
sleep 1
sudo mkdir /var/www/$install_name
echo "
<VirtualHost *:80>
  DocumentRoot /var/www/$install_name/
  ServerName  $install_domain

  <Directory /var/www/$install_name/>
    Require all granted
    AllowOverride All
    Options FollowSymLinks MultiViews
    Satisfy Any

    <IfModule mod_dav.c>
      Dav off
    </IfModule>
  </Directory>
</VirtualHost>
" | sudo tee /etc/apache2/sites-available/$install_name.conf > /dev/null
sudo a2enmod rewrite headers env dir mime
sudo cp -r nextcloud/* /var/www/$install_name/
sudo chown -R www-data:www-data /var/www/$install_name/
sudo a2dissite 000-default.conf
sudo a2ensite $install_name.conf
sudo systemctl restart apache2
sudo certbot --apache
sudo systemctl status certbot.timer
sudo certbot renew --dry-run
sleep 2

# init nextcloud
echo ">>> INITIALIZING NEXTCLOUD"
read -p "Enter database password: " db_password
read -p "Enter username for nextcloud: " nextcloud_user
read -p "Enter password for nextcloud: " nextcloud_pass
echo "CREATE DATABASE nextcloud_db;" | sudo mysql
echo "GRANT ALL ON nextcloud_db.* to 'nextcloud_user'@'localhost' IDENTIFIED BY '${db_password}';" | sudo mysql
echo "FLUSH PRIVILEGES;" | sudo mysql
sudo mkdir /${install_name}
sudo mkdir /${install_name}/data
sudo chown -R www-data:www-data /${install_name}/data
cd /var/www/$install_name/
sudo -u www-data php occ maintenance:install --database='mysql' --database-name='nextcloud_db' --database-user='nextcloud_user' --database-pass="${db_password}" --admin-user="${nextcloud_user}" --admin-pass="${nextcloud_pass}" --data-dir="/${install_name}/data"

sudo sed -i 's/memory_limit = 128M/memory_limit = 512M/g' /etc/php/8.1/apache2/php.ini
sudo sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 200M/g' /etc/php/8.1/apache2/php.ini
sudo sed -i 's/max_execution_time = 30/max_execution_time = 360/g' /etc/php/8.1/apache2/php.ini
sudo sed -i 's/post_max_size = 8M/post_max_size = 200M/g' /etc/php/8.1/apache2/php.ini
sudo sed -i 's/;date.timezone =/date.timezone = America\/Chicago/g' /etc/php/8.1/apache2/php.ini
sudo sed -i 's/;opcache.enable=1/opcache.enable=1/g' /etc/php/8.1/apache2/php.ini
sudo sed -i 's/;opcache.interned_strings_buffer=8/opcache.interned_strings_buffer=8/g' /etc/php/8.1/apache2/php.ini
sudo sed -i 's/;opcache.max_accelerated_files=10000/opcache.max_accelerated_files=10000/g' /etc/php/8.1/apache2/php.ini
sudo sed -i 's/;opcache.memory_consumption=128/opcache.memory_consumption=128/g' /etc/php/8.1/apache2/php.ini
sudo sed -i 's/;opcache.save_comments=1/opcache.save_comments=1/g' /etc/php/8.1/apache2/php.ini
sudo sed -i 's/;opcache.revalidate_freq=2/opcache.revalidate_freq=1/g' /etc/php/8.1/apache2/php.ini
sudo sed -i 's/output_buffering = 4096/output_buffering = Off/g' /etc/php/8.1/apache2/php.ini
sudo systemctl restart apache2

echo "ALL DONE!"
sleep 2
