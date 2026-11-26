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
# (unknown symbol on the ZWRT tree is dropped silently by defconfig). Keeps the
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

# --- Kernel config completeness: olddefconfig after .config assembly ---
# CONFIG_COMPAT=y (adbyby armv7) newly exposes symbols that the config
# fragments never wrote a value for (COMPAT_ALIGNMENT_FIXUPS, ...); the
# build-stage syncconfig then prompts for them interactively ("Restart
# config...") and dies in CI. olddefconfig fills new symbols with their
# defaults, no prompting. Idempotent: ZWRT's own include/ already carries
# the line; the owrt line grafts stock openwrt/include/ which does not.
KD=include/kernel-defaults.mk
if ! grep -q 'olddefconfig' "$KD"; then
	python3 - "$KD" <<'PYEOF'
import re, sys
p = sys.argv[1]
s = open(p).read()
m = re.search(r'([ \t]+)cp \$\(LINUX_DIR\)/\.config\.set \$\(LINUX_DIR\)/\.config\.prev; \\\n', s)
if not m:
    print(f"::error::olddefconfig anchor missing in {p}")
    sys.exit(1)
s = s[:m.end()] + m.group(1) + "$(_SINGLE) $(KERNEL_MAKE) olddefconfig; \\\n" + s[m.end():]
open(p, "w").write(s)
print(f"patched {p}: olddefconfig added after .config copy")
PYEOF
fi
grep -q 'olddefconfig' "$KD" || { echo "::error::olddefconfig missing in $KD"; exit 1; }

# --- apk rejects the upstream adbyby-plus version string ---
# kongfl888's luci-app-adbyby-plus ships PKG_VERSION:=2.0K5 and apk
# mkpkg dies with "package version is invalid" (Error 99). apk's version
# grammar is digit{.digit}...{letter}{_suf}...{~hash}{-r#}: uppercase is
# rejected outright, and a naive lowercase (2.0k5) is ALSO invalid because
# a digit may not follow the single letter. Force a plain numeric version
# instead; fail loudly if the feed drops the variable.
AD=feeds/adbybyplus/luci-app-adbyby-plus/Makefile
[ -f "$AD" ] || { echo "::error::missing $AD"; exit 1; }
sed -i 's/^PKG_VERSION:=.*/PKG_VERSION:=2.0.5/' "$AD"
grep -q '^PKG_VERSION:=2.0.5$' "$AD" || { echo "::error::adbyby-plus PKG_VERSION patch failed"; exit 1; }

# --- ZWRT brand + firmware filename prefix (idempotent, both trees) ---
# The owrt line runs this inside openwrt/ against stock files (OpenWrt
# defaults); the main line is already ZWRT in-tree, so the seds are no-ops.
sed -i 's/,OpenWrt)$/,ZWRT)/g' include/version.mk
grep -q ',ZWRT)' include/version.mk || { echo "::error::version.mk brand patch failed"; exit 1; }

sed -i "s/hostname='OpenWrt'/hostname='ZWRT'/g" package/base-files/files/bin/config_generate
grep -q "hostname='ZWRT'" package/base-files/files/bin/config_generate || { echo "::error::hostname brand patch failed"; exit 1; }

sed -i 's/"OpenWrt"}/"ZWRT"}/g' package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc
grep -q '"ZWRT"}' package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc || { echo "::error::SSID brand patch failed"; exit 1; }

# sanitize() lowercases VERSION_DIST, so the mixed-case filename prefix
# cannot ride on CONFIG_VERSION_DIST; rewrite IMG_PREFIX directly.
sed -i 's|^IMG_PREFIX:=.*|IMG_PREFIX:=JDcloud-AX1800pro-ZWRT-$(IMG_PREFIX_VERNUM)$(IMG_PREFIX_VERCODE)$(IMG_PREFIX_EXTRA)$(BOARD)-$(SUBTARGET)|' include/image.mk
grep -q '^IMG_PREFIX:=JDcloud-AX1800pro-ZWRT-' include/image.mk || { echo "::error::IMG_PREFIX patch failed"; exit 1; }

# --- cellular menu: rename 3ginfo-lite top menu to 蜂窝网络 ---
# luci-app-3ginfo-lite ships the only modem status menu; its stock title is
# "Modem" (zh: 模块). Rewrite the menu.d title so the LuCI nav bar shows
# 蜂窝网络. Runs after feeds install on both lines (cwd = tree root / openwrt/).
MENU=feeds/luci/applications/luci-app-3ginfo-lite/root/usr/share/luci/menu.d/luci-app-3ginfo-lite.json
[ -f "$MENU" ] || { echo "::error::3ginfo-lite menu.d missing: $MENU"; exit 1; }
sed -i 's/"title": "Modem"/"title": "蜂窝网络"/' "$MENU"
grep -q '"title": "蜂窝网络"' "$MENU" || { echo "::error::cellular menu rename failed"; exit 1; }

# --- turboacc: rename menuconfig prompt "Include BBR CCA" -> "Enable BBR CCA" ---
# chenmozhijin's turboacc (pinned feed) exposes the option as "Include BBR CCA";
# rename the prompt so menuconfig literally offers "Enable BBR CCA". Prompt-only
# change - the Kconfig symbol name is untouched, so the seed config line
# CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_BBR_CCA=y keeps working.
TA=feeds/turboacc/luci-app-turboacc/Makefile
[ -f "$TA" ] || { echo "::error::turboacc Makefile missing: $TA"; exit 1; }
sed -i 's/bool "Include BBR CCA"/bool "Enable BBR CCA"/' "$TA"
grep -q 'bool "Enable BBR CCA"' "$TA" || { echo "::error::BBR CCA prompt rename failed"; exit 1; }

# --- adbyby-plus: po/zh-cn -> po/zh_Hans so the Chinese translation builds ---
# luci.mk only emits luci-i18n-* packages for po/* dirs that are keys in its
# LUCI_LANG table; "zh-cn" is NOT a key (zh_Hans is, with zh-cn as an alias),
# so the feed's legacy po/zh-cn produced no i18n package at all and the seed's
# CONFIG_PACKAGE_luci-i18n-adbyby-plus-zh-cn=y was silently dropped by
# defconfig - the UI stayed English. Renaming makes it follow the exact same
# path as luci-i18n-base-zh-cn etc. Idempotent.
ABPO=feeds/adbybyplus/luci-app-adbyby-plus/po
if [ -d "$ABPO/zh-cn" ] && [ ! -d "$ABPO/zh_Hans" ]; then
	mv "$ABPO/zh-cn" "$ABPO/zh_Hans"
fi
[ -f "$ABPO/zh_Hans/adbyby.po" ] || { echo "::error::adbyby zh_Hans/adbyby.po missing"; exit 1; }

# Force scan.mk to re-dump this package: `feeds install` runs prepare-tmpinfo
# (get_installed -> make prepare-tmpinfo) BEFORE diy-part2, so tmp/info/ may
# already hold a DUMP=1 taken while po/ was still named zh-cn (no i18n symbol
# generated - zh-cn is not a LUCI_LANG key). Renaming the po dir does NOT
# touch the Makefile, so scan.mk's mtime rule would keep that stale dump and
# the next defconfig would silently drop
# CONFIG_PACKAGE_luci-i18n-adbyby-plus-zh-cn. Deleting the per-package dump,
# the merged metadata and the generated Kconfig forces a fresh parse (with
# po/zh_Hans) at the next `make defconfig`. Harmless if tmp/ does not exist.
rm -f tmp/.packageinfo tmp/.config-package.in tmp/info/.packageinfo-*adbybyplus*

# --- 3ginfo-lite: no-modem JSON must not crash the 蜂窝网络 page ---
# With no modem attached 3ginfo.sh prints {"error":"Device not found"};
# stock SIMdata() does sdata.simslot.length on that object and the whole view
# dies with "TypeError: Cannot read properties of undefined (reading 'length')".
# Guard the parse, default missing fields, and surface the script error as a
# notification instead of a blank crash page. Anchors verified unique.
G3=feeds/luci/applications/luci-app-3ginfo-lite/htdocs/luci-static/resources/view/modem/3gdetail.js
[ -f "$G3" ] || { echo "::error::3gdetail.js missing: $G3"; exit 1; }
if ! grep -q "sdata\[k\] == null" "$G3"; then
python3 - "$G3" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()

def rep(s, old, new):
    n = s.count(old)
    if n != 1:
        print(f"::error::anchor count={n} (want 1) in {p}: {old!r}")
        sys.exit(1)
    return s.replace(old, new, 1)

s = rep(s, "\tvar sdata = JSON.parse(data);\n",
    "\tvar sdata = {};\n"
    "\ttry { sdata = JSON.parse(data) || {}; } catch (e) { sdata = {}; }\n"
    "\t['simslot', 'imsi', 'iccid', 'imei'].forEach(function(k) {\n"
    "\t\tif (sdata[k] == null) sdata[k] = '';\n"
    "\t});\n")
# Preserve the original (always-false for present imei) semantics; only stop
# the crash when the script omitted imei entirely.
s = rep(s, "if (!json.imei.length > 2) {",
    "if (json.imei == null || !json.imei.length > 2) {")
s = rep(s, "var json = JSON.parse(data);",
    "var json = JSON.parse(data);\n"
    "\t\t\tif (json && json.error) {\n"
    "\t\t\t\tui.addNotification(null, E('p', {}, json.error), 'error');\n"
    "\t\t\t}")
open(p, "w", encoding="utf-8", newline="").write(s)
print(f"patched {p}: no-modem JSON guards + error notification")
PYEOF
fi
grep -q "sdata\[k\] == null" "$G3" || { echo "::error::3gdetail guard missing after patch"; exit 1; }

# --- dockerman: hide the Env row on the container detail page ---
# The detail view printed every container env var (often secrets); user asked
# to not display it. The create form keeps its Env input - only the read-only
# display row is removed. Anchors verified unique. Idempotent.
DM=feeds/luci/applications/luci-app-dockerman/htdocs/luci-static/resources/view/dockerman/container.js
[ -f "$DM" ] || { echo "::error::dockerman container.js missing: $DM"; exit 1; }
if grep -q "form.DummyValue, 'env'" "$DM"; then
python3 - "$DM" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8-sig").read()
start = s.find("o = s.taboption('info', form.DummyValue, 'env', _('Env'));")
end = s.find("o = s.taboption('info', form.DummyValue, 'ports'")
if start < 0 or end < 0 or end <= start:
    print(f"::error::env row anchors not found in {p}")
    sys.exit(1)
s = s[:start] + s[end:]
open(p, "w", encoding="utf-8", newline="").write(s)
print(f"patched {p}: Env display row removed ({end - start} bytes)")
PYEOF
fi
if grep -q "form.DummyValue, 'env'" "$DM"; then
	echo "::error::dockerman env row still present after patch"
	exit 1
fi

# --- fullcone: repair UCI after flash/upgrade ---
# Root cause of turboacc's "FullCone NAT: NOT RUNNING": fw4 renders
# fullcone rules only when firewall.defaults.fullcone=1, and turboacc's
# init rewrites that value on EVERY boot from turboacc.config.fullcone_nat
# (config_get falls back to "0" when the option is absent). A
# settings-preserved config from older firmware therefore keeps forcing
# fullcone OFF, nft_fullcone never gets referenced, and the status page
# reads refcnt=0 -> NOT RUNNING. uci-defaults run once after each flash
# (deleted on success) and re-assert the firmware default (=on).
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-zwrt-fullcone <<'UCIEOF'
#!/bin/sh
# ZWRT: firmware default = FullCone NAT on; re-assert after (re)flash.
[ -n "$(uci -q get turboacc.config)" ] || uci -q set turboacc.config=turboacc
[ -n "$(uci -q get firewall.@defaults[0])" ] || uci -q add firewall defaults >/dev/null
uci -q set turboacc.config.fullcone_nat='1' &&
uci -q set firewall.@defaults[0].fullcone='1' &&
uci -q commit
UCIEOF
[ -f files/etc/uci-defaults/99-zwrt-fullcone ] || { echo "::error::fullcone uci-defaults write failed"; exit 1; }

echo "diy-part2: .config ready"
