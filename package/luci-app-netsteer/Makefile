include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-netsteer
PKG_VERSION:=1.22.14
PKG_RELEASE:=1
PKG_LICENSE:=MIT
PKG_MAINTAINER:=pm-parker <https://github.com/pm-parker>
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-netsteer
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=NetSteer network softirq/IRQ steering with auto-benchmark
  DEPENDS:=+luci-base +ip-full +tc +ethtool +curl +jq +nftables
endef

define Package/luci-app-netsteer/description
  Steer network softirq/IRQ across CPU cores (RPS/RFS/XPS), QoS and P2P
  passthrough with automatic A/B benchmarking. LuCI menu entry included.
endef

define Package/luci-app-netsteer/conffiles
/etc/config/netsteer
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-app-netsteer/install
	$(CP) ./files/* $(1)/
	sed -i "s/var NS_VERSION = '[^']*';/var NS_VERSION = '$(PKG_VERSION)';/" $(1)/www/luci-static/resources/view/netsteer.js
	chmod 755 $(1)/usr/bin/netsteer-* $(1)/etc/init.d/netsteer $(1)/etc/hotplug.d/iface/99-netsteer
endef

$(eval $(call BuildPackage,luci-app-netsteer))
