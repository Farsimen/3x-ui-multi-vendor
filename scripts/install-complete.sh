#!/bin/bash

# نصب کامل 3X-UI Multi-Vendor با RBAC کامل
# شامل: Database, CLI, Web Panel, API Proxy

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════╗
║  3X-UI Multi-Vendor Complete Installer   ║
║         با پشتیبانی کامل RBAC            ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}این اسکریپت باید با دسترسی root اجرا شود${NC}"
   exit 1
fi

echo -e "${YELLOW}[1/6] نصب پیش‌نیازها...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq > /dev/null 2>&1
apt-get install -y -qq nginx php-fpm php-sqlite3 php-curl sqlite3 apache2-utils > /dev/null 2>&1
echo -e "${GREEN}✓ پیش‌نیازها نصب شد${NC}"

# تشخیص نسخه PHP
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
echo -e "${BLUE}→ PHP Version: $PHP_VERSION${NC}"

# تشخیص پورت 3X-UI
if [[ -f /etc/x-ui/x-ui.db ]]; then
    X_UI_PORT=$(sqlite3 /etc/x-ui/x-ui.db "SELECT value FROM settings WHERE key='webPort';" 2>/dev/null || echo "54321")
    X_UI_PATH=$(sqlite3 /etc/x-ui/x-ui.db "SELECT value FROM settings WHERE key='webBasePath';" 2>/dev/null || echo "")
else
    echo -e "${RED}خطا: 3X-UI نصب نیست!${NC}"
    echo -e "${YELLOW}ابتدا 3X-UI و RBAC را نصب کنید${NC}"
    exit 1
fi

SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || echo "127.0.0.1")

echo -e "${YELLOW}[2/6] دانلود فایل‌ها...${NC}"
cd /tmp
rm -rf 3x-ui-vendor-install
mkdir -p 3x-ui-vendor-install
cd 3x-ui-vendor-install

# دانلود API Proxy
wget -q https://raw.githubusercontent.com/Farsimen/3x-ui-multi-vendor/main/web/api-proxy.php
# دانلود Vendor Panel
wget -q https://raw.githubusercontent.com/Farsimen/3x-ui-multi-vendor/main/web/vendor-panel.php

echo -e "${GREEN}✓ فایل‌ها دانلود شدند${NC}"

echo -e "${YELLOW}[3/6] نصب API Proxy...${NC}"

# کپی فایل‌ها
cp api-proxy.php /var/www/html/
cp vendor-panel.php /var/www/html/

# تنظیم دسترسی‌ها
chmod 644 /var/www/html/api-proxy.php
chmod 644 /var/www/html/vendor-panel.php
chown www-data:www-data /var/www/html/*.php

# تنظیم دسترسی دیتابیس
chmod 644 /etc/x-ui/x-ui.db
chown www-data:www-data /etc/x-ui/x-ui.db

# بروزرسانی تنظیمات در فایل‌ها
sed -i "s|define('X_UI_API_BASE', '.*')|define('X_UI_API_BASE', 'http://127.0.0.1:${X_UI_PORT}')|" /var/www/html/api-proxy.php
sed -i "s|define('PANEL_URL', '.*')|define('PANEL_URL', 'http://${SERVER_IP}:${X_UI_PORT}${X_UI_PATH}')|" /var/www/html/vendor-panel.php

echo -e "${GREEN}✓ API Proxy نصب شد${NC}"

echo -e "${YELLOW}[4/6] پیکربندی Nginx...${NC}"

# پیکربندی Nginx برای Vendor Panel
cat > /etc/nginx/sites-available/3x-ui-vendor << EOF
server {
    listen 8080;
    server_name _;
    root /var/www/html;
    
    # Vendor Panel
    location /vendor-panel.php {
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
    
    # API Proxy for RBAC
    location /api/ {
        rewrite ^/api/(.*) /api-proxy.php/\$1 last;
    }
    
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
    }
}
EOF

ln -sf /etc/nginx/sites-available/3x-ui-vendor /etc/nginx/sites-enabled/
nginx -t > /dev/null 2>&1
systemctl reload nginx

echo -e "${GREEN}✓ Nginx پیکربندی شد${NC}"

echo -e "${YELLOW}[5/6] پیکربندی فایروال...${NC}"
if command -v ufw > /dev/null 2>&1; then
    ufw allow 8080/tcp > /dev/null 2>&1
    echo -e "${GREEN}✓ پورت 8080 باز شد${NC}"
fi

echo -e "${YELLOW}[6/6] ایجاد اسکریپت راهنما...${NC}"

cat > /root/3x-ui-vendor-usage.txt << 'USAGE_EOF'
╔═══════════════════════════════════════════════════════╗
║     3X-UI Multi-Vendor - راهنمای استفاده کامل      ║
╚═══════════════════════════════════════════════════════╝

🔹 دسترسی‌های نصب شده:
─────────────────────────────────────────────────────

1️⃣ پنل اصلی 3X-UI (Admin):
   - فقط Admin ها دسترسی کامل دارند
   - می‌توانند Inbound بسازند/حذف کنند
   
2️⃣ Vendor Web Panel:
   - URL: http://YOUR_IP:8080/vendor-panel.php
   - نمایش Inbound های مجاز
   - دسترسی محدود

3️⃣ API Proxy (خودکار):
   - فیلتر کردن درخواست‌های API
   - محدودیت دسترسی بر اساس نقش

─────────────────────────────────────────────────────
🔹 CLI Commands:
─────────────────────────────────────────────────────

x-ui-vendor add <name> <pass> [inbound_ids...]
x-ui-vendor list
x-ui-vendor delete <name>
x-ui-vendor grant <name> <inbound_id>
x-ui-vendor revoke <name> <inbound_id>
x-ui-vendor-info <name>
x-ui-vendor-test

─────────────────────────────────────────────────────
🔹 سناریوی کامل:
─────────────────────────────────────────────────────

1. Admin وارد پنل می‌شود
2. Inbound می‌سازد (مثلاً ID: 1, 2, 3)
3. از CLI vendor می‌سازد:
   x-ui-vendor add vendor1 Pass123 1 2
4. Vendor وارد پنل می‌شود
5. فقط Inbound 1 و 2 را می‌بیند
6. می‌تواند Client مدیریت کند
7. نمی‌تواند Inbound بسازد/حذف کند

─────────────────────────────────────────────────────
🔹 تست سیستم:
─────────────────────────────────────────────────────

# بررسی وضعیت
systemctl status nginx php-fpm x-ui

# تست API Proxy
curl -u vendor1:Pass123 http://127.0.0.1:8080/api/panel/api/inbounds/list

# تست Vendor Panel  
curl http://127.0.0.1:8080/vendor-panel.php

─────────────────────────────────────────────────────
🔹 عیب‌یابی:
─────────────────────────────────────────────────────

# لاگ Nginx
tail -f /var/log/nginx/error.log

# لاگ PHP
tail -f /var/log/php${PHP_VERSION}-fpm.log

# لاگ 3X-UI
journalctl -u x-ui -f

# بررسی دیتابیس
sqlite3 /etc/x-ui/x-ui.db "SELECT * FROM user_roles;"
sqlite3 /etc/x-ui/x-ui.db "SELECT * FROM inbound_access;"

╚═══════════════════════════════════════════════════════╝
USAGE_EOF

sed -i "s|YOUR_IP|${SERVER_IP}|g" /root/3x-ui-vendor-usage.txt
sed -i "s|php-fpm|php${PHP_VERSION}-fpm|g" /root/3x-ui-vendor-usage.txt
sed -i "s|\${PHP_VERSION}|${PHP_VERSION}|g" /root/3x-ui-vendor-usage.txt

echo -e "${GREEN}✓ راهنما ایجاد شد${NC}"

echo ""
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════╗
║     ✅ نصب کامل با موفقیت انجام شد!      ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 خلاصه نصب:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}✓ Database RBAC${NC}"
echo -e "${CYAN}✓ CLI Tools${NC}"
echo -e "${CYAN}✓ Vendor Web Panel${NC}"
echo -e "${CYAN}✓ API Proxy (فیلتر خودکار)${NC}"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔗 دسترسی‌ها:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}پنل Admin:${NC} http://${SERVER_IP}:${X_UI_PORT}${X_UI_PATH}"
echo -e "${YELLOW}Vendor Panel:${NC} http://${SERVER_IP}:8080/vendor-panel.php"
echo -e "${YELLOW}API Proxy:${NC} http://${SERVER_IP}:8080/api/"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}👥 تست سریع:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

FIRST_VENDOR=$(sqlite3 /etc/x-ui/x-ui.db "SELECT u.username FROM users u JOIN user_roles ur ON u.id = ur.user_id WHERE ur.role='vendor' LIMIT 1;" 2>/dev/null || echo "")

if [[ -n "$FIRST_VENDOR" ]]; then
    echo -e "${CYAN}Vendor موجود:${NC} $FIRST_VENDOR"
    echo -e "${CYAN}ورود به:${NC} http://${SERVER_IP}:8080/vendor-panel.php"
else
    echo -e "${YELLOW}⚠️  هنوز Vendor ندارید. ایجاد کنید:${NC}"
    echo -e "${CYAN}x-ui-vendor add vendor1 SecurePass123 1${NC}"
fi
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📚 راهنمای کامل:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}cat /root/3x-ui-vendor-usage.txt${NC}"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🧪 تست سیستم:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}x-ui-vendor-test${NC}"
echo ""

echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}    🚀 3X-UI Multi-Vendor آماده است!      ${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# پاکسازی
cd /root
rm -rf /tmp/3x-ui-vendor-install
