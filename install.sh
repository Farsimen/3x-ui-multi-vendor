#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}3X-UI Multi-Vendor RBAC Installer${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""

# بررسی root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}این اسکریپت باید با دسترسی root اجرا شود${NC}"
   exit 1
fi

# بررسی نصب 3X-UI
if [[ ! -f /usr/local/x-ui/x-ui ]]; then
    echo -e "${RED}3X-UI نصب نیست!${NC}"
    echo "ابتدا 3X-UI را نصب کنید:"
    echo "bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)"
    exit 1
fi

echo -e "${YELLOW}در حال نصب وابستگی‌ها...${NC}"
apt-get update -qq
apt-get install -y -qq sqlite3 apache2-utils git > /dev/null 2>&1

echo -e "${YELLOW}در حال دانلود فایل‌ها...${NC}"
cd /tmp
rm -rf 3x-ui-multi-vendor
git clone -q https://github.com/Farsimen/3x-ui-multi-vendor.git
cd 3x-ui-multi-vendor

echo -e "${YELLOW}در حال توقف 3X-UI...${NC}"
systemctl stop x-ui

echo -e "${YELLOW}در حال Backup دیتابیس...${NC}"
BACKUP_FILE="/etc/x-ui/x-ui.db.backup.$(date +%Y%m%d_%H%M%S)"
cp /etc/x-ui/x-ui.db "$BACKUP_FILE"
echo -e "${GREEN}Backup ذخیره شد: $BACKUP_FILE${NC}"

echo -e "${YELLOW}در حال اجرای Migration...${NC}"
sqlite3 /etc/x-ui/x-ui.db << 'EOF'
-- ایجاد جدول user_roles
CREATE TABLE IF NOT EXISTS user_roles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL UNIQUE,
    role VARCHAR(20) NOT NULL CHECK(role IN ('admin', 'vendor')),
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    deleted_at DATETIME,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ایجاد جدول inbound_access
CREATE TABLE IF NOT EXISTS inbound_access (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    inbound_id INTEGER NOT NULL,
    granted_at DATETIME NOT NULL,
    granted_by INTEGER,
    deleted_at DATETIME,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (inbound_id) REFERENCES inbounds(id) ON DELETE CASCADE
);

-- ایجاد index
CREATE INDEX IF NOT EXISTS idx_user_inbound ON inbound_access(user_id, inbound_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_userid ON user_roles(user_id);

-- ساخت نقش admin برای کاربر اولیه
INSERT OR IGNORE INTO user_roles (user_id, role, created_at, updated_at)
SELECT id, 'admin', datetime('now'), datetime('now')
FROM users
WHERE username = 'admin'
LIMIT 1;
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Migration با موفقیت انجام شد${NC}"
else
    echo -e "${RED}Migration با خطا مواجه شد!${NC}"
    echo -e "${YELLOW}برگرداندن Backup...${NC}"
    cp "$BACKUP_FILE" /etc/x-ui/x-ui.db
    systemctl start x-ui
    exit 1
fi

echo -e "${YELLOW}در حال نصب CLI Tool...${NC}"
cp scripts/x-ui-vendor /usr/local/bin/x-ui-vendor
chmod +x /usr/local/bin/x-ui-vendor

echo -e "${YELLOW}در حال شروع 3X-UI...${NC}"
systemctl start x-ui

if systemctl is-active --quiet x-ui; then
    echo -e "${GREEN}3X-UI با موفقیت شروع شد${NC}"
else
    echo -e "${RED}3X-UI شروع نشد!${NC}"
    echo -e "${YELLOW}برگرداندن Backup...${NC}"
    cp "$BACKUP_FILE" /etc/x-ui/x-ui.db
    systemctl start x-ui
    exit 1
fi

echo ""
echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}✅ نصب با موفقیت انجام شد!${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""
echo -e "${BLUE}🛠  دستورات CLI:${NC}"
echo "  x-ui-vendor add <username> <password> [inbound_ids]"
echo "  x-ui-vendor list"
echo "  x-ui-vendor delete <username>"
echo "  x-ui-vendor grant <username> <inbound_id>"
echo "  x-ui-vendor revoke <username> <inbound_id>"
echo ""
echo -e "${BLUE}💡 مثال:${NC}"
echo "  x-ui-vendor add vendor1 MyPass123 1 2 3"
echo ""
echo -e "${YELLOW}💾 Backup قبلی شما:${NC}"
echo "  $BACKUP_FILE"
echo ""