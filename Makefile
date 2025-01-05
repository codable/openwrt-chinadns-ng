include $(TOPDIR)/rules.mk

PKG_NAME:=chinadns-ng
PKG_VERSION:=2024.12.22
PKG_RELEASE:=1

https://github.com/zfl9/chinadns-ng/archive/refs/tags/2024.12.22.tar.gz
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/zfl9/chinadns-ng.git
PKG_SOURCE_VERSION:=007de26d76dd777c1fbec2fd8449db75515020b3
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_VERSION).tar.gz
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_VERSION)
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)/$(PKG_SOURCE_SUBDIR)
PKG_MIRROR_HASH:=7e410298fa85117507ad905a4ff491e73352c02542653a413a8ffa4171558e17

PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0

PKG_LICENSE:=GPL-3.0
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=pexcn <pexcn97@gmail.com>

include $(INCLUDE_DIR)/package.mk

define Package/chinadns-ng
	SECTION:=net
	CATEGORY:=Network
	TITLE:=ChinaDNS Next Generation, refactoring with epoll and ipset
	URL:=https://github.com/zfl9/chinadns-ng
	DEPENDS:=+ipset
endef

define Package/chinadns-ng/description
ChinaDNS Next Generation, refactoring with epoll and ipset.
endef

define Package/chinadns-ng/conffiles
/etc/config/chinadns-ng
/etc/chinadns-ng/chnroute.txt
/etc/chinadns-ng/chnroute6.txt
/etc/chinadns-ng/gfwlist.txt
/etc/chinadns-ng/chinalist.txt
endef

MAKE_FLAGS += STATIC=1
ZIG_TARGET:=$(subst openwrt-,,$(REAL_GNU_TARGET_NAME))
MIPS_ARCH:=$(subst -,,$(filter -mips32 -mips32r2 -mips32r3 -mips32r5,$(TARGET_CFLAGS)))
MIPS_SOFT_FP:=$(if $(and $(MIPS_ARCH),$(if -msoft-float,$(TARGET_CFLAGS))),1,0)
ZIG:=$(shell command -v zig)

ifdef MIPS_SOFT_FP

define zig_sh_
#!/bin/bash

argv=("$@")

cmd="${argv[0]}"
file="${argv[1]}"

if [ "$MIPS_M_ARCH" ] && [ "$cmd" = clang ] && [[ "$file" == *.s || "$file" == *.S || "$file" == *.sx ]] && [[ "${argv[*]}" == *" -target mips"* ]]; then
    argv+=("-march=$MIPS_M_ARCH")
    ((MIPS_SOFT_FP)) && argv+=("-msoft-float")
fi

exec zig_ "${argv[@]}"
endef

$(PKG_BUILD_DIR)/zig:
	$(file >$(PKG_BUILD_DIR)/zig,$(value zig_sh_))
	chmod a+x $(PKG_BUILD_DIR)/zig
endif

define Build/Configure
	$(MAKE) $(PKG_BUILD_DIR)/zig
	$(CP) $(ZIG) $(PKG_BUILD_DIR)/zig_
	$(SED) 's@/proc/self/exe@/opt/zig123456@g' $(PKG_BUILD_DIR)/zig_
endef

define Build/Compile
	cd $(PKG_BUILD_DIR) && PATH=$(PKG_BUILD_DIR):$(PATH) MIPS_M_ARCH=$(MIPS_ARCH) MIPS_SOFT_FP=$(MIPS_SOFT_FP) zig build -Dtarget=$(ZIG_TARGET) -Dcpu=$(MIPS_ARCH)+soft_float
endef

define Package/chinadns-ng/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/zig-out/bin/chinadns-ng@* $(1)/usr/bin/chinadns-ng
	$(INSTALL_BIN) files/chinadns-ng-daily.sh $(1)/usr/bin
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) files/chinadns-ng.init $(1)/etc/init.d/chinadns-ng
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) files/chinadns-ng.config $(1)/etc/config/chinadns-ng
	$(INSTALL_DIR) $(1)/etc/chinadns-ng
	$(INSTALL_DATA) files/chnroute.txt $(1)/etc/chinadns-ng
	$(INSTALL_DATA) files/chnroute6.txt $(1)/etc/chinadns-ng
	$(INSTALL_DATA) files/gfwlist.txt $(1)/etc/chinadns-ng
	$(INSTALL_DATA) files/chinalist.txt $(1)/etc/chinadns-ng
endef

define Package/chinadns-ng/postinst
#!/bin/sh
if ! crontab -l | grep -q "chinadns-ng"; then
  (crontab -l; echo -e "# chinadns-ng\n10 3 * * * /usr/bin/chinadns-ng-daily.sh") | crontab -
fi
exit 0
endef

define Package/chinadns-ng/postrm
#!/bin/sh
exec 2>/dev/null
rmdir --ignore-fail-on-non-empty /etc/chinadns-ng
(crontab -l | grep -v "chinadns-ng") | crontab -
exit 0
endef

$(eval $(call BuildPackage,chinadns-ng))
