include $(TOPDIR)/rules.mk

PKG_NAME:=luci-theme-design
PKG_VERSION:=1.0
PKG_RELEASE:=20261109-1
PKGARCH:=all

LUCI_TITLE:=LuCI Theme - Design
LUCI_DESCRIPTION:=Design is a clean HTML55 theme for LuCI, based on luci-theme-material and luci-theme-neobird.
LUCI_DEPENDS:=+luci-base

include $(INCLUDE_DIR)/package.mk

define Package/luci-theme-design
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Themes
  TITLE:=$(LUCI_TITLE)
  DEPENDS:=$(LUCI_DEPENDS)
  PKGARCH:=all
endef

define Package/luci-theme-design/description
  $(LUCI_DESCRIPTION)
endef

define Build/Compile
endef

define Package/luci-theme-design/install
	$(CP) $(CURDIR)/files/* $(1)/
endef

$(eval $(call BuildPackage,luci-theme-design))
