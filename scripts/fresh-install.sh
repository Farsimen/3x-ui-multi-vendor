#!/bin/bash

# اسکریپت نصب کامل از صفر - 3X-UI Multi-Vendor RBAC
# Ubuntu 20.04/22.04/24.04

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════╗
║   3X-UI Multi-Vendor RBAC Installer      ║
║          Fresh Installation              ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

# بررسی root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}این اسکریپت باید با دسترسی root اجرا شود${NC}"
   exit 1
fi

# بررسی سیستم عامل
if [[ ! -f /etc/os-release ]]; then
    echo -e "${RED}سیستم عامل شناسایی نشد${NC}"
    exit 1
fi

source /etc/os-release

if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
    echo -e "${RED}این اسکریپت فقط برای Ubuntu/Debian است${NC}"
    exit 1
fi

echo -e "${GREEN}✓ سیستم عامل: $PRETTY_NAME${NC}"
echo ""

# ============================================
# مرحله 1: پاکسازی کامل (اختیاری)
# ============================================

if systemctl is-active --quiet x-ui; then
    echo -e "${YELLOW}⚠️  3X-UI در حال اجراست${NC}"
    echo -n "آیا می‌خواهید نصب قبلی را حذف کنید؟ (yes/no): "
    read -r cleanup
    
    if [[ "$cleanup" == "yes" ]]; then
        echo -e "${YELLOW}[1/8] در حال پاکسازی نصب قبلی...${NC}"
        
        # Backup دیتابیس قبل از حذف
        if [[ -f /etc/x-ui/x-ui.db ]]; then
            BACKUP_DIR="/root/x-ui-backups"
            mkdir -p "$BACKUP_DIR"
            BACKUP_FILE="$BACKUP_DIR/x-ui.db.backup.$(date +%Y%m%d_%H%M%S)"
            cp /etc/x-ui/x-ui.db "$BACKUP_FILE"
            echo -e "${GREEN}✓ Backup: $BACKUP_FILE${NC}"
        fi
        
        # حذف کامل
        systemctl stop x-ui 2>/dev/null || true
        systemctl disable x-ui 2>/dev/null || true
        rm -rf /usr/local/x-ui
        rm -rf /etc/x-ui
        rm -f /etc/systemd/system/x-ui.service
        rm -f /usr/local/bin/x-ui
        rm -f /usr/local/bin/x-ui-vendor
        systemctl daemon-reload
        
        echo -e "${GREEN}✓ پاکسازی کامل شد${NC}"
    else
        echo -e "${RED}لطفا ابتدا 3X-UI قبلی را حذف کنید${NC}"
        exit 1
    fi
fi

echo ""

# ============================================
# مرحله 2: آپدیت سیستم و نصب پیش‌نیازها
# ============================================

echo -e "${YELLOW}[2/8] در حال آپدیت سیستم...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq

echo -e "${YELLOW}[3/8] در حال نصب پیش‌نیازها...${NC}"
apt-get install -y -qq \
    curl \
    wget \
    git \
    tar \
    unzip \
    sqlite3 \
    apache2-utils \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    ufw \
    fail2ban \
    > /dev/null 2>&1

echo -e "${GREEN}✓ پیش‌نیازها نصب شد${NC}"

# ============================================
# مرحله 3: نصب و پیکربندی فایروال
# ============================================

echo -e "${YELLOW}[4/8] در حال پیکربندی فایروال...${NC}"

# غیرفعال کردن IPv6 (اختیاری برای امنیت بیشتر)
if ! grep -q "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.conf; then
    echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
    sysctl -p > /dev/null 2>&1
fi

# پیکربندی UFW
ufw --force reset > /dev/null 2>&1
ufw default deny incoming > /dev/null 2>&1
ufw default allow outgoing > /dev/null 2>&1

# پورت‌های ضروری
ufw allow 22/tcp comment 'SSH' > /dev/null 2>&1
ufw allow 80/tcp comment 'HTTP' > /dev/null 2>&1
ufw allow 443/tcp comment 'HTTPS' > /dev/null 2>&1
ufw allow 54321/tcp comment '3X-UI Panel' > /dev/null 2>&1

# پورت‌های Xray (پیش‌فرض)
for port in 443 8443 2053 2083 2087 2096; do
    ufw allow $port/tcp > /dev/null 2>&1
done

ufw --force enable > /dev/null 2>&1

echo -e "${GREEN}✓ فایروال پیکربندی شد${NC}"

# ============================================
# مرحله 4: نصب 3X-UI اصلی
# ============================================

echo -e "${YELLOW}[5/8] در حال نصب 3X-UI پایه...${NC}"

cd /tmp
rm -rf 3x-ui-install
mkdir -p 3x-ui-install
cd 3x-ui-install

# دانلود آخرین نسخه 3X-UI
LATEST_VERSION=$(curl -s https://api.github.com/repos/MHSanaei/3x-ui/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')

if [[ -z "$LATEST_VERSION" ]]; then
    echo -e "${RED}خطا در دریافت نسخه آخر 3X-UI${NC}"
    exit 1
fi

echo -e "${BLUE}→ نسخه: $LATEST_VERSION${NC}"

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    armv7l) ARCH="armv7" ;;
    *) echo -e "${RED}معماری پشتیبانی نمی‌شود: $ARCH${NC}"; exit 1 ;;
esac

DOWNLOAD_URL="https://github.com/MHSanaei/3x-ui/releases/download/${LATEST_VERSION}/x-ui-linux-${ARCH}.tar.gz"

wget -q --show-progress "$DOWNLOAD_URL" -O x-ui.tar.gz

if [[ ! -f x-ui.tar.gz ]]; then
    echo -e "${RED}خطا در دانلود 3X-UI${NC}"
    exit 1
fi

tar -xzf x-ui.tar.gz
cd x-ui

# نصب
./x-ui install

echo -e "${GREEN}✓ 3X-UI نصب شد${NC}"

# توقف موقت برای نصب RBAC
systemctl stop x-ui

# ============================================
# مرحله 5: نصب Multi-Vendor RBAC
# ============================================

echo -e "${YELLOW}[6/8] در حال نصب Multi-Vendor RBAC...${NC}"

cd /tmp
rm -rf 3x-ui-multi-vendor
git clone -q https://github.com/Farsimen/3x-ui-multi-vendor.git
cd 3x-ui-multi-vendor

# Backup دیتابیس
if [[ -f /etc/x-ui/x-ui.db ]]; then
    BACKUP_FILE="/etc/x-ui/x-ui.db.backup.$(date +%Y%m%d_%H%M%S)"
    cp /etc/x-ui/x-ui.db "$BACKUP_FILE"
    echo -e "${BLUE}→ Backup: $BACKUP_FILE${NC}"
fi

# اجرای Migration
echo -e "${BLUE}→ در حال اجرای Migration دیتابیس...${NC}"
sqlite3 /etc/x-ui/x-ui.db < database/migration.sql

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Migration موفق${NC}"
else
    echo -e "${RED}✗ Migration ناموفق${NC}"
    echo -e "${YELLOW}در حال بازگردانی Backup...${NC}"
    cp "$BACKUP_FILE" /etc/x-ui/x-ui.db
    exit 1
fi

# نصب CLI Tool
cp scripts/x-ui-vendor /usr/local/bin/x-ui-vendor
chmod +x /usr/local/bin/x-ui-vendor

echo -e "${GREEN}✓ RBAC نصب شد${NC}"

# ============================================
# مرحله 6: پیکربندی امنیتی
# ============================================

echo -e "${YELLOW}[7/8] در حال پیکربندی امنیتی...${NC}"

# تنظیم دسترسی فایل‌ها
chmod 600 /etc/x-ui/x-ui.db
chown root:root /etc/x-ui/x-ui.db

# Fail2ban برای محافظت از پنل
if [[ -d /etc/fail2ban ]]; then
    cat > /etc/fail2ban/filter.d/x-ui.conf << 'EOF'
[Definition]
failregex = ^.*login failed.*from <HOST>.*$
ignoreregex =
EOF

    cat > /etc/fail2ban/jail.d/x-ui.conf << 'EOF'
[x-ui]
enabled = true
port = 54321
filter = x-ui
logpath = /var/log/x-ui/access.log
maxretry = 3
bantime = 3600
findtime = 600
EOF

    systemctl restart fail2ban
    echo -e "${GREEN}✓ Fail2ban پیکربندی شد${NC}"
fi

# ============================================
# مرحله 7: راه‌اندازی نهایی
# ============================================

echo -e "${YELLOW}[8/8] در حال راه‌اندازی سرویس...${NC}"

systemctl daemon-reload
systemctl enable x-ui
systemctl start x-ui

# انتظار برای شروع سرویس
sleep 3

if systemctl is-active --quiet x-ui; then
    echo -e "${GREEN}✓ 3X-UI با موفقیت راه‌اندازی شد${NC}"
else
    echo -e "${RED}✗ خطا در راه‌اندازی 3X-UI${NC}"
    echo -e "${YELLOW}بررسی لاگ: journalctl -u x-ui -n 50${NC}"
    exit 1
fi

# ============================================
# نمایش اطلاعات نهایی
# ============================================

echo ""
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════╗
║     ✅ نصب با موفقیت تکمیل شد!           ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

# دریافت IP سرور
SERVER_IP=$(curl -s -4 ifconfig.me || curl -s -4 icanhazip.com || echo "YOUR_SERVER_IP")

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📱 اطلاعات دسترسی:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}URL پنل:${NC} http://${SERVER_IP}:54321"
echo -e "${YELLOW}Username:${NC} admin"
echo -e "${YELLOW}Password:${NC} admin (⚠️ حتما تغییر دهید!)"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🛠️  دستورات CLI:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}# ساخت Vendor با دسترسی به Inbound های 1,2,3${NC}"
echo -e "x-ui-vendor add vendor1 MyPass123 1 2 3"
echo ""
echo -e "${CYAN}# لیست Vendor ها${NC}"
echo -e "x-ui-vendor list"
echo ""
echo -e "${CYAN}# دادن دسترسی جدید${NC}"
echo -e "x-ui-vendor grant vendor1 4"
echo ""
echo -e "${CYAN}# گرفتن دسترسی${NC}"
echo -e "x-ui-vendor revoke vendor1 2"
echo ""
echo -e "${CYAN}# حذف Vendor${NC}"
echo -e "x-ui-vendor delete vendor1"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔒 تنظیمات امنیتی:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}1.${NC} حتما رمز admin را تغییر دهید"
echo -e "${YELLOW}2.${NC} پورت پنل را از 54321 تغییر دهید"
echo -e "${YELLOW}3.${NC} SSL برای پنل فعال کنید"
echo -e "${YELLOW}4.${NC} 2FA را فعال کنید"
echo -e "${YELLOW}5.${NC} فایروال: ufw status"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 وضعیت سرویس:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
systemctl status x-ui --no-pager -l | head -5
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔗 لینک‌های مفید:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}GitHub:${NC} https://github.com/Farsimen/3x-ui-multi-vendor"
echo -e "${CYAN}Docs:${NC} https://github.com/Farsimen/3x-ui-multi-vendor/wiki"
echo -e "${CYAN}Issues:${NC} https://github.com/Farsimen/3x-ui-multi-vendor/issues"
echo ""

echo -e "${MAGENTA}═══════════════════════════════════════════${NC}"
echo -e "${MAGENTA}        🚀 Enjoy 3X-UI Multi-Vendor!       ${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════${NC}"
echo ""

# پاکسازی فایل‌های موقت
cd /root
rm -rf /tmp/3x-ui-install
rm -rf /tmp/3x-ui-multi-vendor

echo -e "${YELLOW}💾 Backup دیتابیس: $BACKUP_FILE${NC}"
echo -e "${YELLOW}📝 لاگ‌ها: journalctl -u x-ui -f${NC}"
echo ""