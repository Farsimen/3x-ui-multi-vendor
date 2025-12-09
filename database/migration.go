package database

import (
	"x-ui/database/model"
	"gorm.io/gorm"
	"x-ui/logger"
)

// MigrateRBAC - اجرای migration برای RBAC
func MigrateRBAC(db *gorm.DB) error {
	logger.Info("Starting RBAC migration...")
	
	// ایجاد جداول
	if err := db.AutoMigrate(
		&model.UserRole{},
		&model.InboundAccess{},
	); err != nil {
		logger.Error("Failed to auto migrate RBAC tables:", err)
		return err
	}
	
	// ایجاد نقش admin برای کاربر اولیه
	var adminUser model.User
	if err := db.Where("username = ?", "admin").First(&adminUser).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			logger.Warning("Admin user not found, skipping admin role creation")
			return nil
		}
		logger.Error("Failed to find admin user:", err)
		return err
	}
	
	// بررسی وجود نقش admin
	var existingRole model.UserRole
	if err := db.Where("user_id = ?", adminUser.ID).First(&existingRole).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			// ایجاد نقش admin
			adminRole := model.UserRole{
				UserID: adminUser.ID,
				Role:   "admin",
			}
			if err := db.Create(&adminRole).Error; err != nil {
				logger.Error("Failed to create admin role:", err)
				return err
			}
			logger.Info("Admin role created successfully")
			return nil
		}
		logger.Error("Failed to check existing admin role:", err)
		return err
	}
	
	logger.Info("Admin role already exists")
	return nil
}