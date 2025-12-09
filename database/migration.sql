-- Migration SQL for 3X-UI Multi-Vendor RBAC
-- تاریخ: 2025-12-09

-- ایجاد جدول user_roles
CREATE TABLE IF NOT EXISTS user_roles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL UNIQUE,
    role VARCHAR(20) NOT NULL CHECK(role IN ('admin', 'vendor')),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at DATETIME,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ایجاد جدول inbound_access
CREATE TABLE IF NOT EXISTS inbound_access (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    inbound_id INTEGER NOT NULL,
    granted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    granted_by INTEGER,
    deleted_at DATETIME,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (inbound_id) REFERENCES inbounds(id) ON DELETE CASCADE,
    UNIQUE(user_id, inbound_id)
);

-- ایجاد Index برای بهبود عملکرد
CREATE INDEX IF NOT EXISTS idx_user_inbound ON inbound_access(user_id, inbound_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_userid ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(role);
CREATE INDEX IF NOT EXISTS idx_inbound_access_userid ON inbound_access(user_id);
CREATE INDEX IF NOT EXISTS idx_inbound_access_inboundid ON inbound_access(inbound_id);

-- ساخت نقش admin برای کاربر اولیه (فقط اگر وجود ندارد)
INSERT OR IGNORE INTO user_roles (user_id, role, created_at, updated_at)
SELECT id, 'admin', datetime('now'), datetime('now')
FROM users
WHERE username = 'admin'
LIMIT 1;

-- Trigger برای به‌روزرسانی خودکار updated_at
CREATE TRIGGER IF NOT EXISTS update_user_roles_timestamp 
AFTER UPDATE ON user_roles
FOR EACH ROW
BEGIN
    UPDATE user_roles SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- بررسی موفقیت‌آمیز بودن migration
SELECT '✅ Migration با موفقیت انجام شد!' as Status;
SELECT COUNT(*) as 'Total Admin Users' FROM user_roles WHERE role = 'admin';
SELECT COUNT(*) as 'Total Vendor Users' FROM user_roles WHERE role = 'vendor';