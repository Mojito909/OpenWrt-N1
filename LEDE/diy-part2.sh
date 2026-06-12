#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#


# ==================== 基础配置 ====================

# TTYD 免登录
sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

# 修改默认主题 (bootstrap -> argon)
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' ./feeds/luci/collections/luci/Makefile

# 修复日期替换
sed -i "s|OpenWrt |LEDE Build $(TZ=UTC-8 date '+%Y.%m.%d') @ OpenWrt |g" package/lean/default-settings/files/zzz-default-settings

# 修复软件源URL替换
sed -i 's#openwrt.proxy.ustclug.org#mirrors.bfsu.edu.cn/openwrt#g' package/lean/default-settings/files/zzz-default-settings

# 修改默认IP地址
sed -i 's/192.168.1.1/192.168.1.10/g' package/base-files/files/bin/config_generate

# 修改系统主机名 (LEDE -> OpenWrt-N1)
sed -i 's/LEDE/OpenWrt-N1/g' package/base-files/files/bin/config_generate

# 修改Samba配置（允许root访问）
sed -i 's/invalid users = root/#invalid users = root/g' feeds/packages/net/samba4/files/smb.conf.template

# 修复插件自启动脚本权限
sed -i '/exit 0/i\chmod +x /etc/init.d/*' package/lean/default-settings/files/zzz-default-settings

# 修改概览时间显示为中文
sed -i 's/os.date()/os.date("%Y年%m月%d日") .. " " .. translate(os.date("%A")) .. " " .. os.date("%X")/g' package/lean/autocore/files/arm/index.htm


# ==================== 主题配置 ====================

# 拉取 Argon 主题
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf package/small-package/luci-app-argon*
rm -rf package/small-package/luci-theme-argon*
git clone -b 18.06 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config
git clone -b 18.06 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon

# 更改 Argon 主题背景
if [ -f "$GITHUB_WORKSPACE/images/bg1.jpg" ]; then
    cp -f "$GITHUB_WORKSPACE/images/bg1.jpg" package/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg
else
    echo "警告: 背景图片文件不存在，跳过复制"
fi

# 移除主题页脚版本信息
sed -i 's/<a class="luci-link" href="https:\/\/github.com\/openwrt\/luci"/<a/g' feeds/luci/themes/luci-theme-argon/luasrc/view/themes/argon/footer.htm
sed -i 's/<a href="https:\/\/github.com\/jerrykuku\/luci-theme-argon" target="_blank">/<a>/g' feeds/luci/themes/luci-theme-argon/luasrc/view/themes/argon/footer.htm
sed -i 's/<a href=\"https:\/\/github.com\/coolsnowwolf\/luci\">/<a>/g' feeds/luci/themes/luci-theme-bootstrap/luasrc/view/themes/bootstrap/footer.htm


# ==================== 插件安装 ====================

# 在线用户
git clone --depth=1 https://github.com/danchexiaoyang/luci-app-onliner.git package/luci-app-onliner

# 通知插件
git clone https://github.com/tty228/luci-app-serverchan.git package/luci-app-serverchan

# 晶晨宝盒
rm -rf package/custom/luci-app-amlogic
rm -rf package/luci-app-amlogic
rm -rf package/small-package/luci-app-amlogic
git clone -b main https://github.com/ophub/luci-app-amlogic.git package/luci-app-amlogic

# AdGuardHome
rm -rf package/luci-app-adguardhome
git clone --depth=1 https://github.com/rufengsuixing/luci-app-adguardhome.git package/luci-app-adguardhome

# HomeProxy
rm -rf package/luci-app-homeproxy
git clone https://github.com/immortalwrt/homeproxy package/luci-app-homeproxy

# SmartDNS
git clone --depth=1 -b lede https://github.com/pymumu/luci-app-smartdns package/luci-app-smartdns
git clone --depth=1 https://github.com/pymumu/openwrt-smartdns package/smartdns

# Alist
rm -rf package/luci-app-alist
git clone --depth=1 https://github.com/sbwml/luci-app-alist package/alist


# ==================== 依赖修复 ====================

# 修复 v2ray-geodata 依赖
rm -rf feeds/packages/net/v2ray-geodata
rm -rf package/feeds/packages/v2ray-geodata
git clone https://github.com/sbwml/v2ray-geodata package/v2ray-geodata

# 修复循环依赖问题
sed -i 's|depends on iptables|depends on iptables \&\& !PACKAGE_luci-app-passwall_Iptables_Transparent_Proxy|g' feeds/small/luci-app-bypass/Makefile 2>/dev/null || true
sed -i 's|select natmap|select natmap \&\& !PACKAGE_natmap|g' feeds/small/natmap/Makefile 2>/dev/null || true
sed -i 's|depends on baresip-mod-avcodec|depends on baresip-mod-avcodec \&\& !PACKAGE_baresip-mod-avformat|g' feeds/packages/net/baresip-mod-avformat/Makefile 2>/dev/null || true
sed -i 's|select miniupnpd|select miniupnpd \&\& !PACKAGE_miniupnpd|g' feeds/packages/net/miniupnpd/Makefile 2>/dev/null || true
sed -i 's|depends on tor|depends on tor \&\& !PACKAGE_luci-app-torbp|g' feeds/small/luci-app-torbp/Makefile 2>/dev/null || true
sed -i 's|select mentohust|select mentohust \&\& !PACKAGE_mentohust|g' feeds/packages/net/mentohust/Makefile 2>/dev/null || true
sed -i 's|select kmod-oaf|select kmod-oaf \&\& !PACKAGE_kmod-oaf|g' feeds/packages/kernel/kmod-oaf/Makefile 2>/dev/null || true
sed -i 's|depends on luci-app-passwall|depends on luci-app-passwall \&\& !PACKAGE_luci-app-ssr-plus|g' feeds/small/luci-app-passwall/Makefile 2>/dev/null || true
sed -i 's|depends on luci-app-ssr-plus|depends on luci-app-ssr-plus \&\& !PACKAGE_luci-app-passwall|g' feeds/small/luci-app-ssr-plus/Makefile 2>/dev/null || true

# golang版本修复
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang

# 修复 hostapd 报错
cp -f "$GITHUB_WORKSPACE/scripts/011-fix-mbo-modules-build.patch" package/network/services/hostapd/patches/011-fix-mbo-modules-build.patch 2>/dev/null || true

# 修复 armv8 设备 xfsprogs 报错
sed -i 's/TARGET_CFLAGS.*/TARGET_CFLAGS += -DHAVE_MAP_SYNC -D_LARGEFILE64_SOURCE/g' feeds/packages/utils/xfsprogs/Makefile

# MosDNS
find ./ | grep Makefile | grep v2ray-geodata | xargs rm -f
find ./ | grep Makefile | grep mosdns | xargs rm -f
rm -rf feeds/packages/net/mosdns feeds/packages/net/v2ray-geodata
git clone https://github.com/sbwml/luci-app-mosdns package/mosdns
git clone https://github.com/sbwml/v2ray-geodata package/geodata


# ==================== NPS 配置 ====================

# 更新 nps 源
rm -rf feeds/packages/net/nps
git clone --depth=1 https://github.com/immortalwrt/packages feeds/packages_temp
cp -rf feeds/packages_temp/net/nps feeds/packages/net/nps
rm -rf feeds/packages_temp

# 修改 nps 服务器允许域名
sed -i 's/^server.datatype = "ipaddr"/--server.datatype = "ipaddr"/g' feeds/luci/applications/luci-app-nps/luasrc/model/cbi/nps.lua
sed -i 's/Must an IPv4 address/IPv4 address or domain name/g' feeds/luci/applications/luci-app-nps/luasrc/model/cbi/nps.lua
sed -i 's/Must an IPv4 address/IPv4 address or domain name/g' feeds/luci/applications/luci-app-nps/po/zh-cn/nps.po
sed -i 's/必须是 IPv4 地址/IPv4 地址或域名/g' feeds/luci/applications/luci-app-nps/po/zh-cn/nps.po


# ==================== 插件名称修改 ====================

sed -i 's/"Argon 主题设置"/"主题设置"/g' $(grep "Argon 主题设置" -rl ./)
sed -i 's/"AdGuard Home"/"AdGuard"/g' $(grep "AdGuard Home" -rl ./)
sed -i 's/"Aria2 配置"/"Aria2"/g' $(grep "Aria2 配置" -rl ./)
sed -i 's/"实时流量监测"/"流量"/g' $(grep "实时流量监测" -rl ./)
sed -i 's/"Alist 文件列表"/"Alist"/g' $(grep "Alist 文件列表" -rl ./)
sed -i 's/"挂载点"/"磁盘挂载"/g' $(grep "挂载点" -rl ./)
sed -i 's/"Npc"/"Nps穿透"/g' $(grep "Npc" -rl ./)
sed -i 's/"Frp 内网穿透"/"Frp穿透"/g' $(grep "Frp 内网穿透" -rl ./)
sed -i 's/"FTP 服务器"/"FTP服务器"/g' $(grep "FTP 服务器" -rl ./)
sed -i 's/"TTYD 终端"/"终端"/g' $(grep "TTYD 终端" -rl ./)
sed -i 's/"网络存储"/"存储"/g' $(grep "网络存储" -rl ./)
sed -i 's/"NPS 内网穿透客户端"/"NPS穿透"/g' $(grep "NPS 内网穿透客户端" -rl ./)
sed -i 's/"ShadowSocksR Plus+"/"SSR Plus+"/g' $(grep "ShadowSocksR Plus+" -rl ./)


# ==================== 界面文字修改 ====================

sed -i '/msgstr/s/"带宽监控"/"监视"/g' feeds/luci/applications/luci-app-nlbwmon/po/zh-cn/nlbwmon.po
sed -i '/msgid "Reboot"/{n;s/msgstr "重启"/msgstr "重启设备"/;}' feeds/luci/modules/luci-base/po/zh-cn/base.po


# ==================== 清理删除 ====================

# 清除 coremark 定时任务
sed -i '/\* \* \* \/etc\/coremark.sh/d' feeds/packages/utils/coremark/*

# 删除冲突/问题插件
rm -rf feeds/luci/applications/luci-app-qbittorrent
rm -rf feeds/packages/net/qBittorrent-static
rm -rf feeds/packages/net/qBittorrent
rm -rf package/small-package/luci-app-netdata
rm -rf feeds/luci/applications/luci-app-mia
rm -rf feeds/small/luci-app-mia
rm -rf package/feeds/luci/luci-app-mia
rm -rf package/feeds/small/luci-app-mia
rm -rf package/small-package/luci-app-mia
rm -rf package/luci-app-mia
rm -rf small/{luci-app-bypass,luci-app-fchomo}