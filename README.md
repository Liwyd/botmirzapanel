# Mirza Panel Bot

A Telegram bot for selling VPN proxy subscriptions. Supports multiple panel backends with integrated MIT Panel reseller management.

## Supported Panels

| Panel | Type | Auth |
|-------|------|------|
| Marzban | `marzban` | Username/Password |
| Marzneshin | `marzneshin` | Username/Password |
| 3x-ui | `x-ui_single` | Username/Password |
| Alireza | `alireza` | Username/Password |
| S-ui | `s_ui` | Token |
| WGDashboard | `wgdashboard` | Token |
| MikroTik | `mikrotik` | Username/Password |
| **MIT Panel** | `mit` | Marzban creds + MIT superadmin creds |

## MIT Panel Integration

MIT Panel integration adds reseller traffic management. When a customer purchases a subscription:

1. Bot checks the reseller's available traffic in MIT Panel
2. Creates the VPN user on the underlying Marzban panel
3. Deducts the traffic from the reseller's MIT Panel account
4. Alerts the panel owner if remaining traffic drops below 200 GB

### Adding a MIT Panel

When adding a new panel, select **MIT Panel** and provide:

- Marzban panel URL, admin username, and password (sudo credentials)
- MIT Panel URL, superadmin username, and superadmin password
- MIT Panel `BOT_API_KEY`
- Reseller admin username in MIT Panel

## Requirements

- PHP 7.4+ with cURL, PDO, MySQLi extensions
- MySQL 5.7+ / MariaDB 10.3+
- Web server (Apache/Nginx) with HTTPS
- Telegram Bot API token

## Installation

### Quick Install

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/mirzapanel.git
cd mirzapanel

# Install PHP dependencies
composer install

# Set up the database
# Create a MySQL database and update config.php with your credentials

# Set Telegram webhook
curl "https://api.telegram.org/botYOUR_TOKEN/setWebhook?url=https://YOUR_DOMAIN/index.php"
```

### Manual Install

1. Upload all files to your web server
2. Create a MySQL database
3. Edit `config.php` with your database credentials, bot token, and admin ID
4. Run `composer install` for QR code generation
5. Set the Telegram webhook to `https://YOUR_DOMAIN/index.php`
6. Open the bot in Telegram and send `/start`

### config.php

```php
<?php
$botnumber = "YOUR_BOT_TOKEN";
$adminnumber = "YOUR_TELEGRAM_ID";
$domainhosts = "YOUR_DOMAIN";

// Database
$dbhost = "localhost";
$dbname = "YOUR_DB_NAME";
$dbuser = "YOUR_DB_USER";
$dbpass = "YOUR_DB_PASSWORD";
```

## Features

- Multi-panel support (Marzban, 3x-ui, S-ui, WGDashboard, MikroTik, MIT Panel)
- Product management with categories
- Automated subscription creation and renewal
- Free trial accounts
- Payment integration (Card-to-card, NOWPayments crypto, AqayePardakht)
- QR code subscription links
- Referral/affiliate system
- Discount codes
- Cron jobs for expiration and volume monitoring
- Persian/Farsi UI
- Web-based installer

## Project Structure

```
botmirzapanel/
  index.php          # Main entry point (webhook handler)
  config.php         # Database and bot configuration
  panels.php         # ManagePanel class (panel abstraction)
  marzban.php        # Marzban API client
  mit.php            # MIT Panel API client
  admin.php          # Admin bot commands
  keyboard.php       # Telegram keyboard builders
  text.php           # Persian text strings
  functions.php      # Utility functions
  table.php          # Database schema/migrations
  botapi.php         # Telegram Bot API wrapper
  installer/         # Web-based installer
  cron/              # Scheduled tasks
  payment/           # Payment gateway integrations
  vendor/            # Composer dependencies
```

## License

MIT License
