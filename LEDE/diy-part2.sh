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

# TTYD 免登录
TTYD_CONFIG="feeds/packages/utils/ttyd/files/ttyd.config"
if [ -f "$TTYD_CONFIG" ]; then
    sed -i 's|/bin/login|/bin/login -f root|g' "$TTYD_CONFIG"
fi

# Modify default theme（FROM uci-theme-bootstrap CHANGE TO luci-theme-material）
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' ./feeds/luci/collections/luci/Makefile

# Modify some code adaptation
#sed -i 's/LUCI_DEPENDS.*/LUCI_DEPENDS:=\@\(arm\|\|aarch64\)/g' feeds/luci/applications/luci-app-cpufreq/Makefile

# Add autocore support for armvirt
# sed -i 's/TARGET_rockchip/TARGET_rockchip\|\|TARGET_armvirt/g' package/lean/autocore/Makefile

# 修复日期替换
sed -i "s|OpenWrt |LEDE Build $(TZ=UTC-8 date '+%Y.%m.%d') @ OpenWrt |g" package/lean/default-settings/files/zzz-default-settings

# 修复软件源URL替换
sed -i 's#openwrt.proxy.ustclug.org#mirrors.bfsu.edu.cn/openwrt#g' package/lean/default-settings/files/zzz-default-settings

# 拉取 argon 源码
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf package/small-package/luci-app-argon*
rm -rf package/small-package/luci-theme-argon*
git clone -b 18.06 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config   
git clone -b 18.06 https://github.com/jerrykuku/luci-theme-argon.git  package/luci-theme-argon

# 更改 Argon 主题背景（检查文件是否存在）
if [ -f "$GITHUB_WORKSPACE/images/bg1.jpg" ]; then
    cp -f $GITHUB_WORKSPACE/images/bg1.jpg package/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg
else
    echo "警告: 背景图片文件不存在，跳过复制"
fi

# Modify default IP
sed -i 's/192.168.1.1/192.168.1.10/g' package/base-files/files/bin/config_generate

# Modify system hostname（FROM OpenWrt CHANGE TO OpenWrt-N1）
sed -i 's/LEDE/OpenWrt-N1/g' package/base-files/files/bin/config_generate

# Replace the default software source
sed -i 's/invalid users = root/#invalid users = root/g' feeds/packages/net/samba4/files/smb.conf.template

# 修复部分插件自启动脚本丢失可执行权限问题
sed -i '/exit 0/i\chmod +x /etc/init.d/*' package/lean/default-settings/files/zzz-default-settings
cat >> package/lean/default-settings/files/zzz-default-settings <<'EOF'
if command -v uci >/dev/null 2>&1 && [ -f /etc/config/ttyd ]; then
    uci set ttyd.@ttyd[0].enabled='1'
    uci set ttyd.@ttyd[0].interface='lan'
    uci set ttyd.@ttyd[0].port='7681'
    uci set ttyd.@ttyd[0].command='/bin/login -f root'
    uci commit ttyd
    /etc/init.d/ttyd enable >/dev/null 2>&1
    /etc/init.d/ttyd restart >/dev/null 2>&1
fi
EOF

# 修改概览里时间显示为中文数字(F大打包工具会替换)
sed -i 's/os.date()/os.date("%Y年%m月%d日") .. " " .. translate(os.date("%A")) .. " " .. os.date("%X")/g' package/lean/autocore/files/arm/index.htm

# 修改主题多余版本信息
sed -i 's/<a class="luci-link" href="https://github.com/openwrt/luci"/<a/g' feeds/luci/themes/luci-theme-argon/luasrc/view/themes/argon/footer.htm
sed -i 's/<a href="https://github.com/jerrykuku/luci-theme-argon" target="_blank">/<a>/g' feeds/luci/themes/luci-theme-argon/luasrc/view/themes/argon/footer.htm
sed -i 's/<a href=\"https:\/\/github.com\/coolsnowwolf\/luci\">/<a>/g' feeds/luci/themes/luci-theme-bootstrap/luasrc/view/themes/bootstrap/footer.htm

# coremark跑分定时清除
sed -i '/\* \* \* \/etc\/coremark.sh/d' feeds/packages/utils/coremark/*

# 在线用户
git clone --depth=1 https://github.com/danchexiaoyang/luci-app-onliner.git package/luci-app-onliner

# 通知插件
git clone https://github.com/tty228/luci-app-serverchan.git package/luci-app-serverchan

# Add luci-app-amlogic 晶晨宝盒
rm -rf package/luci-app-amlogic
git clone -b main https://github.com/ophub/luci-app-amlogic.git package/luci-app-amlogic

# Add luci-app-adguardhome
rm -rf package/luci-app-adguardhome
git clone --depth=1 https://github.com/rufengsuixing/luci-app-adguardhome.git package/luci-app-adguardhome

# Add luci-app-homeproxy
rm -rf package/luci-app-homeproxy
git clone https://github.com/immortalwrt/homeproxy package/luci-app-homeproxy

# 添加 smartdns
git clone --depth=1 -b lede https://github.com/pymumu/luci-app-smartdns package/luci-app-smartdns
git clone --depth=1 https://github.com/pymumu/openwrt-smartdns package/smartdns

# 修复 v2ray-geodata 依赖问题
rm -rf feeds/packages/net/v2ray-geodata
rm -rf package/feeds/packages/v2ray-geodata
git clone https://github.com/sbwml/v2ray-geodata package/v2ray-geodata

# 修复循环依赖问题
# 修复 luci-app-bypass 循环依赖
sed -i 's|depends on iptables|depends on iptables \&\& !PACKAGE_luci-app-passwall_Iptables_Transparent_Proxy|g' feeds/small/luci-app-bypass/Makefile 2>/dev/null || true

# 修复 natmap 自依赖
sed -i 's|select natmap|select natmap \&\& !PACKAGE_natmap|g' feeds/small/natmap/Makefile 2>/dev/null || true

# 修复 baresip 循环依赖
sed -i 's|depends on baresip-mod-avcodec|depends on baresip-mod-avcodec \&\& !PACKAGE_baresip-mod-avformat|g' feeds/packages/net/baresip-mod-avformat/Makefile 2>/dev/null || true

# 修复 miniupnpd 自依赖
sed -i 's|select miniupnpd|select miniupnpd \&\& !PACKAGE_miniupnpd|g' feeds/packages/net/miniupnpd/Makefile 2>/dev/null || true

# 修复 tor 循环依赖
sed -i 's|depends on tor|depends on tor \&\& !PACKAGE_luci-app-torbp|g' feeds/small/luci-app-torbp/Makefile 2>/dev/null || true

# 修复 mentohust 自依赖
sed -i 's|select mentohust|select mentohust \&\& !PACKAGE_mentohust|g' feeds/packages/net/mentohust/Makefile 2>/dev/null || true

# 修复 kmod-oaf 自依赖
sed -i 's|select kmod-oaf|select kmod-oaf \&\& !PACKAGE_kmod-oaf|g' feeds/packages/kernel/kmod-oaf/Makefile 2>/dev/null || true

# 调整部分插件到nas菜单
sed -i 's/services/nas/g' feeds/luci/applications/luci-app-hd-idle/root/usr/share/luci/menu.d/luci-app-hd-idle.json
sed -i 's/services/nas/g' feeds/luci/applications/luci-app-samba4/root/usr/share/luci/menu.d/luci-app-samba4.json
sed -i 's/services/nas/g' feeds/luci/applications/luci-app-aria2/root/usr/share/luci/menu.d/luci-app-aria2.json

#luci-app-nps（修改nps服务器允许域名）
sed -i 's/^server.datatype = "ipaddr"/--server.datatype = "ipaddr"/g' feeds/luci/applications/luci-app-nps/luasrc/model/cbi/nps.lua
sed -i 's/Must an IPv4 address/IPv4 address or domain name/g' feeds/luci/applications/luci-app-nps/luasrc/model/cbi/nps.lua
sed -i 's/Must an IPv4 address/IPv4 address or domain name/g' feeds/luci/applications/luci-app-nps/po/zh-cn/nps.po
sed -i 's/必须是 IPv4 地址/IPv4 地址或域名/g' feeds/luci/applications/luci-app-nps/po/zh-cn/nps.po

#luci-app-frpc
#sed -i 's/"services"/"vpn"/g'  feeds/luci/applications/luci-app-frpc/luasrc/controller/frp.lua
#sed -i 's/"services"/"vpn"/g'  feeds/luci/applications/luci-app-frpc/luasrc/model/cbi/frp/basic.lua
#sed -i 's/"services"/"vpn"/g'  feeds/luci/applications/luci-app-frpc/luasrc/model/cbi/frp/config.lua
#sed -i 's/\[services\]/\[vpn\]/g'  feeds/luci/applications/luci-app-frpc/luasrc/view/frp/frp_status.htm

# Alist
rm -rf package/luci-app-alist
git clone --depth=1 https://github.com/sbwml/luci-app-alist package/luci-app-alist
[ -f package/luci-app-alist/root/usr/share/luci/menu.d/luci-app-alist.json ] && sed -i 's/services/nas/g' package/luci-app-alist/root/usr/share/luci/menu.d/luci-app-alist.json



# 修改插件名字
sed -i 's/"Argon 主题设置"/"主题设置"/g' `grep "Argon 主题设置" -rl ./`
sed -i 's/"AdGuard Home"/"AdGuard"/g' `grep "AdGuard Home" -rl ./`
sed -i 's/"Aria2 配置"/"Aria2"/g' `grep "Aria2 配置" -rl ./`
sed -i 's/"实时流量监测"/"流量"/g' `grep "实时流量监测" -rl ./`
sed -i 's/"Alist 文件列表"/"Alist"/g' `grep "Alist 文件列表" -rl ./`
sed -i 's/"挂载点"/"磁盘挂载"/g' `grep "挂载点" -rl ./`
sed -i 's/"Npc"/"Nps穿透"/g' `grep "Npc" -rl ./`
sed -i 's/"Frp 内网穿透"/"Frp穿透"/g' `grep "Frp 内网穿透" -rl ./`
sed -i 's/"FTP 服务器"/"FTP服务器"/g' `grep "FTP 服务器" -rl ./`
sed -i 's/"TTYD 终端"/"终端"/g' `grep "TTYD 终端" -rl ./`
sed -i 's/"网络存储"/"存储"/g' `grep "网络存储" -rl ./`
sed -i 's/"NPS 内网穿透客户端"/"NPS穿透"/g' `grep "NPS 内网穿透客户端" -rl ./`
sed -i 's/"ShadowSocksR Plus+"/"SSR Plus+"/g' `grep "ShadowSocksR Plus+" -rl ./`


# 修改带宽监控
sed -i '/msgstr/s/"带宽监控"/"监视"/g' feeds/luci/applications/luci-app-nlbwmon/po/zh-cn/nlbwmon.po
sed -i '/msgid "Reboot"/{n;s/msgstr "重启"/msgstr "重启设备"/;}' feeds/luci/modules/luci-base/po/zh-cn/base.po


#删除插件
rm -rf feeds/luci/applications/luci-app-qbittorrent
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

# golang版本修复
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang

# mosdns
find ./ | grep Makefile | grep v2ray-geodata | xargs rm -f
find ./ | grep Makefile | grep mosdns | xargs rm -f
rm -rf feeds/packages/net/mosdns feeds/packages/net/v2ray-geodata
git clone https://github.com/sbwml/luci-app-mosdns package/mosdns
git clone https://github.com/sbwml/v2ray-geodata package/geodata
