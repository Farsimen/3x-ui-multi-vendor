# راهنمای نصب کامل 3X-UI Multi-Vendor RBAC

<div dir="rtl">

## 📋 پیش‌نیازها

### سیستم عامل
- Ubuntu 20.04 LTS ✅
- Ubuntu 22.04 LTS ✅ (توصیه می‌شود)
- Ubuntu 24.04 LTS ✅
- Debian 11/12 ✅

### سخت‌افزار مورد نیاز
- CPU: 1 Core (توصیه: 2 Core)
- RAM: 512MB (توصیه: 1GB)
- Storage: 5GB خالی
- Network: دسترسی به اینترنت

---

## 🚀 روش 1: نصب تک‌دستوری (5 دقیقه)

### نصب از صفر روی سرور تمیز

```bash
curl -Ls https://raw.githubusercontent.com/Farsimen/3x-ui-multi-vendor/main/scripts/fresh-install.sh | bash
```

**این اسکریپت:**
- ✅ سیستم را آپدیت می‌کند
- ✅ تمام پیش‌نیازها را نصب می‌کند
- ✅ فایروال را پیکربندی می‌کند
- ✅ 3X-UI اصلی را نصب می‌کند
- ✅ RBAC Multi-Vendor را اضافه می‌کند
- ✅ CLI Tool را نصب می‌کند
- ✅ سرویس را راه‌اندازی می‌کند

---

## 🗑️ روش 2: حذف کامل نصب قبلی

### اگر قبلاً 3X-UI نصب کرده‌اید:

```bash
# دانلود اسکریپت حذف
curl -Ls https://raw.githubusercontent.com/Farsimen/3x-ui-multi-vendor/main/scripts/uninstall.sh -o /tmp/uninstall.sh

# اجرای اسکریپت
bash /tmp/uninstall.sh
```

**این اسکریپت حذف می‌کند:**
- ⚠️ تمام فایل‌های 3X-UI
- ⚠️ دیتابیس (قبلاً Backup می‌شود)
- ⚠️ سرویس‌ها و تنظیمات
- ⚠️ CLI Tools

**بعد از حذف، نصب مجدد:**
```bash
curl -Ls https://raw.githubusercontent.com/Farsimen/3x-ui-multi-vendor/main/scripts/fresh-install.sh | bash
```

---

## 🔧 روش 3: نصب دستی (پیشرفته)

### مرحله 1: پاکسازی کامل (اختیاری)

```bash
# توقف سرویس
systemctl stop x-ui
systemctl disable x-ui

# Backup دیتابیس
mkdir -p /root/x-ui-backups
cp /etc/x-ui/x-ui.db /root/x-ui-backups/x-ui.db.backup.$(date +%Y%m%d_%H%M%S)

# حذف فایل‌ها
rm -rf /usr/local/x-ui
rm -rf /etc/x-ui
rm -f /etc/systemd/system/x-ui.service
rm -f /usr/local/bin/x-ui
rm -f /usr/local/bin/x-ui-vendor

# ریلود systemd
systemctl daemon-reload
```

### مرحله 2: آپدیت سیستم

```bash
# آپدیت پکیج‌ها
apt update && apt upgrade -y

# نصب پیش‌نیازها
apt install -y \
    curl \
    wget \
    git \
    tar \
    unzip \
    sqlite3 \
    apache2-utils \
    ca-certificates \
    ufw \
    fail2ban
```

### مرحله 3: پیکربندی فایروال

```bash
# ریست فایروال
ufw --force reset

# تنظیمات پیش‌فرض
ufw default deny incoming
ufw default allow outgoing

# پورت‌های ضروری
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw allow 54321/tcp comment '3X-UI Panel'

# پورت‌های Xray (بر اساس نیاز)
ufw allow 8443/tcp
ufw allow 2053/tcp
ufw allow 2083/tcp
ufw allow 2087/tcp
ufw allow 2096/tcp

# فعال‌سازی
ufw --force enable
ufw status
```

### مرحله 4: نصب 3X-UI اصلی

```bash
# دانلود و نصب
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)

# توقف موقت برای نصب RBAC
systemctl stop x-ui
```

### مرحله 5: نصب Multi-Vendor RBAC

```bash
# Clone repository
cd /tmp
git clone https://github.com/Farsimen/3x-ui-multi-vendor.git
cd 3x-ui-multi-vendor

# Backup دیتابیس
cp /etc/x-ui/x-ui.db /etc/x-ui/x-ui.db.backup.$(date +%Y%m%d_%H%M%S)

# اجرای Migration
sqlite3 /etc/x-ui/x-ui.db < database/migration.sql

# بررسی موفقیت Migration
if [ $? -eq 0 ]; then
    echo "✓ Migration موفق"
else
    echo "✗ Migration ناموفق - بازگردانی Backup"
    cp /etc/x-ui/x-ui.db.backup.* /etc/x-ui/x-ui.db
    exit 1
fi

# نصب CLI Tool
cp scripts/x-ui-vendor /usr/local/bin/x-ui-vendor
chmod +x /usr/local/bin/x-ui-vendor
```

### مرحله 6: راه‌اندازی سرویس

```bash
# شروع سرویس
systemctl start x-ui
systemctl enable x-ui

# بررسی وضعیت
systemctl status x-ui

# بررسی لاگ‌ها
journalctl -u x-ui -f
```

---

## 🔐 تنظیمات امنیتی (بعد از نصب)

### 1. تغییر رمز Admin

```bash
# ورود به پنل
http://YOUR_SERVER_IP:54321

# Username: admin
# Password: admin (حتماً تغییر دهید!)
```

### 2. تغییر پورت پنل

```bash
# ویرایش تنظیمات از پنل
Settings → Panel Port → تغییر از 54321 به پورت دلخواه

# یا از CLI:
x-ui set -port 12345

# باز کردن پورت جدید در فایروال
ufw allow 12345/tcp
ufw delete allow 54321/tcp
```

### 3. فعال‌سازی SSL

```bash
# از پنل:
Settings → Panel SSL → Enable

# یا نصب Certbot:
apt install certbot
certbot certonly --standalone -d your-domain.com
```

### 4. فعال‌سازی 2FA

```bash
# از پنل:
Settings → Security → Enable 2FA
# اسکن QR code با Google Authenticator
```

### 5. تنظیم Fail2ban

```bash
# ایجاد فیلتر
cat > /etc/fail2ban/filter.d/x-ui.conf << 'EOF'
[Definition]
failregex = ^.*login failed.*from <HOST>.*$
ignoreregex =
EOF

# ایجاد jail
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

# ریستارت
systemctl restart fail2ban
```

---

## 🧪 تست نصب

### 1. بررسی سرویس

```bash
# وضعیت سرویس
systemctl status x-ui

# باید active (running) باشد
```

### 2. بررسی دیتابیس

```bash
# بررسی جداول RBAC
sqlite3 /etc/x-ui/x-ui.db "SELECT name FROM sqlite_master WHERE type='table';"

# باید شامل user_roles و inbound_access باشد
```

### 3. تست CLI Tool

```bash
# راهنما
x-ui-vendor help

# لیست Vendor ها (خالی در ابتدا)
x-ui-vendor list
```

### 4. ساخت Vendor تستی

```bash
# ساخت Vendor
x-ui-vendor add testvendor TestPass123 1

# بررسی
x-ui-vendor list

# حذف
x-ui-vendor delete testvendor
```

---

## 📱 دسترسی به پنل

### اطلاعات لاگین پیش‌فرض

```
URL: http://YOUR_SERVER_IP:54321
Username: admin
Password: admin
```

### دریافت IP سرور

```bash
# روش 1
curl -4 ifconfig.me

# روش 2
ip addr show

# روش 3
hostname -I
```

---

## 🛠️ استفاده از CLI

### ساخت Vendor با دسترسی به Inbound های 1, 2, 3

```bash
x-ui-vendor add vendor1 MySecurePass123 1 2 3
```

### لیست تمام Vendor ها

```bash
x-ui-vendor list
```

**خروجی نمونه:**
```
لیست Vendor ها:
------------------------
ID  Username   Inbound_IDs
--  --------   -----------
2   vendor1    1,2,3
3   vendor2    1,5
```

### دادن دسترسی جدید

```bash
# دسترسی به Inbound 4
x-ui-vendor grant vendor1 4
```

### گرفتن دسترسی

```bash
# حذف دسترسی از Inbound 2
x-ui-vendor revoke vendor1 2
```

### حذف Vendor

```bash
x-ui-vendor delete vendor1
```

---

## 🔍 عیب‌یابی

### سرویس شروع نمی‌شود

```bash
# بررسی لاگ‌ها
journalctl -u x-ui -n 100 --no-pager

# بررسی پورت
netstat -tulpn | grep 54321

# بررسی دیتابیس
sqlite3 /etc/x-ui/x-ui.db "PRAGMA integrity_check;"
```

### خطای Migration

```bash
# بازگردانی Backup
cp /root/x-ui-backups/x-ui.db.backup.* /etc/x-ui/x-ui.db

# اجرای مجدد Migration
cd /tmp/3x-ui-multi-vendor
sqlite3 /etc/x-ui/x-ui.db < database/migration.sql
```

### CLI Tool کار نمی‌کند

```bash
# بررسی نصب
which x-ui-vendor

# نصب مجدد
cd /tmp/3x-ui-multi-vendor
cp scripts/x-ui-vendor /usr/local/bin/x-ui-vendor
chmod +x /usr/local/bin/x-ui-vendor
```

### فراموشی رمز Admin

```bash
# ریست رمز به admin/admin
x-ui reset

# یا مستقیم از دیتابیس:
sqlite3 /etc/x-ui/x-ui.db "UPDATE users SET password='\$2a\$10\$...' WHERE username='admin';"
```

---

## 🔄 آپدیت سیستم

### آپدیت 3X-UI + RBAC

```bash
# Backup
cp /etc/x-ui/x-ui.db /root/x-ui-backups/x-ui.db.backup.$(date +%Y%m%d_%H%M%S)

# آپدیت 3X-UI
x-ui update

# آپدیت RBAC
cd /tmp
git clone https://github.com/Farsimen/3x-ui-multi-vendor.git
cd 3x-ui-multi-vendor
sqlite3 /etc/x-ui/x-ui.db < database/migration.sql
cp scripts/x-ui-vendor /usr/local/bin/x-ui-vendor

# ریستارت
systemctl restart x-ui
```

---

## 📊 مدیریت Backup

### Backup دستی

```bash
# ایجاد Backup
mkdir -p /root/x-ui-backups
cp /etc/x-ui/x-ui.db /root/x-ui-backups/x-ui.db.backup.$(date +%Y%m%d_%H%M%S)

# فشرده‌سازی
tar -czf /root/x-ui-backups/x-ui-full-backup.tar.gz /etc/x-ui /usr/local/x-ui
```

### Backup خودکار روزانه

```bash
# ایجاد اسکریپت
cat > /usr/local/bin/x-ui-backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/root/x-ui-backups"
mkdir -p "$BACKUP_DIR"
cp /etc/x-ui/x-ui.db "$BACKUP_DIR/x-ui.db.backup.$(date +%Y%m%d_%H%M%S)"
# حذف Backup های قدیمی‌تر از 7 روز
find "$BACKUP_DIR" -name "x-ui.db.backup.*" -mtime +7 -delete
EOF

chmod +x /usr/local/bin/x-ui-backup.sh

# اضافه به Cron (هر روز ساعت 3 صبح)
echo "0 3 * * * /usr/local/bin/x-ui-backup.sh" | crontab -
```

### بازگردانی Backup

```bash
# توقف سرویس
systemctl stop x-ui

# بازگردانی
cp /root/x-ui-backups/x-ui.db.backup.YYYYMMDD_HHMMSS /etc/x-ui/x-ui.db

# شروع سرویس
systemctl start x-ui
```

---

## 🌍 تنظیمات شبکه (برای ایران)

### تنظیم DNS

```bash
# استفاده از Cloudflare/Shecan
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 178.22.122.100" >> /etc/resolv.conf
```

### غیرفعال کردن IPv6

```bash
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p
```

### تنظیم TCP BBR (بهبود سرعت)

```bash
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# بررسی
sysctl net.ipv4.tcp_congestion_control
```

---

## 📞 پشتیبانی

### لینک‌های مفید

- **GitHub**: https://github.com/Farsimen/3x-ui-multi-vendor
- **Issues**: https://github.com/Farsimen/3x-ui-multi-vendor/issues
- **Discussions**: https://github.com/Farsimen/3x-ui-multi-vendor/discussions
- **3X-UI اصلی**: https://github.com/MHSanaei/3x-ui

### گزارش باگ

```bash
# جمع‌آوری اطلاعات سیستم
uname -a
lsb_release -a
systemctl status x-ui
journalctl -u x-ui -n 50
x-ui-vendor list
```

---

## ⚠️ نکات مهم

1. **حتماً رمز عبور پیش‌فرض را تغییر دهید**
2. **از Backup منظم استفاده کنید**
3. **پورت پنل را تغییر دهید**
4. **SSL فعال کنید**
5. **2FA فعال کنید**
6. **فایروال را به‌درستی تنظیم کنید**
7. **لاگ‌ها را مرتب بررسی کنید**

---

## ✅ چک‌لیست نصب

- [ ] سیستم عامل Ubuntu/Debian
- [ ] دسترسی root
- [ ] اتصال به اینترنت
- [ ] IP عمومی
- [ ] حداقل 1GB RAM
- [ ] حداقل 5GB فضای خالی
- [ ] اجرای fresh-install.sh
- [ ] تغییر رمز admin
- [ ] تغییر پورت پنل
- [ ] فعال‌سازی SSL
- [ ] فعال‌سازی 2FA
- [ ] تنظیم Backup خودکار
- [ ] تست CLI Tool
- [ ] ساخت Vendor تستی

---

<div align="center">

**✅ نصب شما کامل شد!**

🚀 **از 3X-UI Multi-Vendor لذت ببرید**

</div>

</div>