package middleware

import (
	"net/http"
	"strconv"
	"x-ui/web/service"
	
	"github.com/gin-gonic/gin"
)

var rbacService = &service.RBACService{}

// RequireAdmin - Middleware برای محدود کردن به admin
func RequireAdmin() gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := getUserID(c)
		if userID == 0 {
			c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "unauthorized"})
			c.Abort()
			return
		}
		
		isAdmin, err := rbacService.IsAdmin(userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": err.Error()})
			c.Abort()
			return
		}
		
		if !isAdmin {
			c.JSON(http.StatusForbidden, gin.H{"success": false, "msg": "admin access required"})
			c.Abort()
			return
		}
		
		c.Next()
	}
}

// RequireVendorOrAdmin - Middleware برای vendor یا admin
func RequireVendorOrAdmin() gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := getUserID(c)
		if userID == 0 {
			c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "unauthorized"})
			c.Abort()
			return
		}
		
		role, err := rbacService.GetUserRole(userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": err.Error()})
			c.Abort()
			return
		}
		
		if role != "admin" && role != "vendor" {
			c.JSON(http.StatusForbidden, gin.H{"success": false, "msg": "access denied"})
			c.Abort()
			return
		}
		
		c.Set("userRole", role)
		c.Next()
	}
}

// CheckInboundAccess - Middleware برای بررسی دسترسی به inbound
func CheckInboundAccess() gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := getUserID(c)
		if userID == 0 {
			c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "unauthorized"})
			c.Abort()
			return
		}
		
		// دریافت inbound ID از پارامتر یا body
		inboundIDStr := c.Param("id")
		if inboundIDStr == "" {
			inboundIDStr = c.PostForm("id")
		}
		
		inboundID, err := strconv.Atoi(inboundIDStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "invalid inbound id"})
			c.Abort()
			return
		}
		
		hasAccess, err := rbacService.HasInboundAccess(userID, inboundID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": err.Error()})
			c.Abort()
			return
		}
		
		if !hasAccess {
			c.JSON(http.StatusForbidden, gin.H{"success": false, "msg": "no access to this inbound"})
			c.Abort()
			return
		}
		
		c.Next()
	}
}

// getUserID - دریافت user ID از session
func getUserID(c *gin.Context) int {
	// این تابع باید با توجه به سیستم session موجود در 3X-UI پیاده‌سازی شود
	userID, exists := c.Get("user_id")
	if !exists {
		return 0
	}
	return userID.(int)
}