#!/bin/sh
# diy-part2.sh - fix up .config before defconfig.
#
# QWRT's apk db shows apk-openssl (origin feeds/base/system/apk) and the
# exported config selects CONFIG_PACKAGE_apk-openssl=y only - keep it, it is
# the same provider QWRT shipped. No mbedtls conflict exists.
#
# The Design theme line is already in configs/zwrt-re-ss-01.config; this is
# only a safety net in case the config file is ever regenerated without it.
set -e

grep -q '^CONFIG_PACKAGE_luci-theme-design=y' .config ||
	echo 'CONFIG_PACKAGE_luci-theme-design=y' >> .config

grep -q '^CONFIG_PACKAGE_apk-openssl=y' .config ||
	echo 'CONFIG_PACKAGE_apk-openssl=y' >> .config

# Official OpenWrt 25.12 has USE_APK=y which *implies* apk-mbedtls; together
# with our apk-openssl selection that would ship two apk providers and break
# image assembly. `imply` is weak, so an explicit =n wins on both trees
# (unknown symbol on LiBwrt is dropped silently by defconfig). Keeps the
# single-provider apk-openssl setup QWRT shipped.
grep -q '^CONFIG_PACKAGE_apk-mbedtls=n' .config ||
	echo 'CONFIG_PACKAGE_apk-mbedtls=n' >> .config

# shadowsocks-rust pulls in the "rust" host toolchain. immortalwrt's
# lang/rust Makefile ships with llvm.download-ci-llvm=true, which fetches a
# prebuilt LLVM from ci-artifacts.rust-lang.org - those artifacts get purged
# and the download now 404s ("ERROR: failed to download llvm from ci",
# run 44695899864). Force LLVM to build from the bundled sources instead,
# which is what upstream openwrt/packages does. No-op when the flag is
# already false or the file is absent.
[ -f feeds/packages/lang/rust/Makefile ] &&
	sed -i 's/llvm.download-ci-llvm=true/llvm.download-ci-llvm=false/' \
		feeds/packages/lang/rust/Makefile

# --- Services menu order (user spec: ssr > homeproxy > passwall > mosdns) ---
# LuCI sorts siblings by ascending order value; negative orders pin these
# four to the top of the Services menu regardless of what other apps ship
# (passwall already ships -1, proving negative orders work). Fail loudly
# when a feed restructures any of these files so the order can never
# silently regress.
SSR=feeds/helloworld/luci-app-ssr-plus/luasrc/controller/shadowsocksr.lua
HP=feeds/luci/applications/luci-app-homeproxy/root/usr/share/luci/menu.d/luci-app-homeproxy.json
PW=feeds/luci/applications/luci-app-passwall/luasrc/controller/passwall.lua
MD=feeds/mosdns_luci/luci-app-mosdns/root/usr/share/luci/menu.d/luci-app-mosdns.json
[ -f "$SSR" ] || { echo "::error::missing $SSR"; exit 1; }
sed -i 's/("ShadowSocksR Plus+"), *10)/("ShadowSocksR Plus+"), -40)/' "$SSR"
grep -q '("ShadowSocksR Plus+"), -40)' "$SSR" || { echo "::error::ssr-plus menu order patch failed"; exit 1; }
[ -f "$HP" ] || { echo "::error::missing $HP"; exit 1; }
sed -i '0,/"order": *10/s//"order": -30/' "$HP"
grep -q '"order": -30' "$HP" || { echo "::error::homeproxy menu order patch failed"; exit 1; }
[ -f "$PW" ] || { echo "::error::missing $PW"; exit 1; }
sed -i 's/("Pass Wall"), *-1)/("Pass Wall"), -20)/; s/"settings"), *nil, *-1)/"settings"), nil, -20)/' "$PW"
grep -q '("Pass Wall"), -20)' "$PW" || { echo "::error::passwall menu order patch failed"; exit 1; }
[ -f "$MD" ] || { echo "::error::missing $MD"; exit 1; }
sed -i '0,/"order": *30/s//"order": -10/' "$MD"
grep -q '"order": -10' "$MD" || { echo "::error::mosdns menu order patch failed"; exit 1; }

echo "diy-part2: .config ready"
