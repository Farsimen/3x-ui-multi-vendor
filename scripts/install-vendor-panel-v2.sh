#!/bin/bash

# نصب پنل کامل Vendor نسخه 2
# با قابلیت کامل مدیریت Client

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
║    Vendor Panel v2 - Complete Edition     ║
║      مدیریت کامل Client ها            ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}باید با root اجرا شود${NC}"
   exit 1
fi

echo -e "${YELLOW}[1/5] نصب پیش‌نیازها...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq > /dev/null 2>&1
apt-get install -y -qq nginx php-fpm php-sqlite3 php-curl sqlite3 > /dev/null 2>&1
echo -e "${GREEN}✓ پیش‌نیازها نصب شد${NC}"

PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
echo -e "${BLUE}→ PHP $PHP_VERSION${NC}"

if [[ ! -f /etc/x-ui/x-ui.db ]]; then
    echo -e "${RED}خطا: 3X-UI نصب نیست!${NC}"
    exit 1
fi

SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || echo "127.0.0.1")

echo -e "${YELLOW}[2/5] دانلود فایل‌ها...${NC}"
rm -rf /var/www/vendor-panel
mkdir -p /var/www/vendor-panel
cd /var/www/vendor-panel

wget -q https://raw.githubusercontent.com/Farsimen/3x-ui-multi-vendor/main/vendor-panel-v2/index.php
wget -q https://raw.githubusercontent.com/Farsimen/3x-ui-multi-vendor/main/vendor-panel-v2/login.php
wget -q https://raw.githubusercontent.com/Farsimen/3x-ui-multi-vendor/main/vendor-panel-v2/dashboard.php
wget -q https://raw.githubusercontent.com/Farsimen/3x-ui-multi-vendor/main/vendor-panel-v2/api.php
wget -q https://raw.githubusercontent.com/Farsimen/3x-ui-multi-vendor/main/vendor-panel-v2/style.css
wget -q https://raw.githubusercontent.com/Farsimen/3x-ui-multi-vendor/main/vendor-panel-v2/script.js

chown -R www-data:www-data /var/www/vendor-panel
chmod -R 755 /var/www/vendor-panel
chmod 644 /etc/x-ui/x-ui.db
chown www-data:www-data /etc/x-ui/x-ui.db

echo -e "${GREEN}✓ فایل‌ها دانلود شدند${NC}"

echo -e "${YELLOW}[3/5] پیکربندی Nginx...${NC}"

cat > /etc/nginx/sites-available/vendor-panel << EOF
server {
    listen 9000;
    server_name _;
    root /var/www/vendor-panel;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(ht|git) {
        deny all;
    }
}
EOF

ln -sf /etc/nginx/sites-available/vendor-panel /etc/nginx/sites-enabled/
nginx -t > /dev/null 2>&1 && systemctl reload nginx

echo -e "${GREEN}✓ Nginx پیکربندی شد${NC}"

echo -e "${YELLOW}[4/5] فایروال...${NC}"
if command -v ufw > /dev/null 2>&1; then
    ufw allow 9000/tcp > /dev/null 2>&1
    echo -e "${GREEN}✓ پورت 9000 باز شد${NC}"
fi

echo -e "${YELLOW}[5/5] راهنما...${NC}"

cat > /root/vendor-panel-info.txt << 'GUIDE_EOF'
╔═══════════════════════════════════════════════════════╗
║         Vendor Panel v2 - راهنما کامل          ║
╚═══════════════════════════════════════════════════════╝

🔗 دسترسی:
   URL: http://YOUR_IP:9000
   Port: 9000

👥 لاگین:
   - Vendor ها: با username/password خودشان
   - Admin: با حساب admin 3X-UI

✨ قابلیت‌ها:
   ✅ مشاهده لیست Client ها
   ✅ ایجاد Client جدید
   ✅ فعال/غیرفعال کردن
   ✅ تنظیم حجم و تاریخ
   ✅ نمایش QR Code
   ✅ لینک کانفیگ
   ✅ لینک Subscription
   ❌ بدون حذف Client
   ❌ بدون ساخت Inbound

🛠️ مدیریت:
   systemctl restart nginx
   systemctl restart x-ui
   tail -f /var/log/nginx/error.log

📚 مستندات:
   https://github.com/Farsimen/3x-ui-multi-vendor

╚═══════════════════════════════════════════════════════╝
GUIDE_EOF

sed -i "s|YOUR_IP|${SERVER_IP}|g" /root/vendor-panel-info.txt

echo ""
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════╗
║     ✅ نصب با موفقیت انجام شد!         ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔗 دسترسی به پنل:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}URL: http://${SERVER_IP}:9000${NC}"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}👥 تست لاگین:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

FIRST_VENDOR=$(sqlite3 /etc/x-ui/x-ui.db "SELECT u.username FROM users u JOIN user_roles ur ON u.id = ur.user_id WHERE ur.role='vendor' LIMIT 1;" 2>/dev/null || echo "")

if [[ -n "$FIRST_VENDOR" ]]; then
    echo -e "${YELLOW}Username:${NC} $FIRST_VENDOR"
    echo -e "${YELLOW}Password:${NC} (رمزی که هنگام ساخت تعیین کردید)"
else
    echo -e "${YELLOW}⚠️  هنوز Vendor ندارید. ایجاد:${NC}"
    echo -e "${CYAN}x-ui-vendor add vendor1 Pass123 1${NC}"
fi
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📚 راهنمای کامل:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}cat /root/vendor-panel-info.txt${NC}"
echo ""

echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}    🎉 آماده به کار! از Vendor Panel لذت ببرید!${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
