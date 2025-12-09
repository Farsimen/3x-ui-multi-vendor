# 3X-UI Multi-Vendor RBAC

<div dir="rtl">

## 📋 معرفی

سیستم Multi-Vendor با RBAC (Role-Based Access Control) برای پنل 3X-UI که امکان مدیریت تا 50 فروشنده را با دسترسی‌های محدود فراهم می‌کند.

## ✨ ویژگی‌ها

### برای Admin:
- ✅ ساخت/حذف Vendor های نامحدود (تا 50)
- ✅ تعیین دسترسی‌های دقیق برای هر Vendor
- ✅ مدیریت کامل Inbound ها و تنظیمات سرور
- ✅ نظارت بر عملکرد تمام Vendor ها
- ✅ مدیریت از طریق CLI و رابط وب

### برای Vendor:
- ✅ دسترسی محدود به Inbound های تخصیص داده شده
- ✅ ساخت/ویرایش/حذف Client فقط در Inbound های مجاز
- ✅ مشاهده آمار و ترافیک Inbound های خود
- ❌ عدم دسترسی به تنظیمات سرور
- ❌ عدم امکان ساخت/ویرایش Inbound
- ❌ عدم دسترسی به Vendor های دیگر

## 🏗️ معماری

### دیتابیس
- **user_roles**: نقش‌های کاربران (admin/vendor)
- **inbound_access**: دسترسی‌های vendor به inbound ها

### Backend
- **RBAC Service**: سرویس مدیریت دسترسی‌ها
- **Middleware**: بررسی خودکار دسترسی‌ها
- **API Endpoints**: REST API برای مدیریت vendor ها

### Frontend
- فیلتر خودکار منوها بر اساس نقش
- صفحه مدیریت Vendor برای Admin
- نمایش فقط Inbound های مجاز برای Vendor

## 📦 نصب

### پیش‌نیازها
- Ubuntu 22.04 یا بالاتر
- 3X-UI نصب شده
- Go 1.23+
- SQLite3

### نصب سریع

```bash
bash <(curl -Ls https://raw.githubusercontent.com/Farsimen/3x-ui-multi-vendor/main/install.sh)
```

### نصب دستی

```bash
# Clone repository
git clone https://github.com/Farsimen/3x-ui-multi-vendor.git
cd 3x-ui-multi-vendor

# Build
export CGO_ENABLED=1
go build -o x-ui main.go

# توقف 3X-UI
systemctl stop x-ui

# Backup دیتابیس
cp /etc/x-ui/x-ui.db /etc/x-ui/x-ui.db.backup

# اجرای migration
sqlite3 /etc/x-ui/x-ui.db < database/migration.sql

# جایگزینی فایل
cp x-ui /usr/local/x-ui/x-ui

# شروع سرویس
systemctl start x-ui
```

## 🔧 استفاده از CLI

### ساخت Vendor جدید

```bash
x-ui-vendor add vendor1 MyPassword123 1 2 3
```

این دستور یک vendor به نام `vendor1` با دسترسی به Inbound های 1، 2 و 3 می‌سازد.

### لیست Vendor ها

```bash
x-ui-vendor list
```

### حذف Vendor

```bash
x-ui-vendor delete vendor1
```

### دادن دسترسی به Inbound

```bash
x-ui-vendor grant vendor1 5
```

### گرفتن دسترسی از Inbound

```bash
x-ui-vendor revoke vendor1 2
```

## 🌐 API Documentation

### Vendor Management

#### ساخت Vendor
```http
POST /api/vendor/create
Content-Type: application/json

{
  "username": "vendor1",
  "password": "MyPassword123",
  "inboundIds": [1, 2, 3]
}
```

#### لیست Vendor ها
```http
GET /api/vendor/list
```

#### حذف Vendor
```http
DELETE /api/vendor/delete/:id
```

#### دادن دسترسی
```http
POST /api/vendor/grant
Content-Type: application/json

{
  "vendorId": 2,
  "inboundId": 5
}
```

#### گرفتن دسترسی
```http
POST /api/vendor/revoke
Content-Type: application/json

{
  "vendorId": 2,
  "inboundId": 3
}
```

## 🛡️ امنیت

- Password ها با bcrypt hash می‌شوند
- Session-based authentication
- Middleware برای بررسی خودکار دسترسی‌ها
- جلوگیری از SQL Injection
- محدودیت تعداد Vendor ها (50)

## 📁 ساختار پروژه

```
3x-ui-multi-vendor/
├── database/
│   ├── model/
│   │   ├── model.go
│   │   └── rbac.go          # مدل‌های RBAC
│   ├── db.go
│   └── migration.go         # Migration RBAC
├── web/
│   ├── service/
│   │   ├── rbac.go          # سرویس RBAC
│   │   └── user.go
│   ├── controller/
│   │   └── vendor.go        # Controller مدیریت Vendor
│   ├── middleware/
│   │   └── rbac.go          # Middleware RBAC
│   └── router.go
├── x-ui-vendor              # CLI Tool
├── install.sh               # Installer
└── README.md
```

## 🤝 مشارکت

برای مشارکت در پروژه:

1. Fork کنید
2. Branch جدید بسازید (`git checkout -b feature/amazing-feature`)
3. تغییرات را Commit کنید (`git commit -m 'Add amazing feature'`)
4. Push کنید (`git push origin feature/amazing-feature`)
5. Pull Request باز کنید

## 📄 لایسنس

GPL-3.0 License

## 🙏 تشکر

از پروژه [3X-UI](https://github.com/MHSanaei/3x-ui) توسط MHSanaei

## 📞 پشتیبانی

- Issues: [GitHub Issues](https://github.com/Farsimen/3x-ui-multi-vendor/issues)
- Discussions: [GitHub Discussions](https://github.com/Farsimen/3x-ui-multi-vendor/discussions)

</div>

---

<div align="center">

**Made with ❤️ for 3X-UI Community**

[⭐ Star این پروژه](https://github.com/Farsimen/3x-ui-multi-vendor)

</div>