# Mirza Panel Bot

Telegram bot for selling VPN proxy subscriptions. Supports multiple panel backends with MIT Panel traffic management.

## Install

```bash
bash <(curl -sSL https://raw.githubusercontent.com/Liwyd/botmirzapanel/main/install.sh)
```

One-liner installs: nginx, PHP 8.2 FPM, MySQL, SSL, firewall, and the bot. Interactive menu handles everything.

## Supported Panels

| Panel | Auth |
|-------|------|
| Marzban | Username/Password |
| Marzneshin | Username/Password |
| 3x-ui | Username/Password |
| Alireza | Username/Password |
| S-ui | Token |
| WGDashboard | Token |
| MikroTik | Username/Password |
| MIT Panel | Marzban + MIT superadmin creds |

## MIT Panel

Adds reseller traffic management. On purchase: checks traffic in MIT Panel, creates VPN user on Marzban, deducts traffic, alerts owner if below 200 GB.

## Structure

```
index.php          # Webhook handler
config.php         # DB and bot config
panels.php         # Panel abstraction (ManagePanel)
marzban.php        # Marzban API client
mit.php            # MIT Panel API client
admin.php          # Admin commands
keyboard.php       # Telegram keyboards
text.php           # UI strings
functions.php      # Utilities
table.php          # DB schema
botapi.php         # Telegram Bot API
install.sh         # CLI installer
installer/         # Web-based installer
cron/              # Scheduled tasks
payment/           # Payment gateways
```

## License

MIT
