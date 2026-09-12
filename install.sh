#!/bin/bash

# Checking Root Access
if [[ $EUID -ne 0 ]]; then
    echo -e "\033[31m[ERROR]\033[0m Please run this script as \033[1mroot\033[0m."
    exit 1
fi

# Check SSL certificate status and days remaining
check_ssl_status() {
    if [ -f "/var/www/html/mirzabotconfig/config.php" ]; then
        domain=$(grep '^\$domainhosts' "/var/www/html/mirzabotconfig/config.php" | cut -d"'" -f2 | cut -d'/' -f1 | cut -d':' -f1)

        if [ -n "$domain" ] && [ -f "/etc/letsencrypt/live/$domain/cert.pem" ]; then
            expiry_date=$(openssl x509 -enddate -noout -in "/etc/letsencrypt/live/$domain/cert.pem" | cut -d= -f2)
            current_date=$(date +%s)
            expiry_timestamp=$(date -d "$expiry_date" +%s)
            days_remaining=$(( ($expiry_timestamp - $current_date) / 86400 ))
            if [ $days_remaining -gt 0 ]; then
                echo -e "\033[32mSSL Certificate: $days_remaining days remaining (Domain: $domain)\033[0m"
            else
                echo -e "\033[31mSSL Certificate: Expired (Domain: $domain)\033[0m"
            fi
        else
            echo -e "\033[33mSSL Certificate: Not found for domain $domain\033[0m"
        fi
    else
        echo -e "\033[33mCannot check SSL: Config file not found\033[0m"
    fi
}

# Check bot installation status
check_bot_status() {
    if [ -f "/var/www/html/mirzabotconfig/config.php" ]; then
        echo -e "\033[32mBot is installed\033[0m"
        check_ssl_status
    else
        echo -e "\033[31mBot is not installed\033[0m"
    fi
}

# Display Logo
function show_logo() {
    clear
    echo -e "\033[1;34m"
    echo "================================================================================="
    echo "  __  __ _____ _____   ______           _____        _   _ ______ _       "
    echo " |  \/  |_   _|  __ \ |___  /   /\     |  __ \ /\   | \ | |  ____| |      "
    echo " | \  / | | | | |__) |   / /   /  \    | |__) /  \  |  \| | |__  | |      "
    echo " | |\/| | | | |  _  /   / /   / /\ \   |  ___/ /\ \ | . \ |  __| | |      "
    echo " | |  | |_| |_| | \ \  / /__ / ____ \  | |  / ____ \| |\  | |____| |____  "
    echo " | |_|  |_|_____|_|  \_\/_____/_/    \_\ |_| /_/    \_\_| \_|______|______| "
    echo "================================================================================="
    echo -e "\033[0m"
    echo ""
    echo -e "\033[1;36mVersion:\033[0m \033[33m6.0.5\033[0m"
    echo -e "\033[1;36mTelegram Channel:\033[0m \033[34mhttps://t.me/mitvpn\033[0m"
    echo -e "\033[1;36mTelegram Support:\033[0m \033[34mhttps://t.me/MITsupports\033[0m"
    echo ""
    echo -e "\033[1;36mInstallation Status:\033[0m"
    check_bot_status
    echo ""
}


# Display Menu
function show_menu() {
    show_logo
    echo -e "\033[1;36m1)\033[0m Install Mirza Bot"
    echo -e "\033[1;36m2)\033[0m Update Mirza Bot"
    echo -e "\033[1;36m3)\033[0m Remove Mirza Bot"
    echo -e "\033[1;36m4)\033[0m Export Database"
    echo -e "\033[1;36m5)\033[0m Import Database"
    echo -e "\033[1;36m6)\033[0m Configure Automated Backup"
    echo -e "\033[1;36m7)\033[0m Renew SSL Certificates"
    echo -e "\033[1;36m8)\033[0m Change Domain"
    echo -e "\033[1;36m9)\033[0m Additional Bot Management"
    echo -e "\033[1;36m10)\033[0m Exit"
    echo ""
    read -p "Select an option [1-10]: " option
    case $option in
        1) install_bot ;;
        2) update_bot ;;
        3) remove_bot ;;
        4) export_database ;;
        5) import_database ;;
        6) auto_backup ;;
        7) renew_ssl ;;
        8) change_domain ;;
        9) manage_additional_bots ;;
        10)
            echo -e "\033[32mExiting...\033[0m"
            exit 0
            ;;
        *)
            echo -e "\033[31mInvalid option. Please try again.\033[0m"
            show_menu
            ;;
    esac
}

# Check if Marzban is installed
function check_marzban_installed() {
    if [ -f "/opt/marzban/docker-compose.yml" ]; then
        return 0
    else
        return 1
    fi
}

# Detect database type for Marzban
function detect_database_type() {
    COMPOSE_FILE="/opt/marzban/docker-compose.yml"
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "unknown"
        return 1
    fi
    if grep -q "^[[:space:]]*mysql:" "$COMPOSE_FILE"; then
        echo "mysql"
        return 0
    elif grep -q "^[[:space:]]*mariadb:" "$COMPOSE_FILE"; then
        echo "mariadb"
        return 1
    else
        echo "sqlite"
        return 1
    fi
}

# Remove any existing Apache installation to prevent conflicts
function remove_apache_if_exists() {
    if dpkg -s apache2 &>/dev/null; then
        echo -e "\033[33mRemoving existing Apache installation to prevent conflicts...\033[0m"
        sudo systemctl stop apache2 2>/dev/null
        sudo systemctl disable apache2 2>/dev/null
        sudo apt-get purge -y apache2 apache2-utils apache2-bin apache2-data libapache2-mod-php* 2>/dev/null
        sudo apt-get autoremove --purge -y 2>/dev/null
        sudo rm -rf /etc/apache2
        sudo ufw delete allow 'Apache' 2>/dev/null
        sudo ufw delete allow 'Apache Full' 2>/dev/null
        echo -e "\033[32mApache removed.\033[0m"
    fi
}

# Remove any existing phpMyAdmin installation
function remove_phpmyadmin_if_exists() {
    if dpkg -s phpmyadmin &>/dev/null; then
        echo -e "\033[33mRemoving existing phpMyAdmin installation...\033[0m"
        sudo apt-get purge -y phpmyadmin 2>/dev/null
        sudo apt-get autoremove --purge -y 2>/dev/null
        sudo rm -f /etc/apache2/conf-available/phpmyadmin.conf 2>/dev/null
        echo -e "\033[32mphpMyAdmin removed.\033[0m"
    fi
}

# Detect the installed PHP-FPM version
function detect_php_version() {
    local php_version=""
    for v in 8.3 8.2 8.1 8.0 7.4; do
        if dpkg -s "php${v}-fpm" &>/dev/null; then
            php_version="$v"
            break
        fi
    done
    if [ -z "$php_version" ]; then
        php_version="8.2"
    fi
    echo "$php_version"
}

# Configure nginx for the bot
function configure_nginx_bot() {
    local DOMAIN="$1"
    local BOT_DIR="$2"
    local NGINX_CONF="/etc/nginx/sites-available/mirzabotconfig"

    sudo bash -c "cat > $NGINX_CONF <<NGINXEOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    root $BOT_DIR;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_pass unix:/var/run/php/php$(detect_php_version)-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINXEOF"

    sudo ln -sf /etc/nginx/sites-available/mirzabotconfig /etc/nginx/sites-enabled/mirzabotconfig
    sudo rm -f /etc/nginx/sites-enabled/default
}

# Configure nginx for Marzban path (port 88)
function configure_nginx_bot_marzban() {
    local DOMAIN="$1"
    local BOT_DIR="$2"
    local NGINX_CONF="/etc/nginx/sites-available/mirzabotconfig"

    sudo bash -c "cat > $NGINX_CONF <<NGINXEOF
server {
    listen 88 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    root $BOT_DIR;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_pass unix:/var/run/php/php$(detect_php_version)-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINXEOF"

    sudo ln -sf /etc/nginx/sites-available/mirzabotconfig /etc/nginx/sites-enabled/mirzabotconfig
    sudo rm -f /etc/nginx/sites-enabled/default
}

# Function to fix update issues by changing mirrors
function fix_update_issues() {
    echo -e "\e[33mTrying to fix update issues by changing mirrors...\033[0m"

    cp /etc/apt/sources.list /etc/apt/sources.list.backup

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        UBUNTU_CODENAME=$(cat /etc/os-release | grep UBUNTU_CODENAME | cut -d '=' -f2)
    else
        echo -e "\e[91mCould not detect Ubuntu version.\033[0m"
        return 1
    fi

    MIRRORS=(
        "archive.ubuntu.com"
        "us.archive.ubuntu.com"
        "fr.archive.ubuntu.com"
        "de.archive.ubuntu.com"
        "mirrors.digitalocean.com"
        "mirrors.linode.com"
    )

    for mirror in "${MIRRORS[@]}"; do
        echo -e "\e[33mTrying mirror: $mirror\033[0m"
        cat > /etc/apt/sources.list << EOF
deb http://$mirror/ubuntu/ $UBUNTU_CODENAME main restricted universe multiverse
deb http://$mirror/ubuntu/ $UBUNTU_CODENAME-updates main restricted universe multiverse
deb http://$mirror/ubuntu/ $UBUNTU_CODENAME-security main restricted universe multiverse
EOF

        if apt-get update 2>/dev/null; then
            echo -e "\e[32mSuccessfully updated using mirror: $mirror\033[0m"
            return 0
        fi
    done

    mv /etc/apt/sources.list.backup /etc/apt/sources.list
    echo -e "\e[91mAll mirrors failed. Restored original sources.list\033[0m"
    return 1
}

# Install Function
function install_bot() {
    echo -e "\e[32mInstalling mirza script ... \033[0m\n"

    # Check if Marzban is installed and redirect to appropriate function
    if check_marzban_installed; then
        echo -e "\033[41m[IMPORTANT WARNING]\033[0m \033[1;33mMarzban detected. Proceeding with Marzban-compatible installation.\033[0m"
        install_bot_with_marzban "$@"
        return 0
    fi

    # Remove Apache and phpMyAdmin if they exist to prevent conflicts
    remove_apache_if_exists
    remove_phpmyadmin_if_exists

    # Add Ondrej Surý PPA for PHP
    add_php_ppa() {
        sudo add-apt-repository -y ppa:ondrej/php || {
            echo -e "\e[91mError: Failed to add PPA ondrej/php.\033[0m"
            return 1
        }
    }

    add_php_ppa_with_locale() {
        sudo LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php || {
            echo -e "\e[91mError: Failed to add PPA ondrej/php with locale override.\033[0m"
            return 1
        }
    }

    if ! add_php_ppa; then
        echo "Failed to add PPA with default locale, retrying with locale override..."
        if ! add_php_ppa_with_locale; then
            echo "Failed to add PPA even with locale override. Exiting..."
            exit 1
        fi
    fi

    # Try normal update/upgrade first
    if ! (sudo apt update && sudo apt upgrade -y); then
        echo -e "\e[93mUpdate/upgrade failed. Attempting to fix using alternative mirrors...\033[0m"
        if fix_update_issues; then
            if sudo apt update && sudo apt upgrade -y; then
                echo -e "\e[92mThe server was successfully updated after fixing mirrors...\033[0m\n"
            else
                echo -e "\e[91mError: Failed to update even after trying alternative mirrors.\033[0m"
                exit 1
            fi
        else
            echo -e "\e[91mError: Failed to update/upgrade packages and mirror fix failed.\033[0m"
            exit 1
        fi
    else
        echo -e "\e[92mThe server was successfully updated ...\033[0m\n"
    fi

    sudo apt-get install -y software-properties-common || {
        echo -e "\e[91mError: Failed to install software-properties-common.\033[0m"
        exit 1
    }

    sudo apt install -y git unzip curl || {
        echo -e "\e[91mError: Failed to install required packages.\033[0m"
        exit 1
    }

    # Install nginx
    sudo apt install -y nginx || {
        echo -e "\e[91mError: Failed to install nginx.\033[0m"
        exit 1
    }

    # Install PHP 8.2 and all necessary modules
    DEBIAN_FRONTEND=noninteractive sudo apt install -y php8.2 php8.2-fpm php8.2-mysql php8.2-mbstring php8.2-zip php8.2-gd php8.2-curl php8.2-soap php8.2-ssh2 libssh2-1-dev libssh2-1 php8.2-pdo || {
        echo -e "\e[91mError: Failed to install PHP 8.2 and modules.\033[0m"
        exit 1
    }

    # Install MySQL server
    DEBIAN_FRONTEND=noninteractive sudo apt install -y mysql-server || {
        echo -e "\e[91mError: Failed to install MySQL server.\033[0m"
        exit 1
    }

    # Additional packages
    sudo apt-get install -y jq || {
        echo -e "\e[91mError: Failed to install jq.\033[0m"
        exit 1
    }

    sudo apt-get install -y php-ssh2 || {
        echo -e "\e[91mError: Failed to install php-ssh2.\033[0m"
        exit 1
    }

    # Enable and start services
    sudo systemctl enable nginx || {
        echo -e "\e[91mError: Failed to enable nginx service.\033[0m"
        exit 1
    }
    sudo systemctl start nginx || {
        echo -e "\e[91mError: Failed to start nginx service.\033[0m"
        exit 1
    }

    sudo systemctl enable mysql.service || {
        echo -e "\e[91mError: Failed to enable MySQL service.\033[0m"
        exit 1
    }
    sudo systemctl start mysql.service || {
        echo -e "\e[91mError: Failed to start MySQL service.\033[0m"
        exit 1
    }

    sudo systemctl enable php8.2-fpm || {
        echo -e "\e[91mError: Failed to enable PHP-FPM service.\033[0m"
        exit 1
    }
    sudo systemctl start php8.2-fpm || {
        echo -e "\e[91mError: Failed to start PHP-FPM service.\033[0m"
        exit 1
    }

    # Install UFW and configure
    sudo apt-get install -y ufw || {
        echo -e "\e[91mError: Failed to install UFW.\033[0m"
        exit 1
    }
    sudo ufw allow 'Nginx Full' || {
        echo -e "\e[91mError: Failed to allow Nginx Full in UFW.\033[0m"
        exit 1
    }

    # Download and install bot files
    BOT_DIR="/var/www/html/mirzabotconfig"
    if [ -d "$BOT_DIR" ]; then
        echo -e "\e[93mDirectory $BOT_DIR already exists. Removing...\033[0m"
        sudo rm -rf "$BOT_DIR" || {
            echo -e "\e[91mError: Failed to remove existing directory $BOT_DIR.\033[0m"
            exit 1
        }
    fi

    sudo mkdir -p "$BOT_DIR"
    if [ ! -d "$BOT_DIR" ]; then
        echo -e "\e[91mError: Failed to create directory $BOT_DIR.\033[0m"
        exit 1
    fi

    # Default to latest release
    ZIP_URL=$(curl -s https://api.github.com/repos/Liwyd/botmirzapanel/releases/latest | grep "zipball_url" | cut -d '"' -f 4)

    # Check for version flag
    if [[ "$1" == "-v" && "$2" == "beta" ]] || [[ "$1" == "-beta" ]] || [[ "$1" == "-" && "$2" == "beta" ]]; then
        ZIP_URL="https://github.com/Liwyd/botmirzapanel/archive/refs/heads/main.zip"
    elif [[ "$1" == "-v" && -n "$2" ]]; then
        ZIP_URL="https://github.com/Liwyd/botmirzapanel/archive/refs/tags/$2.zip"
    fi

    TEMP_DIR="/tmp/mirzabot"
    mkdir -p "$TEMP_DIR"
    wget -O "$TEMP_DIR/bot.zip" "$ZIP_URL" || {
        echo -e "\e[91mError: Failed to download the specified version.\033[0m"
        exit 1
    }

    unzip "$TEMP_DIR/bot.zip" -d "$TEMP_DIR"
    EXTRACTED_DIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d)
    mv "$EXTRACTED_DIR"/* "$BOT_DIR" || {
        echo -e "\e[91mError: Failed to move extracted files.\033[0m"
        exit 1
    }
    rm -rf "$TEMP_DIR"

    sudo chown -R www-data:www-data "$BOT_DIR"
    sudo chmod -R 755 "$BOT_DIR"

    echo -e "\n\033[33mMirza config and script have been installed successfully.\033[0m"

    # MySQL root setup
    wait
    if [ ! -d "/root/confmirza" ]; then
        sudo mkdir /root/confmirza || {
            echo -e "\e[91mError: Failed to create /root/confmirza directory.\033[0m"
            exit 1
        }

        sleep 1

        touch /root/confmirza/dbrootmirza.txt || {
            echo -e "\e[91mError: Failed to create dbrootmirza.txt.\033[0m"
            exit 1
        }
        sudo chmod -R 777 /root/confmirza/dbrootmirza.txt || {
            echo -e "\e[91mError: Failed to set permissions for dbrootmirza.txt.\033[0m"
            exit 1
        }
        sleep 1

        randomdbpasstxt=$(openssl rand -base64 10 | tr -dc 'a-zA-Z0-9' | cut -c1-8)

        ASAS="$"

        echo "${ASAS}user = 'root';" >> /root/confmirza/dbrootmirza.txt
        echo "${ASAS}pass = '${randomdbpasstxt}';" >> /root/confmirza/dbrootmirza.txt
        echo "${ASAS}path = '${RANDOM_NUMBER}';" >> /root/confmirza/dbrootmirza.txt

        sleep 1

        passs=$(cat /root/confmirza/dbrootmirza.txt | grep '$pass' | cut -d"'" -f2)
        userrr=$(cat /root/confmirza/dbrootmirza.txt | grep '$user' | cut -d"'" -f2)

        sudo mysql -u $userrr -p$passs -e "alter user '$userrr'@'localhost' identified with mysql_native_password by '$passs';FLUSH PRIVILEGES;" || {
            echo -e "\e[91mError: Failed to alter MySQL user. Attempting recovery...\033[0m"

            sudo sed -i '$ a skip-grant-tables' /etc/mysql/mysql.conf.d/mysqld.cnf
            sudo systemctl restart mysql

            sudo mysql <<EOF
DROP USER IF EXISTS 'root'@'localhost';
CREATE USER 'root'@'localhost' IDENTIFIED BY '${passs}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

            sudo sed -i '/skip-grant-tables/d' /etc/mysql/mysql.conf.d/mysqld.cnf
            sudo systemctl restart mysql

            echo "SELECT 1" | mysql -u$userrr -p$passs 2>/dev/null || {
                echo -e "\e[91mError: Recovery failed. MySQL login still not working.\033[0m"
                exit 1
            }
        }

        echo "Folder created successfully!"
    else
        echo "Folder already exists."
    fi


    clear

    echo " "
    echo -e "\e[32m SSL \033[0m\n"

    read -p "Enter the domain: " domainname
    while [[ ! "$domainname" =~ ^[a-zA-Z0-9.-]+$ ]]; do
        echo -e "\e[91mInvalid domain format. Please try again.\033[0m"
        read -p "Enter the domain: " domainname
    done
    DOMAIN_NAME="$domainname"
    PATHS=$(cat /root/confmirza/dbrootmirza.txt | grep '$path' | cut -d"'" -f2)
    sudo ufw allow 80 || {
        echo -e "\e[91mError: Failed to allow port 80 in UFW.\033[0m"
        exit 1
    }
    sudo ufw allow 443 || {
        echo -e "\e[91mError: Failed to allow port 443 in UFW.\033[0m"
        exit 1
    }

    echo -e "\033[33mStopping nginx for SSL setup...\033[0m"
    wait

    sudo systemctl stop nginx || {
        echo -e "\e[91mError: Failed to stop nginx.\033[0m"
        exit 1
    }
    sudo apt install -y letsencrypt || {
        echo -e "\e[91mError: Failed to install letsencrypt.\033[0m"
        exit 1
    }
    sudo systemctl enable certbot.timer || {
        echo -e "\e[91mError: Failed to enable certbot timer.\033[0m"
        exit 1
    }
    sudo certbot certonly --standalone --agree-tos --preferred-challenges http -d $DOMAIN_NAME || {
        echo -e "\e[91mError: Failed to generate SSL certificate.\033[0m"
        exit 1
    }
    sudo apt install -y python3-certbot-nginx || {
        echo -e "\e[91mError: Failed to install python3-certbot-nginx.\033[0m"
        exit 1
    }

    # Configure nginx with SSL
    configure_nginx_bot "$DOMAIN_NAME" "$BOT_DIR"

    echo " "
    echo -e "\033[33mEnabling nginx\033[0m"
    wait
    sudo systemctl enable nginx || {
        echo -e "\e[91mError: Failed to enable nginx.\033[0m"
        exit 1
    }
    sudo systemctl start nginx || {
        echo -e "\e[91mError: Failed to start nginx.\033[0m"
        exit 1
    }
    clear

    printf "\e[33m[+] \e[36mBot Token: \033[0m"
    read YOUR_BOT_TOKEN
    while [[ ! "$YOUR_BOT_TOKEN" =~ ^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$ ]]; do
        echo -e "\e[91mInvalid bot token format. Please try again.\033[0m"
        printf "\e[33m[+] \e[36mBot Token: \033[0m"
        read YOUR_BOT_TOKEN
    done

    printf "\e[33m[+] \e[36mChat id: \033[0m"
    read YOUR_CHAT_ID
    while [[ ! "$YOUR_CHAT_ID" =~ ^-?[0-9]+$ ]]; do
        echo -e "\e[91mInvalid chat ID format. Please try again.\033[0m"
        printf "\e[33m[+] \e[36mChat id: \033[0m"
        read YOUR_CHAT_ID
    done

    YOUR_DOMAIN="$DOMAIN_NAME"

    while true; do
        printf "\e[33m[+] \e[36musernamebot: \033[0m"
        read YOUR_BOTNAME
        if [ "$YOUR_BOTNAME" != "" ]; then
            break
        else
            echo -e "\e[91mError: Bot username cannot be empty. Please enter a valid username.\033[0m"
        fi
    done

    ROOT_PASSWORD=$(cat /root/confmirza/dbrootmirza.txt | grep '$pass' | cut -d"'" -f2)
    ROOT_USER="root"
    echo "SELECT 1" | mysql -u$ROOT_USER -p$ROOT_PASSWORD 2>/dev/null || {
        echo -e "\e[91mError: MySQL connection failed.\033[0m"
        exit 1
    }

    if [ $? -eq 0 ]; then
        wait

        randomdbpass=$(openssl rand -base64 10 | tr -dc 'a-zA-Z0-9' | cut -c1-8)
        randomdbdb=$(openssl rand -base64 10 | tr -dc 'a-zA-Z' | cut -c1-8)

        if [[ $(mysql -u root -p$ROOT_PASSWORD -e "SHOW DATABASES LIKE 'mirzabot'" 2>/dev/null) ]]; then
            clear
            echo -e "\n\e[91mYou have already created the database\033[0m\n"
        else
            dbname=mirzabot
            clear
            echo -e "\n\e[32mPlease enter the database username!\033[0m"
            printf "[+] Default user name is \e[91m${randomdbdb}\e[0m ( let it blank to use this user name ): "
            read dbuser
            if [ "$dbuser" = "" ]; then
                dbuser=$randomdbdb
            fi

            echo -e "\n\e[32mPlease enter the database password!\033[0m"
            printf "[+] Default password is \e[91m${randomdbpass}\e[0m ( let it blank to use this password ): "
            read dbpass
            if [ "$dbpass" = "" ]; then
                dbpass=$randomdbpass
            fi

            mysql -u root -p$ROOT_PASSWORD -e "CREATE DATABASE $dbname;" -e "CREATE USER '$dbuser'@'%' IDENTIFIED WITH mysql_native_password BY '$dbpass';GRANT ALL PRIVILEGES ON * . * TO '$dbuser'@'%';FLUSH PRIVILEGES;" -e "CREATE USER '$dbuser'@'localhost' IDENTIFIED WITH mysql_native_password BY '$dbpass';GRANT ALL PRIVILEGES ON * . * TO '$dbuser'@'localhost';FLUSH PRIVILEGES;" || {
                echo -e "\e[91mError: Failed to create database or user.\033[0m"
                exit 1
            }

            echo -e "\n\e[95mDatabase Created.\033[0m"

            clear

            ASAS="$"

            wait

            sleep 1

            file_path="/var/www/html/mirzabotconfig/config.php"

            if [ -f "$file_path" ]; then
              rm "$file_path" || {
                echo -e "\e[91mError: Failed to delete old config.php.\033[0m"
                exit 1
              }
              echo -e "File deleted successfully."
            else
              echo -e "File not found."
            fi

            sleep 1

            secrettoken=$(openssl rand -base64 10 | tr -dc 'a-zA-Z0-9' | cut -c1-8)

            echo -e "<?php" >> /var/www/html/mirzabotconfig/config.php
            echo -e "${ASAS}APIKEY = '${YOUR_BOT_TOKEN}';" >> /var/www/html/mirzabotconfig/config.php
            echo -e "${ASAS}usernamedb = '${dbuser}';" >> /var/www/html/mirzabotconfig/config.php
            echo -e "${ASAS}passworddb = '${dbpass}';" >> /var/www/html/mirzabotconfig/config.php
            echo -e "${ASAS}dbname = '${dbname}';" >> /var/www/html/mirzabotconfig/config.php
            echo -e "${ASAS}domainhosts = '${YOUR_DOMAIN}/mirzabotconfig';" >> /var/www/html/mirzabotconfig/config.php
            echo -e "${ASAS}adminnumber = '${YOUR_CHAT_ID}';" >> /var/www/html/mirzabotconfig/config.php
            echo -e "${ASAS}usernamebot = '${YOUR_BOTNAME}';" >> /var/www/html/mirzabotconfig/config.php
            echo -e "${ASAS}secrettoken = '${secrettoken}';" >> /var/www/html/mirzabotconfig/config.php
            echo -e "${ASAS}connect = mysqli_connect('localhost', \$usernamedb, \$passworddb, \$dbname);" >> /var/www/html/mirzabotconfig/config.php
            echo -e "if (${ASAS}connect->connect_error) {" >> /var/www/html/mirzabotconfig/config.php
            echo -e "die(' The connection to the database failed:' . ${ASAS}connect->connect_error);" >> /var/www/html/mirzabotconfig/config.php
            echo -e "}" >> /var/www/html/mirzabotconfig/config.php
            echo -e "mysqli_set_charset(${ASAS}connect, 'utf8mb4');" >> /var/www/html/mirzabotconfig/config.php
            text_to_save=$(cat <<EOF
\$options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES   => false,
];
\$dsn = "mysql:host=localhost;dbname=${ASAS}dbname;charset=utf8mb4";
try {
     \$pdo = new PDO(\$dsn, \$usernamedb, \$passworddb, \$options);
} catch (\PDOException \$e) {
     throw new \PDOException(\$e->getMessage(), (int)\$e->getCode());
}
EOF
)
echo -e "$text_to_save" >> /var/www/html/mirzabotconfig/config.php
            echo -e "?>" >> /var/www/html/mirzabotconfig/config.php

            sleep 1

            curl -F "url=https://${YOUR_DOMAIN}/mirzabotconfig/index.php" \
     -F "secret_token=${secrettoken}" \
     "https://api.telegram.org/bot${YOUR_BOT_TOKEN}/setWebhook" || {
                echo -e "\e[91mError: Failed to set webhook for bot.\033[0m"
                exit 1
            }
            MESSAGE="The bot is installed! for start the bot send /start command."
            curl -s -X POST "https://api.telegram.org/bot${YOUR_BOT_TOKEN}/sendMessage" -d chat_id="${YOUR_CHAT_ID}" -d text="$MESSAGE" || {
                echo -e "\e[91mError: Failed to send message to Telegram.\033[0m"
                exit 1
            }

            sleep 1
            sudo systemctl start nginx || {
                echo -e "\e[91mError: Failed to start nginx.\033[0m"
                exit 1
            }
            url="https://${YOUR_DOMAIN}/mirzabotconfig/table.php"
            curl -s "$url" || {
                echo -e "\e[91mError: Failed to fetch URL from domain.\033[0m"
                exit 1
            }

            clear

            echo " "

            echo -e "\e[102mDomain Bot: https://${YOUR_DOMAIN}\033[0m"
            echo -e "\e[33mDatabase name: \e[36m${dbname}\033[0m"
            echo -e "\e[33mDatabase username: \e[36m${dbuser}\033[0m"
            echo -e "\e[33mDatabase password: \e[36m${dbpass}\033[0m"
            echo -e "\e[33mManage DB via CLI: \e[36mmysql -u ${dbuser} -p ${dbname}\033[0m"
            echo " "
            echo -e "Mirza Bot"
        fi


    elif [ "$ROOT_PASSWORD" = "" ] || [ "$ROOT_USER" = "" ]; then
        echo -e "\n\e[36mThe password is empty.\033[0m\n"
    else

        echo -e "\n\e[36mThe password is not correct.\033[0m\n"

    fi

    # Add executable permission and link
    chmod +x /root/install.sh
    ln -vs /root/install.sh /usr/local/bin/mirza

}

function install_bot_with_marzban() {
    # Display warning and confirmation
    echo -e "\033[41m[IMPORTANT WARNING]\033[0m \033[1;33mMarzban panel is detected on your server. Please make sure to backup the Marzban database before installing Mirza Bot.\033[0m"
    read -p "Are you sure you want to install Mirza Bot alongside Marzban? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "\e[91mInstallation aborted by user.\033[0m"
        exit 0
    fi

    # Check database type
    echo -e "\e[32mChecking Marzban database type...\033[0m"
    DB_TYPE=$(detect_database_type)
    if [ "$DB_TYPE" != "mysql" ]; then
        echo -e "\e[91mError: Your database is $DB_TYPE. To install Mirza Bot, you must use MySQL.\033[0m"
        echo -e "\e[93mPlease configure Marzban to use MySQL and try again.\033[0m"
        exit 1
    fi
    echo -e "\e[92mMySQL detected. Proceeding with installation...\033[0m"

    # Check if port 88 is free before proceeding (Marzban uses 443, we use 88)
    echo -e "\e[32mChecking port availability...\033[0m"
    if sudo ss -tuln | grep -q ":88 "; then
        echo -e "\e[91mError: Port 88 is already in use. Please free port 88 and run the script again.\033[0m"
        exit 1
    fi
    echo -e "\e[92mPort 88 is free. Proceeding with installation...\033[0m"

    # Remove Apache and phpMyAdmin if they exist
    remove_apache_if_exists
    remove_phpmyadmin_if_exists

    # Try normal update/upgrade first
    if ! (sudo apt update && sudo apt upgrade -y); then
        echo -e "\e[93mUpdate/upgrade failed. Attempting to fix using alternative mirrors...\033[0m"
        if fix_update_issues; then
            if sudo apt update && sudo apt upgrade -y; then
                echo -e "\e[92mSystem updated successfully after fixing mirrors...\033[0m\n"
            else
                echo -e "\e[91mError: Failed to update even after trying alternative mirrors.\033[0m"
                exit 1
            fi
        else
            echo -e "\e[91mError: Failed to update/upgrade system and mirror fix failed.\033[0m"
            exit 1
        fi
    else
        echo -e "\e[92mSystem updated successfully...\033[0m\n"
    fi

    sudo apt-get install -y software-properties-common || {
        echo -e "\e[91mError: Failed to install software-properties-common.\033[0m"
        exit 1
    }

    # Install MySQL client
    echo -e "\e[32mChecking and installing MySQL client...\033[0m"
    if ! command -v mysql &>/dev/null; then
        sudo apt install -y mysql-client || {
            echo -e "\e[91mError: Failed to install MySQL client.\033[0m"
            exit 1
        }
        echo -e "\e[92mMySQL client installed successfully.\033[0m"
    else
        echo -e "\e[92mMySQL client is already installed.\033[0m"
    fi

    # Add Ondrej Surý PPA for PHP 8.2
    sudo add-apt-repository -y ppa:ondrej/php || {
        echo -e "\e[91mError: Failed to add PPA ondrej/php. Trying with locale override...\033[0m"
        sudo LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php || {
            echo -e "\e[91mError: Failed to add PPA even with locale override.\033[0m"
            exit 1
        }
    }
    sudo apt update || {
        echo -e "\e[91mError: Failed to update package list after adding PPA.\033[0m"
        exit 1
    }

    # Install all required packages
    sudo apt install -y git unzip curl wget jq || {
        echo -e "\e[91mError: Failed to install basic tools.\033[0m"
        exit 1
    }

    # Install nginx
    sudo apt install -y nginx || {
        echo -e "\e[91mError: Failed to install nginx.\033[0m"
        exit 1
    }

    # Install PHP 8.2 and all necessary modules
    DEBIAN_FRONTEND=noninteractive sudo apt install -y php8.2 php8.2-fpm php8.2-mysql php8.2-mbstring php8.2-zip php8.2-gd php8.2-curl php8.2-soap php8.2-ssh2 libssh2-1-dev libssh2-1 php8.2-pdo || {
        echo -e "\e[91mError: Failed to install PHP 8.2 and modules.\033[0m"
        exit 1
    }

    sudo apt install -y python3-certbot-nginx || {
        echo -e "\e[91mError: Failed to install Certbot for nginx.\033[0m"
        exit 1
    }
    sudo systemctl enable certbot.timer || {
        echo -e "\e[91mError: Failed to enable certbot timer.\033[0m"
        exit 1
    }

    # Install UFW if not present
    if ! dpkg -s ufw &>/dev/null; then
        sudo apt install -y ufw || {
            echo -e "\e[91mError: Failed to install UFW.\033[0m"
            exit 1
        }
    fi

    # Check Marzban and use its MySQL (Docker-based)
    ENV_FILE="/opt/marzban/.env"
    if [ ! -f "$ENV_FILE" ]; then
        echo -e "\e[91mError: Marzban .env file not found.\033[0m"
        exit 1
    fi

    # Get MySQL root password from .env
    MYSQL_ROOT_PASSWORD=$(grep "MYSQL_ROOT_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '[:space:]' | sed 's/"//g')
    ROOT_USER="root"

    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        echo -e "\e[93mWarning: Could not retrieve MySQL root password from Marzban .env file.\033[0m"
        read -s -p "Please enter the MySQL root password manually: " MYSQL_ROOT_PASSWORD
        echo
    fi

    # Dynamically find the MySQL container
    MYSQL_CONTAINER=$(docker ps -q --filter "name=mysql" --no-trunc)
    if [ -z "$MYSQL_CONTAINER" ]; then
        echo -e "\e[91mError: Could not find a running MySQL container.\033[0m"
        echo -e "\e[93mRunning containers:\033[0m"
        docker ps
        exit 1
    fi

    echo "Testing MySQL connection..."

    if [ -f "/opt/marzban/.env" ]; then
        MYSQL_ROOT_PASSWORD=$(grep -E '^MYSQL_ROOT_PASSWORD=' /opt/marzban/.env | cut -d '=' -f2- | tr -d '" \n\r')
        if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
            echo -e "\e[93mWarning: MYSQL_ROOT_PASSWORD not found in .env.\033[0m"
            read -s -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
            echo
        fi
    else
        echo -e "\e[93mWarning: .env file not found.\033[0m"
        read -s -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
        echo
    fi

    ROOT_USER="root"
    echo -e "\e[32mUsing MySQL container: $(docker inspect -f '{{.Name}}' "$MYSQL_CONTAINER" | cut -c2-)\033[0m"

    # Try connecting directly to host first
    mysql -u "$ROOT_USER" -p"$MYSQL_ROOT_PASSWORD" -h 127.0.0.1 -P 3306 -e "SELECT 1;" 2>/tmp/mysql_error.log
    if [ $? -eq 0 ]; then
        echo -e "\e[92mMySQL connection successful (direct host method).\033[0m"
    else
        if [ -n "$MYSQL_CONTAINER" ]; then
            echo -e "\e[93mDirect connection failed, trying inside container...\033[0m"
            docker exec "$MYSQL_CONTAINER" bash -c "echo 'SELECT 1;' | mysql -u '$ROOT_USER' -p'$MYSQL_ROOT_PASSWORD'" 2>/tmp/mysql_error.log
            if [ $? -eq 0 ]; then
                echo -e "\e[92mMySQL connection successful (container method).\033[0m"
            else
                echo -e "\e[91mError: Failed to connect to MySQL using both methods.\033[0m"
                echo -e "\e[93mPassword used: '$MYSQL_ROOT_PASSWORD'\033[0m"
                echo -e "\e[93mError details:\033[0m"
                cat /tmp/mysql_error.log
                echo -e "\e[93mPlease ensure MySQL is running and the root password is correct.\033[0m"
                read -s -p "Enter the correct MySQL root password: " NEW_PASSWORD
                echo
                MYSQL_ROOT_PASSWORD="$NEW_PASSWORD"
                mysql -u "$ROOT_USER" -p"$MYSQL_ROOT_PASSWORD" -h 127.0.0.1 -P 3306 -e "SELECT 1;" 2>/tmp/mysql_error.log || {
                    docker exec "$MYSQL_CONTAINER" bash -c "echo 'SELECT 1;' | mysql -u '$ROOT_USER' -p'$MYSQL_ROOT_PASSWORD'" 2>/tmp/mysql_error.log || {
                        echo -e "\e[91mError: Still can't connect with new password.\033[0m"
                        cat /tmp/mysql_error.log
                        exit 1
                    }
                }
                echo -e "\e[92mMySQL connection successful with new password.\033[0m"
            fi
        else
            echo -e "\e[91mError: No MySQL container found and direct connection failed.\033[0m"
            cat /tmp/mysql_error.log
            exit 1
        fi
    fi

    # Ask for database username and password
    clear
    echo -e "\e[33mConfiguring Mirza Bot database credentials...\033[0m"
    default_dbuser=$(openssl rand -base64 12 | tr -dc 'a-zA-Z' | head -c8)
    printf "\e[33m[+] \e[36mDatabase username (default: $default_dbuser): \033[0m"
    read dbuser
    if [ -z "$dbuser" ]; then
        dbuser="$default_dbuser"
    fi

    default_dbpass=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c12)
    printf "\e[33m[+] \e[36mDatabase password (default: $default_dbpass): \033[0m"
    read -s dbpass
    echo
    if [ -z "$dbpass" ]; then
        dbpass="$default_dbpass"
    fi
    dbname="mirzabot"

    # Create database and user inside Docker container
    docker exec "$MYSQL_CONTAINER" bash -c "mysql -u '$ROOT_USER' -p'$MYSQL_ROOT_PASSWORD' -e \"CREATE DATABASE IF NOT EXISTS $dbname; CREATE USER IF NOT EXISTS '$dbuser'@'%' IDENTIFIED BY '$dbpass'; GRANT ALL PRIVILEGES ON $dbname.* TO '$dbuser'@'%'; FLUSH PRIVILEGES;\"" || {
        echo -e "\e[91mError: Failed to create database or user in Marzban MySQL container.\033[0m"
        exit 1
    }
    echo -e "\e[92mDatabase '$dbname' created successfully.\033[0m"

    # Bot directory setup
    BOT_DIR="/var/www/html/mirzabotconfig"
    if [ -d "$BOT_DIR" ]; then
        echo -e "\e[93mDirectory $BOT_DIR already exists. Removing...\033[0m"
        sudo rm -rf "$BOT_DIR" || {
            echo -e "\e[91mError: Failed to remove existing directory $BOT_DIR.\033[0m"
            exit 1
        }
    fi
    sudo mkdir -p "$BOT_DIR" || {
        echo -e "\e[91mError: Failed to create directory $BOT_DIR.\033[0m"
        exit 1
    }

    # Download bot files
    ZIP_URL=$(curl -s https://api.github.com/repos/Liwyd/botmirzapanel/releases/latest | grep "zipball_url" | cut -d '"' -f 4)
    if [[ "$1" == "-v" && "$2" == "beta" ]] || [[ "$1" == "-beta" ]] || [[ "$1" == "-" && "$2" == "beta" ]]; then
        ZIP_URL="https://github.com/Liwyd/botmirzapanel/archive/refs/heads/main.zip"
    elif [[ "$1" == "-v" && -n "$2" ]]; then
        ZIP_URL="https://github.com/Liwyd/botmirzapanel/archive/refs/tags/$2.zip"
    fi

    TEMP_DIR="/tmp/mirzabot"
    mkdir -p "$TEMP_DIR"
    wget -O "$TEMP_DIR/bot.zip" "$ZIP_URL" || {
        echo -e "\e[91mError: Failed to download bot files.\033[0m"
        exit 1
    }
    unzip "$TEMP_DIR/bot.zip" -d "$TEMP_DIR" || {
        echo -e "\e[91mError: Failed to unzip bot files.\033[0m"
        exit 1
    }
    EXTRACTED_DIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d)
    mv "$EXTRACTED_DIR"/* "$BOT_DIR" || {
        echo -e "\e[91mError: Failed to move bot files.\033[0m"
        exit 1
    }
    rm -rf "$TEMP_DIR"

    sudo chown -R www-data:www-data "$BOT_DIR"
    sudo chmod -R 755 "$BOT_DIR"
    echo -e "\e[92mBot files installed in $BOT_DIR.\033[0m"
    sleep 3
    clear

    # SSL setup on port 88 (Marzban uses 443, we use 88)
    echo -e "\e[32mConfiguring SSL on port 88...\033[0m\n"
    sudo ufw allow 80 || {
        echo -e "\e[91mError: Failed to configure firewall for port 80.\033[0m"
        exit 1
    }
    sudo ufw allow 88 || {
        echo -e "\e[91mError: Failed to configure firewall for port 88.\033[0m"
        exit 1
    }
    clear
    printf "\e[33m[+] \e[36mEnter the domain (e.g., example.com): \033[0m"
    read domainname
    while [[ ! "$domainname" =~ ^[a-zA-Z0-9.-]+$ ]]; do
        echo -e "\e[91mInvalid domain format. Must be like 'example.com'. Please try again.\033[0m"
        printf "\e[33m[+] \e[36mEnter the domain (e.g., example.com): \033[0m"
        read domainname
    done
    DOMAIN_NAME="$domainname"
    echo -e "\e[92mDomain set to: $DOMAIN_NAME\033[0m"

    # Start nginx for certbot
    sudo systemctl start nginx || {
        echo -e "\e[91mError: Failed to start nginx before Certbot.\033[0m"
        exit 1
    }
    sudo certbot certonly --standalone --agree-tos --preferred-challenges http -d "$DOMAIN_NAME" || {
        echo -e "\e[91mError: Failed to obtain SSL certificate.\033[0m"
        exit 1
    }

    # Configure nginx for port 88
    configure_nginx_bot_marzban "$DOMAIN_NAME" "$BOT_DIR"

    # Remove port 80 from UFW after SSL is configured
    sudo ufw delete allow 80 || {
        echo -e "\e[91mError: Failed to remove port 80 from firewall.\033[0m"
    }

    sudo nginx -t || {
        echo -e "\e[91mError: nginx configuration test failed.\033[0m"
        exit 1
    }
    sudo systemctl restart nginx || {
        echo -e "\e[91mError: Failed to restart nginx after SSL configuration.\033[0m"
        systemctl status nginx.service
        exit 1
    }
    echo -e "\e[92mSSL configured successfully on port 88. Port 80 disabled.\033[0m"
    sleep 3
    clear

    # Bot token, chat ID, and username
    printf "\e[33m[+] \e[36mBot Token: \033[0m"
    read YOUR_BOT_TOKEN
    while [[ ! "$YOUR_BOT_TOKEN" =~ ^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$ ]]; do
        echo -e "\e[91mInvalid bot token format. Please try again.\033[0m"
        printf "\e[33m[+] \e[36mBot Token: \033[0m"
        read YOUR_BOT_TOKEN
    done

    printf "\e[33m[+] \e[36mChat id: \033[0m"
    read YOUR_CHAT_ID
    while [[ ! "$YOUR_CHAT_ID" =~ ^-?[0-9]+$ ]]; do
        echo -e "\e[91mInvalid chat ID format. Please try again.\033[0m"
        printf "\e[33m[+] \e[36mChat id: \033[0m"
        read YOUR_CHAT_ID
    done

    YOUR_DOMAIN="$DOMAIN_NAME:88"
    printf "\e[33m[+] \e[36mUsernamebot: \033[0m"
    read YOUR_BOTNAME
    while [ -z "$YOUR_BOTNAME" ]; do
        echo -e "\e[91mError: Bot username cannot be empty.\033[0m"
        printf "\e[33m[+] \e[36mUsernamebot: \033[0m"
        read YOUR_BOTNAME
    done

    # Create config file
    ASAS="$"
    secrettoken=$(openssl rand -base64 10 | tr -dc 'a-zA-Z0-9' | cut -c1-8)
    cat <<EOF > "$BOT_DIR/config.php"
<?php
${ASAS}APIKEY = '$YOUR_BOT_TOKEN';
${ASAS}usernamedb = '$dbuser';
${ASAS}passworddb = '$dbpass';
${ASAS}dbname = '$dbname';
${ASAS}domainhosts = '$YOUR_DOMAIN/mirzabotconfig';
${ASAS}adminnumber = '$YOUR_CHAT_ID';
${ASAS}usernamebot = '$YOUR_BOTNAME';
${ASAS}secrettoken = '$secrettoken';

${ASAS}connect = mysqli_connect('127.0.0.1', \$usernamedb, \$passworddb, \$dbname);
if (${ASAS}connect->connect_error) {
    die('Database connection failed: ' . ${ASAS}connect->connect_error);
}
mysqli_set_charset(${ASAS}connect, 'utf8mb4');

${ASAS}options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES   => false,
];
${ASAS}dsn = "mysql:host=127.0.0.1;port=3306;dbname=\$dbname;charset=utf8mb4";
try {
    ${ASAS}pdo = new PDO(\$dsn, \$usernamedb, \$passworddb, \$options);
} catch (\PDOException \$e) {
    die('PDO Connection failed: ' . \$e->getMessage());
}
?>
EOF

    # Set webhook with port 88
    curl -F "url=https://${YOUR_DOMAIN}/mirzabotconfig/index.php" \
         -F "secret_token=${secrettoken}" \
         "https://api.telegram.org/bot${YOUR_BOT_TOKEN}/setWebhook" || {
        echo -e "\e[91mError: Failed to set webhook.\033[0m"
        exit 1
    }

    # Send confirmation message
    MESSAGE="The bot is installed! for start bot send comment /start"
    curl -s -X POST "https://api.telegram.org/bot${YOUR_BOT_TOKEN}/sendMessage" -d chat_id="${YOUR_CHAT_ID}" -d text="$MESSAGE" || {
        echo -e "\033[31mError: Failed to send message to Telegram.\033[0m"
        return 1
    }

    # Execute table creation script
    TABLE_SETUP_URL="https://${YOUR_DOMAIN}/mirzabotconfig/table.php"
    echo -e "\033[33mSetting up database tables...\033[0m"
    curl -s "$TABLE_SETUP_URL" || {
        echo -e "\033[31mError: Failed to execute table creation script at $TABLE_SETUP_URL.\033[0m"
        return 1
    }

    # Output Bot Information
    echo -e "\033[32mBot installed successfully!\033[0m"
    echo -e "\033[102mDomain Bot: https://$YOUR_DOMAIN\033[0m"
    echo -e "\033[33mDatabase name: \033[36m$dbname\033[0m"
    echo -e "\033[33mDatabase username: \033[36m$dbuser\033[0m"
    echo -e "\033[33mDatabase password: \033[36m$dbpass\033[0m"

    # Add executable permission and link
    chmod +x /root/install.sh
    ln -vs /root/install.sh /usr/local/bin/mirza
}

# Update Function
function update_bot() {
    echo "Updating Mirza Bot..."

    if ! sudo apt update && sudo apt upgrade -y; then
        echo -e "\e[91mError updating the server. Exiting...\033[0m"
        exit 1
    fi
    echo -e "\e[92mServer packages updated successfully...\033[0m\n"

    BOT_DIR="/var/www/html/mirzabotconfig"
    if [ ! -d "$BOT_DIR" ]; then
        echo -e "\e[91mError: Mirza Bot is not installed. Please install it first.\033[0m"
        exit 1
    fi

    # Fetch latest release from GitHub
    if [[ "$1" == "-beta" ]] || [[ "$1" == "-v" && "$2" == "beta" ]]; then
        ZIP_URL="https://github.com/Liwyd/botmirzapanel/archive/refs/heads/main.zip"
    else
        ZIP_URL=$(curl -s https://api.github.com/repos/Liwyd/botmirzapanel/releases/latest | grep "zipball_url" | cut -d '"' -f4)
    fi

    TEMP_DIR="/tmp/mirzabot_update"
    mkdir -p "$TEMP_DIR"

    wget -O "$TEMP_DIR/bot.zip" "$ZIP_URL" || {
        echo -e "\e[91mError: Failed to download update package.\033[0m"
        exit 1
    }
    unzip "$TEMP_DIR/bot.zip" -d "$TEMP_DIR"

    EXTRACTED_DIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d)

    CONFIG_PATH="/var/www/html/mirzabotconfig/config.php"
    TEMP_CONFIG="/root/mirza_config_backup.php"
    if [ -f "$CONFIG_PATH" ]; then
        cp "$CONFIG_PATH" "$TEMP_CONFIG" || {
            echo -e "\e[91mConfig file backup failed!\033[0m"
            exit 1
        }
    fi

    sudo rm -rf /var/www/html/mirzabotconfig || {
        echo -e "\e[91mFailed to remove old bot files!\033[0m"
        exit 1
    }

    sudo mkdir -p /var/www/html/mirzabotconfig
    sudo mv "$EXTRACTED_DIR"/* /var/www/html/mirzabotconfig/ || {
        echo -e "\e[91mFile transfer failed!\033[0m"
        exit 1
    }

    if [ -f "$TEMP_CONFIG" ]; then
        sudo mv "$TEMP_CONFIG" "$CONFIG_PATH" || {
            echo -e "\e[91mConfig file restore failed!\033[0m"
            exit 1
        }
    fi

    if [ -f "/var/www/html/mirzabotconfig/install.sh" ]; then
        sudo cp /var/www/html/mirzabotconfig/install.sh /root/install.sh
        echo -e "\n\e[92mCopied latest install.sh to /root/install.sh.\033[0m"
    else
        echo -e "\n\e[91mWarning: install.sh not found after update.\033[0m"
    fi

    sudo chown -R www-data:www-data /var/www/html/mirzabotconfig/
    sudo chmod -R 755 /var/www/html/mirzabotconfig/

    URL=$(grep '\$domainhosts' "$CONFIG_PATH" | cut -d"'" -f2)
    curl -s "https://$URL/table.php" || {
        echo -e "\e[91mSetup script execution failed!\033[0m"
    }

    rm -rf "$TEMP_DIR"

    echo -e "\n\e[92mMirza Bot updated to latest version successfully!\033[0m"

    if [ -f "/root/install.sh" ]; then
        sudo chmod +x /root/install.sh
        sudo ln -vsf /root/install.sh /usr/local/bin/mirza
        echo -e "\e[92mEnsured /root/install.sh is executable and 'mirza' command is linked.\033[0m"
    fi
}

# Delete Function
function remove_bot() {
    echo -e "\e[33mStarting Mirza Bot removal process...\033[0m"
    LOG_FILE="/var/log/remove_bot.log"
    echo "Log file: $LOG_FILE" > "$LOG_FILE"

    BOT_DIR="/var/www/html/mirzabotconfig"
    if [ ! -d "$BOT_DIR" ]; then
        echo -e "\e[31m[ERROR]\033[0m Mirza Bot is not installed (/var/www/html/mirzabotconfig not found)." | tee -a "$LOG_FILE"
        echo -e "\e[33mNothing to remove. Exiting...\033[0m" | tee -a "$LOG_FILE"
        sleep 2
        exit 1
    fi

    read -p "Are you sure you want to remove Mirza Bot and its dependencies? (y/n): " choice
    if [[ "$choice" != "y" ]]; then
        echo "Aborting..." | tee -a "$LOG_FILE"
        exit 0
    fi

    # Check if Marzban is installed and redirect to appropriate function
    if check_marzban_installed; then
        echo -e "\e[41m[IMPORTANT NOTICE]\033[0m \e[33mMarzban detected. Proceeding with Marzban-compatible removal.\033[0m" | tee -a "$LOG_FILE"
        remove_bot_with_marzban
        return 0
    fi

    echo "Removing Mirza Bot..." | tee -a "$LOG_FILE"

    # Delete the Bot Directory
    if [ -d "$BOT_DIR" ]; then
        sudo rm -rf "$BOT_DIR" && echo -e "\e[92mBot directory removed: $BOT_DIR\033[0m" | tee -a "$LOG_FILE" || {
            echo -e "\e[91mFailed to remove bot directory: $BOT_DIR. Exiting...\033[0m" | tee -a "$LOG_FILE"
            exit 1
        }
    fi

    # Delete Configuration File
    CONFIG_PATH="/root/config.php"
    if [ -f "$CONFIG_PATH" ]; then
        sudo shred -u -n 5 "$CONFIG_PATH" && echo -e "\e[92mConfig file securely removed: $CONFIG_PATH\033[0m" | tee -a "$LOG_FILE" || {
            echo -e "\e[91mFailed to securely remove config file: $CONFIG_PATH\033[0m" | tee -a "$LOG_FILE"
        }
    fi

    # Delete MySQL and Database Data
    echo -e "\e[33mRemoving MySQL and database...\033[0m" | tee -a "$LOG_FILE"
    sudo systemctl stop mysql
    sudo systemctl disable mysql
    sudo systemctl daemon-reload

    sudo apt --fix-broken install -y

    sudo apt-get purge -y mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-*
    sudo rm -rf /etc/mysql /var/lib/mysql /var/log/mysql /var/log/mysql.* /usr/lib/mysql /usr/include/mysql /usr/share/mysql
    sudo rm /lib/systemd/system/mysql.service
    sudo rm /etc/init.d/mysql

    sudo dpkg --remove --force-remove-reinstreq mysql-server mysql-server-8.0

    sudo find /etc/systemd /lib/systemd /usr/lib/systemd -name "*mysql*" -exec rm -f {} \;

    sudo apt-get purge -y mysql-server mysql-server-8.0 mysql-client mysql-client-8.0
    sudo apt-get purge -y mysql-client-core-8.0 mysql-server-core-8.0 mysql-common php-mysql php8.2-mysql php8.3-mysql php-mariadb-mysql-kbs

    sudo apt-get autoremove --purge -y
    sudo apt-get clean
    sudo apt-get update

    echo -e "\e[92mMySQL has been completely removed.\033[0m" | tee -a "$LOG_FILE"

    # Remove nginx
    echo -e "\e[33mRemoving nginx...\033[0m" | tee -a "$LOG_FILE"
    sudo systemctl stop nginx || {
        echo -e "\e[91mFailed to stop nginx. Continuing anyway...\033[0m" | tee -a "$LOG_FILE"
    }
    sudo systemctl disable nginx || {
        echo -e "\e[91mFailed to disable nginx. Continuing anyway...\033[0m" | tee -a "$LOG_FILE"
    }
    sudo apt-get purge -y nginx nginx-common || {
        echo -e "\e[91mFailed to purge nginx packages.\033[0m" | tee -a "$LOG_FILE"
    }
    sudo apt-get autoremove --purge -y
    sudo apt-get autoclean -y
    sudo rm -rf /etc/nginx /var/www/html

    # Remove phpMyAdmin if present
    echo -e "\e[33mRemoving phpMyAdmin...\033[0m" | tee -a "$LOG_FILE"
    if dpkg -s phpmyadmin &>/dev/null; then
        sudo apt-get purge -y phpmyadmin && echo -e "\e[92mphpMyAdmin removed.\033[0m" | tee -a "$LOG_FILE"
        sudo apt-get autoremove -y && sudo apt-get autoclean -y
    else
        echo -e "\e[93mphpMyAdmin is not installed.\033[0m" | tee -a "$LOG_FILE"
    fi

    # Remove Unnecessary Packages
    echo -e "\e[33mRemoving additional packages...\033[0m" | tee -a "$LOG_FILE"
    sudo apt-get remove -y php-soap php-ssh2 libssh2-1-dev libssh2-1 \
        && echo -e "\e[92mRemoved additional PHP packages.\033[0m" | tee -a "$LOG_FILE" || echo -e "\e[93mSome additional PHP packages may not be installed.\033[0m" | tee -a "$LOG_FILE"

    # Reset Firewall
    echo -e "\e[33mResetting firewall rules (except SSL)...\033[0m" | tee -a "$LOG_FILE"
    sudo ufw delete allow 'Nginx Full' 2>/dev/null
    sudo ufw delete allow 'Nginx HTTP' 2>/dev/null
    sudo ufw delete allow 'Nginx HTTPS' 2>/dev/null
    sudo ufw reload

    echo -e "\e[92mMirza Bot, MySQL, and their dependencies have been completely removed.\033[0m" | tee -a "$LOG_FILE"
}

function remove_bot_with_marzban() {
    echo -e "\e[33mRemoving Mirza Bot alongside Marzban...\033[0m" | tee -a "$LOG_FILE"

    BOT_DIR="/var/www/html/mirzabotconfig"

    if [ ! -d "$BOT_DIR" ]; then
        echo -e "\e[93mWarning: Bot directory $BOT_DIR not found. Assuming it was already removed.\033[0m" | tee -a "$LOG_FILE"
        DB_NAME="mirzabot"
        DB_USER=""
    else
        CONFIG_PATH="$BOT_DIR/config.php"
        if [ -f "$CONFIG_PATH" ]; then
            DB_USER=$(grep '^\$usernamedb' "$CONFIG_PATH" | awk -F"'" '{print $2}')
            DB_NAME=$(grep '^\$dbname' "$CONFIG_PATH" | awk -F"'" '{print $2}')
            if [ -z "$DB_USER" ] || [ -z "$DB_NAME" ]; then
                echo -e "\e[91mError: Could not extract database credentials from $CONFIG_PATH. Using defaults.\033[0m" | tee -a "$LOG_FILE"
                DB_NAME="mirzabot"
                DB_USER=""
            else
                echo -e "\e[92mFound database credentials: User=$DB_USER, Database=$DB_NAME\033[0m" | tee -a "$LOG_FILE"
            fi
        else
            echo -e "\e[93mWarning: config.php not found at $CONFIG_PATH.\033[0m" | tee -a "$LOG_FILE"
            DB_NAME="mirzabot"
            DB_USER=""
        fi

        sudo rm -rf "$BOT_DIR" && echo -e "\e[92mBot directory removed: $BOT_DIR\033[0m" | tee -a "$LOG_FILE" || {
            echo -e "\e[91mFailed to remove bot directory: $BOT_DIR. Exiting...\033[0m" | tee -a "$LOG_FILE"
            exit 1
        }
    fi

    # Get MySQL root password from Marzban's .env
    ENV_FILE="/opt/marzban/.env"
    if [ -f "$ENV_FILE" ]; then
        MYSQL_ROOT_PASSWORD=$(grep "MYSQL_ROOT_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '[:space:]' | sed 's/"//g')
        ROOT_USER="root"
    else
        echo -e "\e[91mError: Marzban .env file not found.\033[0m" | tee -a "$LOG_FILE"
        exit 1
    fi

    MYSQL_CONTAINER=$(docker ps -q --filter "name=mysql" --no-trunc)
    if [ -z "$MYSQL_CONTAINER" ]; then
        echo -e "\e[91mError: Could not find a running MySQL container.\033[0m" | tee -a "$LOG_FILE"
        exit 1
    fi

    # Remove database
    if [ -n "$DB_NAME" ]; then
        echo -e "\e[33mRemoving database $DB_NAME...\033[0m" | tee -a "$LOG_FILE"
        docker exec "$MYSQL_CONTAINER" bash -c "mysql -u '$ROOT_USER' -p'$MYSQL_ROOT_PASSWORD' -e \"DROP DATABASE IF EXISTS $DB_NAME;\"" && {
            echo -e "\e[92mDatabase $DB_NAME removed successfully.\033[0m" | tee -a "$LOG_FILE"
        } || {
            echo -e "\e[91mFailed to remove database $DB_NAME.\033[0m" | tee -a "$LOG_FILE"
        }
    fi

    # Remove user if DB_USER is available
    if [ -n "$DB_USER" ]; then
        echo -e "\e[33mRemoving database user $DB_USER...\033[0m" | tee -a "$LOG_FILE"
        docker exec "$MYSQL_CONTAINER" bash -c "mysql -u '$ROOT_USER' -p'$MYSQL_ROOT_PASSWORD' -e \"DROP USER IF EXISTS '$DB_USER'@'%'; FLUSH PRIVILEGES;\"" && {
            echo -e "\e[92mUser $DB_USER removed successfully.\033[0m" | tee -a "$LOG_FILE"
        } || {
            echo -e "\e[91mFailed to remove user $DB_USER.\033[0m" | tee -a "$LOG_FILE"
        }
    else
        echo -e "\e[93mWarning: No database user specified. Checking for non-default users...\033[0m" | tee -a "$LOG_FILE"
        MIRZA_USERS=$(docker exec "$MYSQL_CONTAINER" bash -c "mysql -u '$ROOT_USER' -p'$MYSQL_ROOT_PASSWORD' -e \"SELECT User FROM mysql.user WHERE User NOT IN ('root', 'mysql.infoschema', 'mysql.session', 'mysql.sys', 'marzban');\"" | grep -v "User" | awk '{print $1}')
        if [ -n "$MIRZA_USERS" ]; then
            for user in $MIRZA_USERS; do
                echo -e "\e[33mRemoving detected non-default user: $user...\033[0m" | tee -a "$LOG_FILE"
                docker exec "$MYSQL_CONTAINER" bash -c "mysql -u '$ROOT_USER' -p'$MYSQL_ROOT_PASSWORD' -e \"DROP USER IF EXISTS '$user'@'%'; FLUSH PRIVILEGES;\"" && {
                    echo -e "\e[92mUser $user removed successfully.\033[0m" | tee -a "$LOG_FILE"
                } || {
                    echo -e "\e[91mFailed to remove user $user.\033[0m" | tee -a "$LOG_FILE"
                }
            done
        else
            echo -e "\e[93mNo non-default users found.\033[0m" | tee -a "$LOG_FILE"
        fi
    fi

    # Remove nginx
    echo -e "\e[33mRemoving nginx...\033[0m" | tee -a "$LOG_FILE"
    sudo systemctl stop nginx || {
        echo -e "\e[91mFailed to stop nginx. Continuing anyway...\033[0m" | tee -a "$LOG_FILE"
    }
    sudo systemctl disable nginx || {
        echo -e "\e[91mFailed to disable nginx. Continuing anyway...\033[0m" | tee -a "$LOG_FILE"
    }
    sudo apt-get purge -y nginx nginx-common || {
        echo -e "\e[91mFailed to purge nginx packages.\033[0m" | tee -a "$LOG_FILE"
    }
    sudo apt-get autoremove --purge -y
    sudo apt-get autoclean -y
    sudo rm -rf /etc/nginx /var/www/html

    # Reset Firewall (keep SSL)
    echo -e "\e[33mResetting firewall rules (keeping SSL)...\033[0m" | tee -a "$LOG_FILE"
    sudo ufw delete allow 'Nginx Full' 2>/dev/null
    sudo ufw delete allow 'Nginx HTTP' 2>/dev/null
    sudo ufw delete allow 'Nginx HTTPS' 2>/dev/null
    sudo ufw reload

    echo -e "\e[92mMirza Bot has been removed alongside Marzban. SSL certificates remain intact.\033[0m" | tee -a "$LOG_FILE"
}

# Extract database credentials from config.php
function extract_db_credentials() {
    CONFIG_PATH="/var/www/html/mirzabotconfig/config.php"
    if [ -f "$CONFIG_PATH" ]; then
        DB_USER=$(grep '^\$usernamedb' "$CONFIG_PATH" | awk -F"'" '{print $2}')
        DB_PASS=$(grep '^\$passworddb' "$CONFIG_PATH" | awk -F"'" '{print $2}')
        DB_NAME=$(grep '^\$dbname' "$CONFIG_PATH" | awk -F"'" '{print $2}')
        TELEGRAM_TOKEN=$(grep '^\$APIKEY' "$CONFIG_PATH" | awk -F"'" '{print $2}')
        TELEGRAM_CHAT_ID=$(grep '^\$adminnumber' "$CONFIG_PATH" | awk -F"'" '{print $2}')
        if [ -z "$DB_USER" ] || [ -z "$DB_PASS" ] || [ -z "$DB_NAME" ] || [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
            echo -e "\033[31m[ERROR]\033[0m Failed to extract required credentials from $CONFIG_PATH."
            return 1
        fi
        return 0
    else
        echo -e "\033[31m[ERROR]\033[0m config.php not found at $CONFIG_PATH."
        return 1
    fi
}

# Translate cron schedule to human-readable format
function translate_cron() {
    local cron_line="$1"
    local schedule=""
    case "$cron_line" in
        "* * * * *"*) schedule="Every Minute" ;;
        "0 * * * *"*) schedule="Every Hour" ;;
        "0 0 * * *"*) schedule="Every Day" ;;
        "0 0 * * 0"*) schedule="Every Week" ;;
        *) schedule="Custom Schedule ($cron_line)" ;;
    esac
    echo "$schedule"
}

# Export Database Function
function export_database() {
    echo -e "\033[33mChecking database configuration...\033[0m"

    if ! extract_db_credentials; then
        return 1
    fi

    if check_marzban_installed; then
        echo -e "\033[31m[ERROR]\033[0m Exporting database is not supported when Marzban is installed due to database being managed by Docker."
        return 1
    fi

    echo -e "\033[33mVerifying database existence...\033[0m"

    if ! mysql -u "$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME;" 2>/dev/null; then
        echo -e "\033[31m[ERROR]\033[0m Database $DB_NAME does not exist or credentials are incorrect."
        return 1
    fi

    BACKUP_FILE="/root/${DB_NAME}_backup.sql"
    echo -e "\033[33mCreating backup at $BACKUP_FILE...\033[0m"

    if ! mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$BACKUP_FILE"; then
        echo -e "\033[31m[ERROR]\033[0m Failed to create database backup."
        return 1
    fi

    echo -e "\033[32mBackup successfully created at $BACKUP_FILE.\033[0m"
}
# Import Database Function
function import_database() {
    echo -e "\033[33mChecking database configuration...\033[0m"

    if ! extract_db_credentials; then
        return 1
    fi

    if check_marzban_installed; then
        echo -e "\033[31m[ERROR]\033[0m Importing database is not supported when Marzban is installed due to database being managed by Docker."
        return 1
    fi

    echo -e "\033[33mVerifying database existence...\033[0m"

    if ! mysql -u "$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME;" 2>/dev/null; then
        echo -e "\033[31m[ERROR]\033[0m Database $DB_NAME does not exist or credentials are incorrect."
        return 1
    fi

    while true; do
        read -p "Enter the path to the backup file [default: /root/${DB_NAME}_backup.sql]: " BACKUP_FILE
        BACKUP_FILE=${BACKUP_FILE:-/root/${DB_NAME}_backup.sql}

        if [[ -f "$BACKUP_FILE" && "$BACKUP_FILE" =~ \.sql$ ]]; then
            break
        else
            echo -e "\033[31m[ERROR]\033[0m Invalid file path or format. Please provide a valid .sql file."
        fi
    done

    echo -e "\033[33mImporting backup from $BACKUP_FILE...\033[0m"

    if ! mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$BACKUP_FILE"; then
        echo -e "\033[31m[ERROR]\033[0m Failed to import database from backup file."
        return 1
    fi

    echo -e "\033[32mDatabase successfully imported from $BACKUP_FILE.\033[0m"
}

# Function for automated backup
function auto_backup() {
    echo -e "\033[36mConfigure Automated Backup\033[0m"

    BOT_DIR="/var/www/html/mirzabotconfig"
    if [ ! -d "$BOT_DIR" ]; then
        echo -e "\033[31m[ERROR]\033[0m Mirza Bot is not installed ($BOT_DIR not found)."
        echo -e "\033[33mExiting...\033[0m"
        sleep 2
        return 1
    fi

    if ! extract_db_credentials; then
        return 1
    fi

    if check_marzban_installed; then
        echo -e "\033[41m[NOTICE]\033[0m \033[33mMarzban detected. Using Marzban-compatible backup.\033[0m"
        BACKUP_SCRIPT="/root/backup_mirza_marzban.sh"
        MYSQL_CONTAINER=$(docker ps -q --filter "name=mysql" --no-trunc)
        if [ -z "$MYSQL_CONTAINER" ]; then
            echo -e "\033[31m[ERROR]\033[0m No running MySQL container found for Marzban."
            return 1
        fi
        cat <<EOF > "$BACKUP_SCRIPT"
#!/bin/bash
BACKUP_FILE="/root/\${DB_NAME}_\$(date +\"%Y%m%d_%H%M%S\").sql"
docker exec $MYSQL_CONTAINER mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "\$BACKUP_FILE"
if [ \$? -eq 0 ]; then
    curl -F document=@"\$BACKUP_FILE" "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_CHAT_ID"
    rm "\$BACKUP_FILE"
else
    echo -e "\033[31m[ERROR]\033[0m Failed to create Marzban database backup."
fi
EOF
    else
        echo -e "\033[33mUsing standard backup.\033[0m"
        BACKUP_SCRIPT="/root/mirza_backup.sh"
        if ! mysql -u "$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME;" 2>/dev/null; then
            echo -e "\033[31m[ERROR]\033[0m Database $DB_NAME does not exist or credentials are incorrect."
            return 1
        fi
        cat <<EOF > "$BACKUP_SCRIPT"
#!/bin/bash
BACKUP_FILE="/root/\${DB_NAME}_\$(date +\"%Y%m%d_%H%M%S\").sql"
mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "\$BACKUP_FILE"
if [ \$? -eq 0 ]; then
    curl -F document=@"\$BACKUP_FILE" "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_CHAT_ID"
    rm "\$BACKUP_FILE"
else
    echo -e "\033[31m[ERROR]\033[0m Failed to create database backup."
fi
EOF
    fi

    chmod +x "$BACKUP_SCRIPT"

    CURRENT_CRON=$(crontab -l 2>/dev/null | grep "$BACKUP_SCRIPT" | grep -v "^#")
    if [ -n "$CURRENT_CRON" ]; then
        SCHEDULE=$(translate_cron "$CURRENT_CRON")
        echo -e "\033[33mCurrent Backup Schedule:\033[0m $SCHEDULE"
    else
        echo -e "\033[33mNo active backup schedule found.\033[0m"
    fi

    echo -e "\033[36m1) Every Minute\033[0m"
    echo -e "\033[36m2) Every Hour\033[0m"
    echo -e "\033[36m3) Every Day\033[0m"
    echo -e "\033[36m4) Every Week\033[0m"
    echo -e "\033[36m5) Disable Backup\033[0m"
    echo -e "\033[36m6) Back to Menu\033[0m"
    echo ""
    read -p "Select an option [1-6]: " backup_option

    update_cron() {
        local cron_line="$1"
        if [ -n "$CURRENT_CRON" ]; then
            crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT" | crontab - && {
                echo -e "\033[92mRemoved previous backup schedule.\033[0m"
            } || {
                echo -e "\033[31mFailed to remove existing cron.\033[0m"
            }
        fi
        if [ -n "$cron_line" ]; then
            (crontab -l 2>/dev/null; echo "$cron_line") | crontab - && {
                echo -e "\033[92mBackup scheduled: $(translate_cron "$cron_line")\033[0m"
                bash "$BACKUP_SCRIPT" &>/dev/null &
            } || {
                echo -e "\033[31mFailed to schedule backup.\033[0m"
            }
        fi
    }

    case $backup_option in
        1) update_cron "* * * * * bash $BACKUP_SCRIPT" ;;
        2) update_cron "0 * * * * bash $BACKUP_SCRIPT" ;;
        3) update_cron "0 0 * * * bash $BACKUP_SCRIPT" ;;
        4) update_cron "0 0 * * 0 bash $BACKUP_SCRIPT" ;;
        5)
            if [ -n "$CURRENT_CRON" ]; then
                crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT" | crontab - && {
                    echo -e "\033[92mAutomated backup disabled.\033[0m"
                } || {
                    echo -e "\033[31mFailed to disable backup.\033[0m"
                }
            else
                echo -e "\033[93mNo backup schedule to disable.\033[0m"
            fi
            ;;
        6) show_menu ;;
        *)
            echo -e "\033[31mInvalid option. Please try again.\033[0m"
            auto_backup
            ;;
    esac
}

# Function to renew SSL certificates
function renew_ssl() {
    echo -e "\033[33mStarting SSL renewal process...\033[0m"

    if ! command -v certbot &>/dev/null; then
        echo -e "\033[31m[ERROR]\033[0m Certbot is not installed. Please install Certbot to proceed."
        return 1
    fi

    # Stop nginx to free port 80
    echo -e "\033[33mStopping nginx...\033[0m"
    sudo systemctl stop nginx || {
        echo -e "\033[31m[ERROR]\033[0m Failed to stop nginx. Exiting..."
        return 1
    }

    # Renew SSL certificates
    if sudo certbot renew; then
        echo -e "\033[32mSSL certificates successfully renewed.\033[0m"
    else
        echo -e "\033[31m[ERROR]\033[0m SSL renewal failed. Please check Certbot logs for more details."
        sudo systemctl start nginx
        return 1
    fi

    # Restart nginx
    echo -e "\033[33mRestarting nginx...\033[0m"
    sudo systemctl restart nginx || {
        echo -e "\033[31m[WARNING]\033[0m Failed to restart nginx. Please check manually."
    }
}

# Function to Manage Additional Bots
function manage_additional_bots() {
    if [ ! -d "/var/www/html/mirzabotconfig" ]; then
        echo -e "\033[31m[ERROR]\033[0m The main Mirza Bot is not installed (/var/www/html/mirzabotconfig not found)."
        echo -e "\033[33mYou are not allowed to use this section without the main bot installed. Exiting...\033[0m"
        sleep 2
        exit 1
    fi

    if check_marzban_installed; then
        echo -e "\033[31m[ERROR]\033[0m Additional bot management is not available when Marzban is installed."
        echo -e "\033[33mExiting script...\033[0m"
        sleep 2
        exit 1
    fi

    echo -e "\033[36m1) Install Additional Bot\033[0m"
    echo -e "\033[36m2) Update Additional Bot\033[0m"
    echo -e "\033[36m3) Remove Additional Bot\033[0m"
    echo -e "\033[36m4) Export Additional Bot Database\033[0m"
    echo -e "\033[36m5) Import Additional Bot Database\033[0m"
    echo -e "\033[36m6) Configure Automated Backup for Additional Bot\033[0m"
    echo -e "\033[36m7) Back to Main Menu\033[0m"
    echo ""
    read -p "Select an option [1-7]: " sub_option
    case $sub_option in
        1) install_additional_bot ;;
        2) update_additional_bot ;;
        3) remove_additional_bot ;;
        4) export_additional_bot_database ;;
        5) import_additional_bot_database ;;
        6) configure_backup_additional_bot ;;
        7) show_menu ;;
        *)
            echo -e "\033[31mInvalid option. Please try again.\033[0m"
            manage_additional_bots
            ;;
    esac
}

function change_domain() {
    local new_domain
    while [[ ! "$new_domain" =~ ^[a-zA-Z0-9.-]+$ ]]; do
        read -p "Enter new domain: " new_domain
        [[ ! "$new_domain" =~ ^[a-zA-Z0-9.-]+$ ]] && echo -e "\033[31mInvalid domain format\033[0m"
    done

    echo -e "\033[33mStopping nginx to configure SSL...\033[0m"
    if ! sudo systemctl stop nginx; then
        echo -e "\033[31m[ERROR] Failed to stop nginx!\033[0m"
        return 1
    fi

    echo -e "\033[33mConfiguring SSL for new domain...\033[0m"
    if ! sudo certbot certonly --standalone --agree-tos --preferred-challenges http -d "$new_domain"; then
        echo -e "\033[31m[ERROR] SSL configuration failed!\033[0m"
        echo -e "\033[33mCleaning up...\033[0m"
        sudo certbot delete --cert-name "$new_domain" 2>/dev/null
        echo -e "\033[33mRestarting nginx after cleanup...\033[0m"
        sudo systemctl start nginx || echo -e "\033[31m[ERROR] Failed to restart nginx!\033[0m"
        return 1
    fi

    CONFIG_FILE="/var/www/html/mirzabotconfig/config.php"
    BOT_DIR="/var/www/html/mirzabotconfig"

    # Reconfigure nginx for the new domain
    configure_nginx_bot "$new_domain" "$BOT_DIR"

    echo -e "\033[33mRestarting nginx after SSL configuration...\033[0m"
    if ! sudo systemctl start nginx; then
        echo -e "\033[31m[ERROR] Failed to restart nginx!\033[0m"
        return 1
    fi

    if [ -f "$CONFIG_FILE" ]; then
        sudo cp "$CONFIG_FILE" "$CONFIG_FILE.$(date +%s).bak"

        sudo sed -i "s/\$domainhosts = '.*\/mirzabotconfig';/\$domainhosts = '${new_domain}\/mirzabotconfig';/" "$CONFIG_FILE"

        NEW_SECRET=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')
        sudo sed -i "s/\$secrettoken = '.*';/\$secrettoken = '${NEW_SECRET%%}';/" "$CONFIG_FILE"

        BOT_TOKEN=$(awk -F"'" '/\$APIKEY/{print $2}' "$CONFIG_FILE")
        curl -s -o /dev/null -F "url=https://${new_domain}/mirzabotconfig/index.php" \
             -F "secret_token=${NEW_SECRET}" \
             "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook" || {
            echo -e "\033[33m[WARNING] Webhook update failed\033[0m"
        }
    else
        echo -e "\033[31m[CRITICAL] Config file missing!\033[0m"
        return 1
    fi

    if curl -sI "https://${new_domain}" | grep -q "200"; then
        echo -e "\033[32mDomain successfully migrated to ${new_domain}\033[0m"
    else
        echo -e "\033[31m[WARNING] Final verification failed!\033[0m"
        echo -e "\033[33mPlease check:\033[0m"
        echo -e "1. DNS settings for ${new_domain}"
        echo -e "2. nginx configuration"
        echo -e "3. Firewall settings"
        return 1
    fi
}

# Function for Installing Additional Bot
function install_additional_bot() {
    clear
    echo -e "\033[33mStarting Additional Bot Installation...\033[0m"

    ROOT_CREDENTIALS_FILE="/root/confmirza/dbrootmirza.txt"
    if [[ ! -f "$ROOT_CREDENTIALS_FILE" ]]; then
        echo -e "\033[31mError: Root credentials file not found at $ROOT_CREDENTIALS_FILE.\033[0m"
        echo -ne "\033[36mPlease enter the root MySQL password: \033[0m"
        read -s ROOT_PASS
        echo
        ROOT_USER="root"
    else
        ROOT_USER=$(grep '\$user =' "$ROOT_CREDENTIALS_FILE" | awk -F"'" '{print $2}')
        ROOT_PASS=$(grep '\$pass =' "$ROOT_CREDENTIALS_FILE" | awk -F"'" '{print $2}')
        if [[ -z "$ROOT_USER" || -z "$ROOT_PASS" ]]; then
            echo -e "\033[31mError: Could not extract root credentials from file.\033[0m"
            return 1
        fi
    fi

    while true; do
        echo -ne "\033[36mEnter the domain for the additional bot: \033[0m"
        read DOMAIN_NAME
        if [[ "$DOMAIN_NAME" =~ ^[a-zA-Z0-9.-]+$ ]]; then
            break
        else
            echo -e "\033[31mInvalid domain format. Please try again.\033[0m"
        fi
    done

    # Stop nginx to free port 80 for certbot
    echo -e "\033[33mStopping nginx to free port 80...\033[0m"
    sudo systemctl stop nginx

    # Obtain SSL Certificate
    echo -e "\033[33mObtaining SSL certificate...\033[0m"
    sudo certbot certonly --standalone --agree-tos --preferred-challenges http -d "$DOMAIN_NAME" || {
        echo -e "\033[31mError obtaining SSL certificate.\033[0m"
        return 1
    }

    # Restart nginx
    echo -e "\033[33mRestarting nginx...\033[0m"
    sudo systemctl start nginx

    while true; do
        echo -ne "\033[36mEnter the bot name: \033[0m"
        read BOT_NAME
        if [[ "$BOT_NAME" =~ ^[a-zA-Z0-9_-]+$ && ! -d "/var/www/html/$BOT_NAME" ]]; then
            break
        else
            echo -e "\033[31mInvalid or duplicate bot name. Please try again.\033[0m"
        fi
    done

    BOT_DIR="/var/www/html/$BOT_NAME"
    echo -e "\033[33mDownloading bot source code...\033[0m"
    ZIP_URL=$(curl -s https://api.github.com/repos/Liwyd/botmirzapanel/releases/latest | grep "zipball_url" | cut -d '"' -f 4)
    TEMP_DIR="/tmp/mirzabot_additional"
    mkdir -p "$TEMP_DIR"
    wget -O "$TEMP_DIR/bot.zip" "$ZIP_URL" || {
        echo -e "\033[31mError: Failed to download bot files.\033[0m"
        return 1
    }
    unzip "$TEMP_DIR/bot.zip" -d "$TEMP_DIR"
    EXTRACTED_DIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d)
    sudo mkdir -p "$BOT_DIR"
    sudo mv "$EXTRACTED_DIR"/* "$BOT_DIR"
    rm -rf "$TEMP_DIR"

    while true; do
        echo -ne "\033[36mEnter the bot token: \033[0m"
        read BOT_TOKEN
        if [[ "$BOT_TOKEN" =~ ^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$ ]]; then
            break
        else
            echo -e "\033[31mInvalid bot token format. Please try again.\033[0m"
        fi
    done

    while true; do
        echo -ne "\033[36mEnter the chat ID: \033[0m"
        read CHAT_ID
        if [[ "$CHAT_ID" =~ ^-?[0-9]+$ ]]; then
            break
        else
            echo -e "\033[31mInvalid chat ID format. Please try again.\033[0m"
        fi
    done

    DB_NAME="mirzabot_$BOT_NAME"
    DB_USERNAME="$DB_NAME"
    DEFAULT_PASSWORD=$(openssl rand -base64 10 | tr -dc 'a-zA-Z0-9' | cut -c1-8)
    echo -ne "\033[36mEnter the database password (default: $DEFAULT_PASSWORD): \033[0m"
    read DB_PASSWORD
    DB_PASSWORD=${DB_PASSWORD:-$DEFAULT_PASSWORD}

    echo -e "\033[33mCreating database and user...\033[0m"
    sudo mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "CREATE DATABASE $DB_NAME;" || {
        echo -e "\033[31mError: Failed to create database.\033[0m"
        return 1
    }
    sudo mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "CREATE USER '$DB_USERNAME'@'localhost' IDENTIFIED BY '$DB_PASSWORD';" || {
        echo -e "\033[31mError: Failed to create database user.\033[0m"
        return 1
    }
    sudo mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USERNAME'@'localhost';" || {
        echo -e "\033[31mError: Failed to grant privileges to user.\033[0m"
        return 1
    }
    sudo mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "FLUSH PRIVILEGES;"

    # Configure nginx for additional bot
    BOT_DIR="/var/www/html/$BOT_NAME"
    NGINX_CONF="/etc/nginx/sites-available/$DOMAIN_NAME.conf"
    sudo bash -c "cat > $NGINX_CONF <<NGINXEOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN_NAME;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    root $BOT_DIR;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_pass unix:/var/run/php/php$(detect_php_version)-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINXEOF"
    sudo ln -sf "$NGINX_CONF" "/etc/nginx/sites-enabled/$DOMAIN_NAME.conf"

    # Configure the Bot
    CONFIG_FILE="$BOT_DIR/config.php"
    echo -e "\033[33mSaving bot configuration...\033[0m"
    cat <<EOF > "$CONFIG_FILE"
<?php
\$APIKEY = '$BOT_TOKEN';
\$usernamedb = '$DB_USERNAME';
\$passworddb = '$DB_PASSWORD';
\$dbname = '$DB_NAME';
\$domainhosts = '$DOMAIN_NAME/$BOT_NAME';
\$adminnumber = '$CHAT_ID';
\$usernamebot = '$BOT_NAME';
\$connect = mysqli_connect('localhost', \$usernamedb, \$passworddb, \$dbname);
if (\$connect->connect_error) {
    die('Database connection failed: ' . \$connect->connect_error);
}
mysqli_set_charset(\$connect, 'utf8mb4');
\$options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES   => false,
];
\$dsn = "mysql:host=localhost;dbname=\$dbname;charset=utf8mb4";
try {
     \$pdo = new PDO(\$dsn, \$usernamedb, \$passworddb, \$options);
} catch (\PDOException \$e) {
     throw new \PDOException(\$e->getMessage(), (int)\$e->getCode());
}
?>
EOF

    sleep 1

    sudo chown -R www-data:www-data "$BOT_DIR"
    sudo chmod -R 755 "$BOT_DIR"

    sudo nginx -t && sudo systemctl reload nginx

    # Set Webhook
    echo -e "\033[33mSetting webhook for bot...\033[0m"
    curl -F "url=https://$DOMAIN_NAME/$BOT_NAME/index.php" "https://api.telegram.org/bot$BOT_TOKEN/setWebhook" || {
        echo -e "\033[31mError: Failed to set webhook for bot.\033[0m"
        return 1
    }

    # Send Installation Confirmation
    MESSAGE="The bot is installed! for start bot send comment /start"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" -d chat_id="${CHAT_ID}" -d text="$MESSAGE" || {
        echo -e "\033[31mError: Failed to send message to Telegram.\033[0m"
        return 1
    }

    # Execute table creation script
    TABLE_SETUP_URL="https://${DOMAIN_NAME}/$BOT_NAME/table.php"
    echo -e "\033[33mSetting up database tables...\033[0m"
    curl -s "$TABLE_SETUP_URL" || {
        echo -e "\033[31mError: Failed to execute table creation script at $TABLE_SETUP_URL.\033[0m"
        return 1
    }

    # Output Bot Information
    echo -e "\033[32mBot installed successfully!\033[0m"
    echo -e "\033[102mDomain Bot: https://$DOMAIN_NAME\033[0m"
    echo -e "\033[33mDatabase name: \033[36m$DB_NAME\033[0m"
    echo -e "\033[33mDatabase username: \033[36m$DB_USERNAME\033[0m"
    echo -e "\033[33mDatabase password: \033[36m$DB_PASSWORD\033[0m"
    echo -e "\033[33mManage DB via CLI: \033[36mmysql -u $DB_USERNAME -p $DB_NAME\033[0m"
}

# Function to Update Additional Bot
function update_additional_bot() {
    clear
    echo -e "\033[36mAvailable Bots:\033[0m"

    BOT_DIRS=$(ls -d /var/www/html/*/ 2>/dev/null | grep -v "/var/www/html/mirzabotconfig" | xargs -n 1 basename)

    if [ -z "$BOT_DIRS" ]; then
        echo -e "\033[31mNo additional bots found in /var/www/html.\033[0m"
        return 1
    fi

    echo "$BOT_DIRS" | nl -w 2 -s ") "

    echo -ne "\033[36mSelect a bot by name: \033[0m"
    read SELECTED_BOT

    if [[ ! "$BOT_DIRS" =~ (^|[[:space:]])$SELECTED_BOT($|[[:space:]]) ]]; then
        echo -e "\033[31mInvalid bot name.\033[0m"
        return 1
    fi

    BOT_PATH="/var/www/html/$SELECTED_BOT"
    CONFIG_PATH="$BOT_PATH/config.php"
    TEMP_CONFIG_PATH="/root/${SELECTED_BOT}_config.php"

    echo -e "\033[33mUpdating $SELECTED_BOT...\033[0m"

    if [ -f "$CONFIG_PATH" ]; then
        mv "$CONFIG_PATH" "$TEMP_CONFIG_PATH" || {
            echo -e "\033[31mFailed to backup config.php. Exiting...\033[0m"
            return 1
        }
    else
        echo -e "\033[31mconfig.php not found in $BOT_PATH. Exiting...\033[0m"
        return 1
    fi

    if ! rm -rf "$BOT_PATH"; then
        echo -e "\033[31mFailed to remove old bot directory. Exiting...\033[0m"
        return 1
    fi

    ZIP_URL=$(curl -s https://api.github.com/repos/Liwyd/botmirzapanel/releases/latest | grep "zipball_url" | cut -d '"' -f 4)
    TEMP_DIR="/tmp/mirzabot_additional_update"
    mkdir -p "$TEMP_DIR"
    wget -O "$TEMP_DIR/bot.zip" "$ZIP_URL" || {
        echo -e "\033[31mFailed to download update. Exiting...\033[0m"
        return 1
    }
    unzip "$TEMP_DIR/bot.zip" -d "$TEMP_DIR"
    EXTRACTED_DIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d)
    sudo mv "$EXTRACTED_DIR"/* "$BOT_PATH"
    rm -rf "$TEMP_DIR"

    if ! mv "$TEMP_CONFIG_PATH" "$CONFIG_PATH"; then
        echo -e "\033[31mFailed to restore config.php. Exiting...\033[0m"
        return 1
    fi

    sudo chown -R www-data:www-data "$BOT_PATH"
    sudo chmod -R 755 "$BOT_PATH"

    URL=$(grep '\$domainhosts' "$CONFIG_PATH" | cut -d"'" -f2)
    if [ -z "$URL" ]; then
        echo -e "\033[31mFailed to extract domain URL from config.php. Exiting...\033[0m"
        return 1
    fi

    if ! curl -s "https://$URL/table.php"; then
        echo -e "\033[31mFailed to execute table.php. Exiting...\033[0m"
        return 1
    fi

    echo -e "\033[32m$SELECTED_BOT has been successfully updated!\033[0m"
}

# Function to Remove Additional Bot
function remove_additional_bot() {
    clear
    echo -e "\033[36mAvailable Bots:\033[0m"

    BOT_DIRS=$(ls -d /var/www/html/*/ 2>/dev/null | grep -v "/var/www/html/mirzabotconfig" | xargs -n 1 basename)

    if [ -z "$BOT_DIRS" ]; then
        echo -e "\033[31mNo additional bots found in /var/www/html.\033[0m"
        return 1
    fi

    echo "$BOT_DIRS" | nl -w 2 -s ") "

    echo -ne "\033[36mSelect a bot by name: \033[0m"
    read SELECTED_BOT

    if [[ ! "$BOT_DIRS" =~ (^|[[:space:]])$SELECTED_BOT($|[[:space:]]) ]]; then
        echo -e "\033[31mInvalid bot name.\033[0m"
        return 1
    fi

    BOT_PATH="/var/www/html/$SELECTED_BOT"
    CONFIG_PATH="$BOT_PATH/config.php"

    echo -ne "\033[36mAre you sure you want to remove $SELECTED_BOT? (yes/no): \033[0m"
    read CONFIRM_REMOVE
    if [[ "$CONFIRM_REMOVE" != "yes" ]]; then
        echo -e "\033[33mAborted.\033[0m"
        return 1
    fi

    echo -ne "\033[36mHave you backed up the database? (yes/no): \033[0m"
    read BACKUP_CONFIRM
    if [[ "$BACKUP_CONFIRM" != "yes" ]]; then
        echo -e "\033[33mAborted. Please backup the database first.\033[0m"
        return 1
    fi

    ROOT_CREDENTIALS_FILE="/root/confmirza/dbrootmirza.txt"
    if [ -f "$ROOT_CREDENTIALS_FILE" ]; then
        ROOT_USER=$(grep '\$user =' "$ROOT_CREDENTIALS_FILE" | awk -F"'" '{print $2}')
        ROOT_PASS=$(grep '\$pass =' "$ROOT_CREDENTIALS_FILE" | awk -F"'" '{print $2}')
    else
        echo -ne "\033[36mRoot credentials file not found. Enter MySQL root password: \033[0m"
        read -s ROOT_PASS
        echo
        ROOT_USER="root"
    fi

    DOMAIN_NAME=$(grep '\$domainhosts' "$CONFIG_PATH" | cut -d"'" -f2 | cut -d"/" -f1 | cut -d":" -f1)
    DB_NAME=$(awk -F"'" '/\$dbname = / {print $2}' "$CONFIG_PATH")
    DB_USER=$(awk -F"'" '/\$usernamedb = / {print $2}' "$CONFIG_PATH")

    # Delete database
    echo -e "\033[33mRemoving database $DB_NAME...\033[0m"
    mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" 2>/tmp/db_remove_error.log
    if [ $? -eq 0 ]; then
        echo -e "\033[32mDatabase $DB_NAME removed successfully.\033[0m"
    else
        echo -e "\033[31mFailed to remove database $DB_NAME.\033[0m"
    fi

    # Delete user
    echo -e "\033[33mRemoving user $DB_USER...\033[0m"
    mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "DROP USER IF EXISTS '$DB_USER'@'localhost';" 2>/tmp/user_remove_error.log
    if [ $? -eq 0 ]; then
        echo -e "\033[32mUser $DB_USER removed successfully.\033[0m"
    else
        echo -e "\033[31mFailed to remove user $DB_USER.\033[0m"
    fi

    # Remove bot directory
    echo -e "\033[33mRemoving bot directory $BOT_PATH...\033[0m"
    if ! rm -rf "$BOT_PATH"; then
        echo -e "\033[31mFailed to remove bot directory.\033[0m"
        return 1
    fi

    # Remove nginx configuration
    NGINX_CONF="/etc/nginx/sites-available/$DOMAIN_NAME.conf"
    if [ -f "$NGINX_CONF" ]; then
        echo -e "\033[33mRemoving nginx configuration for $DOMAIN_NAME...\033[0m"
        sudo rm -f "$NGINX_CONF"
        sudo rm -f "/etc/nginx/sites-enabled/$DOMAIN_NAME.conf"
        sudo nginx -t && sudo systemctl reload nginx
    else
        echo -e "\033[31mnginx configuration for $DOMAIN_NAME not found.\033[0m"
    fi

    echo -e "\033[32m$SELECTED_BOT has been successfully removed.\033[0m"
}

#Function to export additional bot database
function export_additional_bot_database() {
    clear
    echo -e "\033[36mAvailable Bots:\033[0m"

    BOT_DIRS=$(ls -d /var/www/html/*/ 2>/dev/null | grep -v "/var/www/html/mirzabotconfig" | xargs -n 1 basename)

    if [ -z "$BOT_DIRS" ]; then
        echo -e "\033[31mNo additional bots found in /var/www/html.\033[0m"
        return 1
    fi

    echo "$BOT_DIRS" | nl -w 2 -s ") "

    echo -ne "\033[36mEnter the bot name: \033[0m"
    read SELECTED_BOT

    if [[ ! "$BOT_DIRS" =~ (^|[[:space:]])$SELECTED_BOT($|[[:space:]]) ]]; then
        echo -e "\033[31mInvalid bot name.\033[0m"
        return 1
    fi

    BOT_PATH="/var/www/html/$SELECTED_BOT"
    CONFIG_PATH="$BOT_PATH/config.php"

    if [ ! -f "$CONFIG_PATH" ]; then
        echo -e "\033[31mconfig.php not found for $SELECTED_BOT.\033[0m"
        return 1
    fi

    ROOT_CREDENTIALS_FILE="/root/confmirza/dbrootmirza.txt"
    if [ -f "$ROOT_CREDENTIALS_FILE" ]; then
        ROOT_USER=$(grep '\$user =' "$ROOT_CREDENTIALS_FILE" | awk -F"'" '{print $2}')
        ROOT_PASS=$(grep '\$pass =' "$ROOT_CREDENTIALS_FILE" | awk -F"'" '{print $2}')
    else
        echo -e "\033[31mRoot credentials file not found.\033[0m"
        echo -ne "\033[36mEnter MySQL root password: \033[0m"
        read -s ROOT_PASS
        echo

        if [ -z "$ROOT_PASS" ]; then
            echo -e "\033[31mPassword cannot be empty. Exiting...\033[0m"
            return 1
        fi

        ROOT_USER="root"

        echo "SELECT 1" | mysql -u "$ROOT_USER" -p"$ROOT_PASS" 2>/dev/null
        if [ $? -ne 0 ]; then
            echo -e "\033[31mInvalid root credentials. Exiting...\033[0m"
            return 1
        fi
    fi

    DB_USER=$(grep '^\$usernamedb' "$CONFIG_PATH" | awk -F"'" '{print $2}')
    DB_PASS=$(grep '^\$passworddb' "$CONFIG_PATH" | awk -F"'" '{print $2}')
    DB_NAME=$(grep '^\$dbname' "$CONFIG_PATH" | awk -F"'" '{print $2}')

    if [ -z "$DB_USER" ] || [ -z "$DB_PASS" ] || [ -z "$DB_NAME" ]; then
        echo -e "\033[31m[ERROR]\033[0m Failed to extract database credentials from $CONFIG_PATH."
        return 1
    fi

    echo -e "\033[33mVerifying database existence...\033[0m"
    if ! mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "USE $DB_NAME;" 2>/dev/null; then
        echo -e "\033[31m[ERROR]\033[0m Database $DB_NAME does not exist or credentials are incorrect."
        return 1
    fi

    BACKUP_FILE="/root/${DB_NAME}_backup.sql"
    echo -e "\033[33mCreating backup at $BACKUP_FILE...\033[0m"
    if ! mysqldump -u "$ROOT_USER" -p"$ROOT_PASS" "$DB_NAME" > "$BACKUP_FILE"; then
        echo -e "\033[31m[ERROR]\033[0m Failed to create database backup."
        return 1
    fi

    echo -e "\033[32mBackup successfully created at $BACKUP_FILE.\033[0m"
}

#function to import additional bot database
function import_additional_bot_database() {
    clear
    echo -e "\033[36mStarting Import Database Process...\033[0m"

    ROOT_CREDENTIALS_FILE="/root/confmirza/dbrootmirza.txt"
    if [ -f "$ROOT_CREDENTIALS_FILE" ]; then
        ROOT_USER=$(grep '\$user =' "$ROOT_CREDENTIALS_FILE" | awk -F"'" '{print $2}')
        ROOT_PASS=$(grep '\$pass =' "$ROOT_CREDENTIALS_FILE" | awk -F"'" '{print $2}')
    else
        echo -e "\033[31mRoot credentials file not found.\033[0m"
        echo -ne "\033[36mEnter MySQL root password: \033[0m"
        read -s ROOT_PASS
        echo

        if [ -z "$ROOT_PASS" ]; then
            echo -e "\033[31mPassword cannot be empty. Exiting...\033[0m"
            return 1
        fi

        ROOT_USER="root"

        echo "SELECT 1" | mysql -u "$ROOT_USER" -p"$ROOT_PASS" 2>/dev/null
        if [ $? -ne 0 ]; then
            echo -e "\033[31mInvalid root credentials. Exiting...\033[0m"
            return 1
        fi
    fi

    SQL_FILES=$(find /root -maxdepth 1 -type f -name "*.sql")
    if [ -z "$SQL_FILES" ]; then
        echo -e "\033[31mNo .sql files found in /root. Please provide a valid .sql file.\033[0m"
        return 1
    fi

    echo -e "\033[36mAvailable .sql files:\033[0m"
    echo "$SQL_FILES" | nl -w 2 -s ") "

    echo -ne "\033[36mEnter the number of the file or provide a full path: \033[0m"
    read FILE_SELECTION

    if [[ "$FILE_SELECTION" =~ ^[0-9]+$ ]]; then
        SELECTED_FILE=$(echo "$SQL_FILES" | sed -n "${FILE_SELECTION}p")
    else
        SELECTED_FILE="$FILE_SELECTION"
    fi

    if [ ! -f "$SELECTED_FILE" ]; then
        echo -e "\033[31mSelected file does not exist. Exiting...\033[0m"
        return 1
    fi

    echo -e "\033[36mAvailable Bots:\033[0m"
    BOT_DIRS=$(ls -d /var/www/html/*/ 2>/dev/null | grep -v "/var/www/html/mirzabotconfig" | xargs -n 1 basename)

    if [ -z "$BOT_DIRS" ]; then
        echo -e "\033[31mNo additional bots found in /var/www/html.\033[0m"
        return 1
    fi

    echo "$BOT_DIRS" | nl -w 2 -s ") "

    echo -ne "\033[36mSelect a bot by name: \033[0m"
    read SELECTED_BOT

    if [[ ! "$BOT_DIRS" =~ (^|[[:space:]])$SELECTED_BOT($|[[:space:]]) ]]; then
        echo -e "\033[31mInvalid bot name.\033[0m"
        return 1
    fi

    BOT_PATH="/var/www/html/$SELECTED_BOT"
    CONFIG_PATH="$BOT_PATH/config.php"

    if [ ! -f "$CONFIG_PATH" ]; then
        echo -e "\033[31mconfig.php not found for $SELECTED_BOT.\033[0m"
        return 1
    fi

    DB_USER=$(grep '^\$usernamedb' "$CONFIG_PATH" | awk -F"'" '{print $2}')
    DB_PASS=$(grep '^\$passworddb' "$CONFIG_PATH" | awk -F"'" '{print $2}')
    DB_NAME=$(grep '^\$dbname' "$CONFIG_PATH" | awk -F"'" '{print $2}')

    if [ -z "$DB_USER" ] || [ -z "$DB_PASS" ] || [ -z "$DB_NAME" ]; then
        echo -e "\033[31m[ERROR]\033[0m Failed to extract database credentials from $CONFIG_PATH."
        return 1
    fi

    echo -e "\033[33mVerifying database existence...\033[0m"
    if ! mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "USE $DB_NAME;" 2>/dev/null; then
        echo -e "\033[31m[ERROR]\033[0m Database $DB_NAME does not exist or credentials are incorrect."
        return 1
    fi

    echo -e "\033[33mImporting database from $SELECTED_FILE into $DB_NAME...\033[0m"
    if ! mysql -u "$ROOT_USER" -p"$ROOT_PASS" "$DB_NAME" < "$SELECTED_FILE"; then
        echo -e "\033[31m[ERROR]\033[0m Failed to import database."
        return 1
    fi

    echo -e "\033[32mDatabase successfully imported from $SELECTED_FILE into $DB_NAME.\033[0m"
}
#function to configure backup additional bot
function configure_backup_additional_bot() {
    clear
    echo -e "\033[36mConfiguring Automated Backup for Additional Bot...\033[0m"

    echo -e "\033[36mAvailable Bots:\033[0m"
    BOT_DIRS=$(ls -d /var/www/html/*/ 2>/dev/null | grep -v "/var/www/html/mirzabotconfig" | xargs -n 1 basename)

    if [ -z "$BOT_DIRS" ]; then
        echo -e "\033[31mNo additional bots found in /var/www/html.\033[0m"
        return 1
    fi

    echo "$BOT_DIRS" | nl -w 2 -s ") "

    echo -ne "\033[36mSelect a bot by name: \033[0m"
    read SELECTED_BOT

    if [[ ! "$BOT_DIRS" =~ (^|[[:space:]])$SELECTED_BOT($|[[:space:]]) ]]; then
        echo -e "\033[31mInvalid bot name.\033[0m"
        return 1
    fi

    BOT_PATH="/var/www/html/$SELECTED_BOT"
    CONFIG_PATH="$BOT_PATH/config.php"

    if [ ! -f "$CONFIG_PATH" ]; then
        echo -e "\033[31mconfig.php not found for $SELECTED_BOT.\033[0m"
        return 1
    fi

    DB_NAME=$(grep '^\$dbname' "$CONFIG_PATH" | awk -F"'" '{print $2}')
    DB_USER=$(grep '^\$usernamedb' "$CONFIG_PATH" | awk -F"'" '{print $2}')
    DB_PASS=$(grep '^\$passworddb' "$CONFIG_PATH" | awk -F"'" '{print $2}')
    TELEGRAM_TOKEN=$(grep '^\$APIKEY' "$CONFIG_PATH" | awk -F"'" '{print $2}')
    TELEGRAM_CHAT_ID=$(grep '^\$adminnumber' "$CONFIG_PATH" | awk -F"'" '{print $2}')

    if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
        echo -e "\033[31m[ERROR]\033[0m Failed to extract database credentials from $CONFIG_PATH."
        return 1
    fi

    if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        echo -e "\033[31m[ERROR]\033[0m Telegram token or chat ID not found in $CONFIG_PATH."
        return 1
    fi

    while true; do
        echo -e "\033[36mChoose backup frequency:\033[0m"
        echo -e "\033[36m1) Every minute\033[0m"
        echo -e "\033[36m2) Every hour\033[0m"
        echo -e "\033[36m3) Every day\033[0m"
        read -p "Enter your choice (1-3): " frequency

        case $frequency in
            1) cron_time="* * * * *" ; break ;;
            2) cron_time="0 * * * *" ; break ;;
            3) cron_time="0 0 * * *" ; break ;;
            *)
                echo -e "\033[31mInvalid option. Please try again.\033[0m"
                ;;
        esac
    done

    BACKUP_SCRIPT="/root/${SELECTED_BOT}_auto_backup.sh"
    cat <<EOF > "$BACKUP_SCRIPT"
#!/bin/bash

DB_NAME="$DB_NAME"
DB_USER="$DB_USER"
DB_PASS="$DB_PASS"
TELEGRAM_TOKEN="$TELEGRAM_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"

BACKUP_FILE="/root/\${DB_NAME}_\$(date +"%Y%m%d_%H%M%S").sql"
if mysqldump -u "\$DB_USER" -p"\$DB_PASS" "\$DB_NAME" > "\$BACKUP_FILE"; then
    curl -F document=@"\$BACKUP_FILE" "https://api.telegram.org/bot\$TELEGRAM_TOKEN/sendDocument" -F chat_id="\$TELEGRAM_CHAT_ID"
    rm "\$BACKUP_FILE"
else
    echo -e "\033[31m[ERROR]\033[0m Failed to create database backup."
fi
EOF

    chmod +x "$BACKUP_SCRIPT"

    (crontab -l 2>/dev/null; echo "$cron_time bash $BACKUP_SCRIPT") | crontab -

    echo -e "\033[32mAutomated backup configured successfully for $SELECTED_BOT.\033[0m"
}

# Main Execution
process_arguments() {
    local version=""
    case "$1" in
        -v*)
            version="${1#-v}"
            if [ -n "$version" ]; then
                install_bot "-v" "$version"
            else
                if [ -n "$2" ]; then
                    install_bot "-v" "$2"
                else
                    echo -e "\033[31m[ERROR]\033[0m Please specify a version with -v (e.g., -v 4.11.1)"
                    exit 1
                fi
            fi
            ;;
        -beta)
            install_bot "-beta"
            ;;
        --beta)
            install_bot "-beta"
            ;;
        -update)
            update_bot "$2"
            ;;
        *)
            show_menu
            ;;
    esac
}

process_arguments "$1" "$2"
