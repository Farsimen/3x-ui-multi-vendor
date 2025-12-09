#!/bin/bash

# اسکریپت حذف کامل 3X-UI Multi-Vendor RBAC

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}====================================${NC}"
echo -e "${RED}3X-UI Multi-Vendor RBAC Uninstaller${NC}"
echo -e "${RED}====================================${NC}"
echo ""

# بررسی root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}این اسکریپت باید با دسترسی root اجرا شود${NC}"
   exit 1
fi

echo -e "${YELLOW}⚠️  هشدار: این عملیات تمام داده‌های 3X-UI را حذف می‌کند!${NC}"
echo -n "آیا مطمئن هستید؟ (yes/no): "
read -r confirm

if [[ "$confirm" != "yes" ]]; then
    echo -e "${GREEN}عملیات لغو شد${NC}"
    exit 0
fi

echo -e "${YELLOW}در حال توقف سرویس 3X-UI...${NC}"
systemctl stop x-ui 2>/dev/null || true
systemctl disable x-ui 2>/dev/null || true

echo -e "${YELLOW}در حال حذف فایل‌های 3X-UI...${NC}"
rm -rf /usr/local/x-ui
rm -rf /etc/x-ui
rm -f /etc/systemd/system/x-ui.service
rm -f /usr/local/bin/x-ui
rm -f /usr/local/bin/x-ui-vendor

echo -e "${YELLOW}در حال پاکسازی systemd...${NC}"
systemctl daemon-reload
systemctl reset-failed

echo -e "${YELLOW}در حال حذف کاربران 3X-UI...${NC}"
userdel -r x-ui 2>/dev/null || true

echo -e "${YELLOW}در حال حذف گروه‌های 3X-UI...${NC}"
groupdel x-ui 2>/dev/null || true

echo -e "${YELLOW}در حال پاکسازی لاگ‌ها...${NC}"
rm -rf /var/log/x-ui
rm -f /var/log/x-ui.log

echo -e "${YELLOW}در حال پاکسازی فایل‌های موقت...${NC}"
rm -rf /tmp/3x-ui*
rm -rf /tmp/x-ui*

echo ""
echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}✅ حذف کامل 3X-UI با موفقیت انجام شد${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""
echo -e "${YELLOW}برای نصب مجدد از اسکریپت fresh-install.sh استفاده کنید${NC}"