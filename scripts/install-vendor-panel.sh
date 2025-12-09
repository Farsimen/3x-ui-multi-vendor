#!/bin/bash

# نصب Vendor Web Panel برای 3X-UI Multi-Vendor
# این پنل امکان مشاهده Inbound های مجاز را برای Vendor ها فراهم می‌کند

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════╗
║   3X-UI Vendor Web Panel Installer       ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

# بررسی root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}این اسکریپت باید با دسترسی root اجرا شود${NC}"
   exit 1
fi

echo -e "${YELLOW}[1/5] نصب پیش‌نیازها...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq > /dev/null 2>&1
apt-get install -y -qq nginx php-fpm php-sqlite3 > /dev/null 2>&1
echo -e "${GREEN}✓ پیش‌نیازها نصب شد${NC}"

echo -e "${YELLOW}[2/5] پیکربندی Nginx...${NC}"

# تشخیص نسخه PHP
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
echo -e "${BLUE}→ PHP Version: $PHP_VERSION${NC}"

# پیکربندی Nginx برای PHP
cat > /etc/nginx/sites-available/vendor-panel << EOF
server {
    listen 8080;
    server_name _;
    root /var/www/html;
    index vendor-panel.php;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -sf /etc/nginx/sites-available/vendor-panel /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t > /dev/null 2>&1
systemctl reload nginx
echo -e "${GREEN}✓ Nginx پیکربندی شد${NC}"

echo -e "${YELLOW}[3/5] دانلود Vendor Panel...${NC}"
wget -q https://raw.githubusercontent.com/Farsimen/3x-ui-multi-vendor/main/web/vendor-panel.php -O /var/www/html/vendor-panel.php
chmod 644 /var/www/html/vendor-panel.php
chown www-data:www-data /var/www/html/vendor-panel.php
echo -e "${GREEN}✓ فایل‌ها دانلود شدند${NC}"

echo -e "${YELLOW}[4/5] تنظیم دسترسی دیتابیس...${NC}"
if [[ -f /etc/x-ui/x-ui.db ]]; then
    chmod 644 /etc/x-ui/x-ui.db
    chown www-data:www-data /etc/x-ui/x-ui.db
    echo -e "${GREEN}✓ دسترسی‌ها تنظیم شد${NC}"
else
    echo -e "${RED}✗ دیتابیس 3X-UI یافت نشد!${NC}"
    echo -e "${YELLOW}ابتدا 3X-UI Multi-Vendor را نصب کنید${NC}"
    exit 1
fi

echo -e "${YELLOW}[5/5] پیکربندی فایروال...${NC}"
if command -v ufw > /dev/null 2>&1; then
    ufw allow 8080/tcp > /dev/null 2>&1
    echo -e "${GREEN}✓ پورت 8080 باز شد${NC}"
fi

# دریافت IP سرور
SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || echo "YOUR_SERVER_IP")

# پیدا کردن اطلاعات 3X-UI
if [[ -f /usr/local/x-ui/x-ui ]]; then
    X_UI_PORT=$(sqlite3 /etc/x-ui/x-ui.db "SELECT value FROM settings WHERE key='webPort';" 2>/dev/null || echo "54321")
    X_UI_PATH=$(sqlite3 /etc/x-ui/x-ui.db "SELECT value FROM settings WHERE key='webBasePath';" 2>/dev/null || echo "")
else
    X_UI_PORT="54321"
    X_UI_PATH=""
fi

# بروزرسانی URL پنل اصلی در فایل PHP
sed -i "s|define('PANEL_URL', '.*')|define('PANEL_URL', 'http://${SERVER_IP}:${X_UI_PORT}${X_UI_PATH}')|" /var/www/html/vendor-panel.php

echo ""
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════╗
║     ✅ نصب با موفقیت تکمیل شد!           ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📱 دسترسی به Vendor Panel:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}URL:${NC} http://${SERVER_IP}:8080/vendor-panel.php"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔐 تست لاگین:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# نمایش اولین Vendor
FIRST_VENDOR=$(sqlite3 /etc/x-ui/x-ui.db "SELECT u.username FROM users u JOIN user_roles ur ON u.id = ur.user_id WHERE ur.role='vendor' LIMIT 1;" 2>/dev/null || echo "vendor")

echo -e "${YELLOW}Username:${NC} $FIRST_VENDOR"
echo -e "${YELLOW}Password:${NC} (رمزی که هنگام ساخت تعیین کردید)"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}ℹ️  توضیحات:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}• این پنل فقط Inbound های مجاز Vendor را نمایش می‌دهد${NC}"
echo -e "${CYAN}• برای مدیریت Client ها، از پنل اصلی 3X-UI استفاده کنید${NC}"
echo -e "${CYAN}• Vendor ها فقط می‌توانند Client های Inbound مجاز خود را ببینند${NC}"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🛠️  دستورات مدیریت:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}# ریستارت Nginx${NC}"
echo -e "systemctl restart nginx"
echo ""
echo -e "${CYAN}# مشاهده لاگ Nginx${NC}"
echo -e "tail -f /var/log/nginx/error.log"
echo ""
echo -e "${CYAN}# بررسی وضعیت سرویس‌ها${NC}"
echo -e "systemctl status nginx php${PHP_VERSION}-fpm"
echo ""

echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}        🚀 Enjoy Vendor Panel!              ${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
