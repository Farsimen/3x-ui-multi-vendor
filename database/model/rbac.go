package model

import (
	"time"
	"gorm.io/gorm"
)

// UserRole - جدول نقش‌های کاربران
type UserRole struct {
	ID        int            `json:"id" gorm:"primaryKey;autoIncrement"`
	UserID    int            `json:"userId" gorm:"uniqueIndex;not null"`
	Role      string         `json:"role" gorm:"type:varchar(20);not null;check:role IN ('admin', 'vendor')"`
	CreatedAt time.Time      `json:"createdAt"`
	UpdatedAt time.Time      `json:"updatedAt"`
	DeletedAt gorm.DeletedAt `json:"-" gorm:"index"`
	
	User User `json:"-" gorm:"foreignKey:UserID;constraint:OnDelete:CASCADE"`
}

// InboundAccess - جدول دسترسی‌های vendor به inbound ها
type InboundAccess struct {
	ID        int            `json:"id" gorm:"primaryKey;autoIncrement"`
	UserID    int            `json:"userId" gorm:"not null;index:idx_user_inbound"`
	InboundID int            `json:"inboundId" gorm:"not null;index:idx_user_inbound"`
	GrantedAt time.Time      `json:"grantedAt"`
	GrantedBy int            `json:"grantedBy"` // ID ادمینی که دسترسی داده
	DeletedAt gorm.DeletedAt `json:"-" gorm:"index"`
	
	User    User    `json:"-" gorm:"foreignKey:UserID;constraint:OnDelete:CASCADE"`
	Inbound Inbound `json:"-" gorm:"foreignKey:InboundID;constraint:OnDelete:CASCADE"`
}

// TableName - نام جدول
func (UserRole) TableName() string {
	return "user_roles"
}

func (InboundAccess) TableName() string {
	return "inbound_access"
}

// BeforeCreate - تنظیم زمان قبل از ساخت
func (r *UserRole) BeforeCreate(tx *gorm.DB) error {
	r.CreatedAt = time.Now()
	r.UpdatedAt = time.Now()
	return nil
}

func (a *InboundAccess) BeforeCreate(tx *gorm.DB) error {
	a.GrantedAt = time.Now()
	return nil
}