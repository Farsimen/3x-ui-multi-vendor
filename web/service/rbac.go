package service

import (
	"errors"
	"x-ui/database"
	"x-ui/database/model"
)

type RBACService struct{}

var (
	ErrUnauthorized    = errors.New("unauthorized access")
	ErrUserNotFound    = errors.New("user not found")
	ErrInvalidRole     = errors.New("invalid role")
	ErrAccessDenied    = errors.New("access denied")
	ErrDuplicateAccess = errors.New("access already granted")
)

// IsAdmin - بررسی admin بودن کاربر
func (s *RBACService) IsAdmin(userID int) (bool, error) {
	db := database.GetDB()
	var role model.UserRole
	
	err := db.Where("user_id = ?", userID).First(&role).Error
	if err != nil {
		if database.IsNotFound(err) {
			return false, nil
		}
		return false, err
	}
	
	return role.Role == "admin", nil
}

// IsVendor - بررسی vendor بودن کاربر
func (s *RBACService) IsVendor(userID int) (bool, error) {
	db := database.GetDB()
	var role model.UserRole
	
	err := db.Where("user_id = ?", userID).First(&role).Error
	if err != nil {
		if database.IsNotFound(err) {
			return false, nil
		}
		return false, err
	}
	
	return role.Role == "vendor", nil
}

// GetUserRole - دریافت نقش کاربر
func (s *RBACService) GetUserRole(userID int) (string, error) {
	db := database.GetDB()
	var role model.UserRole
	
	err := db.Where("user_id = ?", userID).First(&role).Error
	if err != nil {
		if database.IsNotFound(err) {
			return "", ErrUserNotFound
		}
		return "", err
	}
	
	return role.Role, nil
}

// HasInboundAccess - بررسی دسترسی به inbound
func (s *RBACService) HasInboundAccess(userID, inboundID int) (bool, error) {
	// اگر admin باشد، دسترسی کامل دارد
	isAdmin, err := s.IsAdmin(userID)
	if err != nil {
		return false, err
	}
	if isAdmin {
		return true, nil
	}
	
	// بررسی دسترسی vendor
	db := database.GetDB()
	var access model.InboundAccess
	
	err = db.Where("user_id = ? AND inbound_id = ?", userID, inboundID).
		First(&access).Error
	
	if err != nil {
		if database.IsNotFound(err) {
			return false, nil
		}
		return false, err
	}
	
	return true, nil
}

// GetVendorInbounds - دریافت لیست inbound های یک vendor
func (s *RBACService) GetVendorInbounds(userID int) ([]int, error) {
	db := database.GetDB()
	var accesses []model.InboundAccess
	
	err := db.Where("user_id = ?", userID).Find(&accesses).Error
	if err != nil {
		return nil, err
	}
	
	inboundIDs := make([]int, len(accesses))
	for i, access := range accesses {
		inboundIDs[i] = access.InboundID
	}
	
	return inboundIDs, nil
}

// GrantInboundAccess - دادن دسترسی به vendor
func (s *RBACService) GrantInboundAccess(adminID, userID, inboundID int) error {
	// بررسی admin بودن
	isAdmin, err := s.IsAdmin(adminID)
	if err != nil {
		return err
	}
	if !isAdmin {
		return ErrUnauthorized
	}
	
	// بررسی vendor بودن کاربر
	isVendor, err := s.IsVendor(userID)
	if err != nil {
		return err
	}
	if !isVendor {
		return ErrInvalidRole
	}
	
	// بررسی عدم وجود دسترسی قبلی
	hasAccess, err := s.HasInboundAccess(userID, inboundID)
	if err != nil {
		return err
	}
	if hasAccess {
		return ErrDuplicateAccess
	}
	
	// ایجاد دسترسی جدید
	db := database.GetDB()
	access := model.InboundAccess{
		UserID:    userID,
		InboundID: inboundID,
		GrantedBy: adminID,
	}
	
	return db.Create(&access).Error
}

// RevokeInboundAccess - گرفتن دسترسی از vendor
func (s *RBACService) RevokeInboundAccess(adminID, userID, inboundID int) error {
	// بررسی admin بودن
	isAdmin, err := s.IsAdmin(adminID)
	if err != nil {
		return err
	}
	if !isAdmin {
		return ErrUnauthorized
	}
	
	db := database.GetDB()
	return db.Where("user_id = ? AND inbound_id = ?", userID, inboundID).
		Delete(&model.InboundAccess{}).Error
}

// CreateVendor - ساخت vendor جدید
func (s *RBACService) CreateVendor(adminID int, username, password string, inboundIDs []int) error {
	// بررسی admin بودن
	isAdmin, err := s.IsAdmin(adminID)
	if err != nil {
		return err
	}
	if !isAdmin {
		return ErrUnauthorized
	}
	
	db := database.GetDB()
	
	// شروع تراکنش
	tx := db.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()
	
	// ساخت کاربر
	userService := &UserService{}
	user, err := userService.CreateUser(username, password)
	if err != nil {
		tx.Rollback()
		return err
	}
	
	// ایجاد نقش vendor
	role := model.UserRole{
		UserID: user.ID,
		Role:   "vendor",
	}
	if err := tx.Create(&role).Error; err != nil {
		tx.Rollback()
		return err
	}
	
	// اضافه کردن دسترسی‌های inbound
	for _, inboundID := range inboundIDs {
		access := model.InboundAccess{
			UserID:    user.ID,
			InboundID: inboundID,
			GrantedBy: adminID,
		}
		if err := tx.Create(&access).Error; err != nil {
			tx.Rollback()
			return err
		}
	}
	
	return tx.Commit().Error
}

// DeleteVendor - حذف vendor
func (s *RBACService) DeleteVendor(adminID, vendorID int) error {
	// بررسی admin بودن
	isAdmin, err := s.IsAdmin(adminID)
	if err != nil {
		return err
	}
	if !isAdmin {
		return ErrUnauthorized
	}
	
	// بررسی vendor بودن کاربر هدف
	isVendor, err := s.IsVendor(vendorID)
	if err != nil {
		return err
	}
	if !isVendor {
		return errors.New("target user is not a vendor")
	}
	
	// حذف کاربر (cascade delete نقش و دسترسی‌ها را حذف می‌کند)
	userService := &UserService{}
	return userService.DeleteUser(vendorID)
}

// GetAllVendors - دریافت لیست تمام vendor ها
func (s *RBACService) GetAllVendors() ([]model.User, error) {
	db := database.GetDB()
	var roles []model.UserRole
	
	err := db.Where("role = ?", "vendor").Preload("User").Find(&roles).Error
	if err != nil {
		return nil, err
	}
	
	vendors := make([]model.User, len(roles))
	for i, role := range roles {
		vendors[i] = role.User
	}
	
	return vendors, nil
}

// FilterInboundsByAccess - فیلتر inbound ها بر اساس دسترسی
func (s *RBACService) FilterInboundsByAccess(userID int, inbounds []model.Inbound) ([]model.Inbound, error) {
	isAdmin, err := s.IsAdmin(userID)
	if err != nil {
		return nil, err
	}
	
	// admin همه inbound ها را می‌بیند
	if isAdmin {
		return inbounds, nil
	}
	
	// دریافت inbound های مجاز vendor
	allowedIDs, err := s.GetVendorInbounds(userID)
	if err != nil {
		return nil, err
	}
	
	// فیلتر کردن
	filtered := make([]model.Inbound, 0)
	for _, inbound := range inbounds {
		for _, allowedID := range allowedIDs {
			if inbound.ID == allowedID {
				filtered = append(filtered, inbound)
				break
			}
		}
	}
	
	return filtered, nil
}