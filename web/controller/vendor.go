package controller

import (
	"net/http"
	"strconv"
	"x-ui/web/service"
	
	"github.com/gin-gonic/gin"
)

type VendorController struct {
	rbacService *service.RBACService
}

func NewVendorController() *VendorController {
	return &VendorController{
		rbacService: &service.RBACService{},
	}
}

// CreateVendor - ساخت vendor جدید
func (vc *VendorController) CreateVendor(c *gin.Context) {
	var req struct {
		Username   string `json:"username" binding:"required"`
		Password   string `json:"password" binding:"required"`
		InboundIDs []int  `json:"inboundIds"`
	}
	
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": err.Error()})
		return
	}
	
	adminID := getUserID(c)
	err := vc.rbacService.CreateVendor(adminID, req.Username, req.Password, req.InboundIDs)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": err.Error()})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{"success": true, "msg": "vendor created successfully"})
}

// ListVendors - لیست vendor ها
func (vc *VendorController) ListVendors(c *gin.Context) {
	vendors, err := vc.rbacService.GetAllVendors()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": err.Error()})
		return
	}
	
	// حذف password از خروجی
	for i := range vendors {
		vendors[i].Password = ""
	}
	
	c.JSON(http.StatusOK, gin.H{"success": true, "obj": vendors})
}

// DeleteVendor - حذف vendor
func (vc *VendorController) DeleteVendor(c *gin.Context) {
	vendorIDStr := c.Param("id")
	vendorID, err := strconv.Atoi(vendorIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "invalid vendor id"})
		return
	}
	
	adminID := getUserID(c)
	err = vc.rbacService.DeleteVendor(adminID, vendorID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": err.Error()})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{"success": true, "msg": "vendor deleted successfully"})
}

// GrantAccess - دادن دسترسی به inbound
func (vc *VendorController) GrantAccess(c *gin.Context) {
	var req struct {
		VendorID  int `json:"vendorId" binding:"required"`
		InboundID int `json:"inboundId" binding:"required"`
	}
	
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": err.Error()})
		return
	}
	
	adminID := getUserID(c)
	err := vc.rbacService.GrantInboundAccess(adminID, req.VendorID, req.InboundID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": err.Error()})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{"success": true, "msg": "access granted"})
}

// RevokeAccess - گرفتن دسترسی از inbound
func (vc *VendorController) RevokeAccess(c *gin.Context) {
	var req struct {
		VendorID  int `json:"vendorId" binding:"required"`
		InboundID int `json:"inboundId" binding:"required"`
	}
	
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": err.Error()})
		return
	}
	
	adminID := getUserID(c)
	err := vc.rbacService.RevokeInboundAccess(adminID, req.VendorID, req.InboundID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": err.Error()})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{"success": true, "msg": "access revoked"})
}

// GetVendorInbounds - دریافت inbound های یک vendor
func (vc *VendorController) GetVendorInbounds(c *gin.Context) {
	vendorIDStr := c.Param("id")
	vendorID, err := strconv.Atoi(vendorIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "invalid vendor id"})
		return
	}
	
	inboundIDs, err := vc.rbacService.GetVendorInbounds(vendorID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": err.Error()})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{"success": true, "obj": inboundIDs})
}

// getUserID - دریافت user ID از session
func getUserID(c *gin.Context) int {
	// این تابع باید با توجه به سیستم session موجود در 3X-UI پیاده‌سازی شود
	// فرض بر این است که user ID در context ذخیره شده است
	userID, exists := c.Get("user_id")
	if !exists {
		return 0
	}
	return userID.(int)
}