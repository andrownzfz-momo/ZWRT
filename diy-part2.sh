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

echo "diy-part2: .config ready"
