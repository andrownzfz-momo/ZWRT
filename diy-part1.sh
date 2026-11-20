#!/bin/sh
# diy-part1.sh - append third-party feeds for ZWRT RE-SS-01 build.
#
# Reverse-engineered from the QWRT R25.11.11 apk database
# (/lib/apk/db/installed, 541 packages): every package NOT provided by the
# ZWRT base tree or its default feeds was traced to its origin. This list
# reproduces QWRT's exact package sources:
#
#   feeds/base/helloworld/...          -> fw876/helloworld
#       luci-app-ssr-plus, mosdns, shadowsocksr-libev
#   feeds/base/luci-app-mosdns/...     -> sbwml/luci-app-mosdns
#       luci-app-mosdns, geo2txt
#   feeds/base/luci-app-turboacc       -> chenmozhijin/turboacc (branch luci)
#   feeds/base/luci-app-wolplus        -> animegasan/luci-app-wolplus
#   package/luci-app-nssstatus         -> shadowvershh/luci-app-nssstatus
#       VENDORED into package/ (no feed line): its Makefile sits at the
#       repo root, which the feeds index generator cannot scan - both
#       ZWRT and official trees printed "Ignoring feed ... index missing"
#       and silently dropped the package (runs 44695899864, 44728156638).
#
# Already covered by ZWRT default feeds (do NOT re-add):
#   luci feed     -> passwall, homeproxy, dockerman, nlbwmon, autoreboot,
#                    aria2, cpufreq, package-manager, nfs, samba4, sqm,
#                    firewall, luci-i18n-*
#   packages feed -> xray-core, sing-box, chinadns-ng, dns2socks, dns2tcp,
#                    microsocks, ipt2socks, v2ray-geodata, v2ray-plugin,
#                    tcping, simple-obfs, etherwake, adguardhome, dockerd
#   base tree     -> emortal (autocore/automount/cpufreq/default-settings),
#                    shellsync, fullconenat-nft, ath11k-firmware, ipq-wifi
#
# Feed order matters: earlier feeds win on duplicate package names, so
# helloworld is listed before luci-mosdns (QWRT resolved mosdns to
# helloworld/mosdns) and after the default feeds (QWRT resolved
# chinadns-ng/tcping/xray-core etc. to feeds/packages).
set -e

# scripts/feeds parses feed names with \w+ (no hyphens allowed), so this
# feed is named mosdns_luci instead of luci-mosdns.
cat >> feeds.conf.default <<'EOF'
src-git helloworld https://github.com/fw876/helloworld.git
src-git mosdns_luci https://github.com/sbwml/luci-app-mosdns.git
src-git turboacc https://github.com/chenmozhijin/turboacc.git;luci
src-git wolplus https://github.com/animegasan/luci-app-wolplus.git
EOF

echo "diy-part1: feeds.conf.default updated"
cat feeds.conf.default
