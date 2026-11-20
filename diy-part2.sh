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

echo "diy-part2: .config ready"
