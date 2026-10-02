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

# 修改默认IP地址（按需求 192.168.31.10）与主机名（LEDE -> OpenWrt-N1）
sed -i 's/192.168.1.1/192.168.31.10/g' package/base-files/files/bin/config_generate
sed -i 's/LEDE/OpenWrt-N1/g' package/base-files/files/bin/config_generate
# 双保险：config_generate 的 sed 只覆盖首装生成路径；保留配置升级（晶晨宝盒）
# 会沿用旧 /etc/config/system，IP 与主机名都因此报过"没生效"。用 first-boot
# uci-defaults 在每次新 rootfs 首次启动时再强制指定一次，两条路径都收敛
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-n1-defaults <<'EOF'
uci set network.lan.ipaddr='192.168.31.10'
uci set system.@system[0].hostname='OpenWrt-N1'
uci commit network
uci commit system
EOF
# 构建日志验证：补丁必须命中 config_generate，否则后续流程没有意义
grep -n "192.168.31.10" package/base-files/files/bin/config_generate || { echo "错误：IP 补丁未命中 config_generate，请检查上游改动"; exit 1; }
grep -q "hostname='OpenWrt-N1'" package/base-files/files/bin/config_generate || { echo "错误：主机名补丁未命中 config_generate，请检查上游改动"; exit 1; }

# 修改Samba配置（允许root访问）
sed -i 's/invalid users = root/#invalid users = root/g' feeds/packages/net/samba4/files/smb.conf.template

# 修复插件自启动脚本权限
sed -i '/exit 0/i\chmod +x /etc/init.d/*' package/lean/default-settings/files/zzz-default-settings

# 修改概览时间显示为中文
sed -i 's/os.date()/os.date("%Y年%m月%d日") .. " " .. translate(os.date("%A")) .. " " .. os.date("%X")/g' package/lean/autocore/files/arm/index.htm


# ==================== 主题配置 ====================

# 拉取 Argon 主题
# 关键约束：luci@master 的 LuCI 用 Lua 模板引擎渲染主题（dispatcher.lua 的
# tpl.Template 找的是 luasrc/view/themes/argon/header.htm），主题必须用
# jerrykuku 的 18.06 分支（Lua 模板）。master 分支是 ucode 模板（.ut），这一代
# LuCI 无法渲染，会导致 "No valid theme found" 全站打不开。
# （ucode 主题是为 23.05/25.12 那代 LuCI 准备的，两代不可混用。）
# 同时清理同名包：luci@master feed 自带 argon-config（v0.9）、kenzo 源的
# argon 主题/配置是 ucode 版（v2.4.7/v1.0），形态不匹配且版本不一，均删除。
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf package/feeds/kenzo/luci-app-argon*
rm -rf package/feeds/kenzo/luci-theme-argon*
rm -rf package/feeds/luci/luci-app-argon-config
git clone -b 18.06 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config
git clone -b 18.06 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon

# 更改 Argon 主题背景
if [ -f "$GITHUB_WORKSPACE/images/bg1.jpg" ]; then
    cp -f "$GITHUB_WORKSPACE/images/bg1.jpg" package/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg
else
    echo "警告: 背景图片文件不存在，跳过复制"
fi

# 移除主题页脚版本信息（18.06 分支是 Lua 模板，页脚在 footer.htm）
sed -i 's/<a class="luci-link" href="https:\/\/github.com\/openwrt\/luci"/<a/g' package/luci-theme-argon/luasrc/view/themes/argon/footer.htm
sed -i 's/<a href="https:\/\/github.com\/jerrykuku\/luci-theme-argon" target="_blank">/<a>/g' package/luci-theme-argon/luasrc/view/themes/argon/footer.htm
# bootstrap 主题在 luci@master 仍是 Lua 模板，页脚文件存在，保留原有处理
sed -i 's/<a href=\"https:\/\/github.com\/coolsnowwolf\/luci\">/<a>/g' feeds/luci/themes/luci-theme-bootstrap/luasrc/view/themes/bootstrap/footer.htm


# ==================== 插件安装 ====================

# 在线用户
git clone --depth=1 https://github.com/danchexiaoyang/luci-app-onliner.git package/luci-app-onliner

# 通知插件（微信推送）
# 官方 README 指定编译用 openwrt-18.06 分支（Lua 控制器形态）。master 分支是
# menu.d/ucode 形态，本构建的 luci@master 属 Lua dispatcher、不读 menu.d——
# 装上后插件在、菜单不出现，这正是盒子上"微信推送消失"的根因（与晶晨宝盒
# main 分支的教训相同）。18.06 分支的 PKG_NAME 是 luci-app-serverchan，改回
# luci-app-wechatpush 以对齐 .config/workflow 硬校验/同名去重逻辑。
rm -rf package/luci-app-serverchan package/luci-app-wechatpush
git clone --depth=1 -b openwrt-18.06 https://github.com/tty228/luci-app-wechatpush.git package/luci-app-wechatpush
[ -f package/luci-app-wechatpush/Makefile ] || { echo "错误：luci-app-wechatpush（serverchan 18.06 分支）克隆失败，插件将缺失"; exit 1; }
# 18.06 分支的 Makefile/uci 配置是 CRLF 行尾：先剥掉 \r——否则 PKG_VERSION
# 等值携带 \r 破坏下载与编译，改名 sed 也永远锚不上（^...$ 匹配不到 \r）。
# init.d/控制器本身是 LF，无需处理；CRLF 的 api/*.json 属空白差异，无害。
sed -i 's/\r$//' package/luci-app-wechatpush/Makefile package/luci-app-wechatpush/root/etc/config/serverchan
sed -i 's/PKG_NAME:=luci-app-serverchan/PKG_NAME:=luci-app-wechatpush/' package/luci-app-wechatpush/Makefile
grep -q 'PKG_NAME:=luci-app-wechatpush' package/luci-app-wechatpush/Makefile || { echo "错误：wechatpush PKG_NAME 改名未命中，.config 的 luci-app-wechatpush 将被 defconfig 静默丢弃"; exit 1; }
# 凡其他来源也提供同名包（openwrt-23.05/25.12 在 luci feed、luci@master 在
# kenzok8 源），都会生成两份同名 ipk 导致 package/install 阶段 opkg 冲突
# （Error 255）。保留本地 clone 版，两个来源的挂载副本都清掉。
rm -rf package/feeds/luci/luci-app-wechatpush
rm -rf package/feeds/kenzo/luci-app-wechatpush

# Dockerman：luci feed 版的 action_events() 对没有 Actor 字段的 Docker 事件
# 裸取 v.Actor.Attributes（dockerman.lua:190 "attempt to index field 'Actor'"），
# 事件页直接 500。kenzo 源的 v0.5.26 已逐字段加防护并持续维护。feeds install
# 首源优先（luci 排在 kenzo 前）才会装到旧版，这里删掉 luci 挂载、用 feeds
# update 已克隆到本地的 kenzo 源码建本地副本（本地 package/ 优先级最高）。
rm -rf package/feeds/luci/luci-app-dockerman
rm -rf package/luci-app-dockerman
cp -a feeds/kenzo/luci-app-dockerman package/luci-app-dockerman
[ -f package/luci-app-dockerman/Makefile ] || { echo "错误：dockerman 替换失败，feeds/kenzo/luci-app-dockerman 不存在，请检查 feeds update 步骤"; exit 1; }

# 晶晨宝盒
rm -rf package/custom/luci-app-amlogic
rm -rf package/luci-app-amlogic
rm -rf package/feeds/kenzo/luci-app-amlogic
# ophub 把应用按 LuCI 代次分了分支：main 是 menu.d/ucode 形态（openwrt-23.05+
# 的新一代 LuCI），lua 才是 Lua 控制器形态。本构建的 luci@master 属于后者，
# Lua dispatcher 不读 menu.d 菜单，克隆 main 分支装上后菜单里不会出现晶晨宝盒，
# 必须用 lua 分支（v3.1.321）。
git clone -b lua https://github.com/ophub/luci-app-amlogic.git package/luci-app-amlogic

# AdGuardHome
# kenzo 源也提供 luci-app-adguardhome（v1.0），与下面的 rufengsuixing 克隆
# （v1.8，.config-lede 的 INCLUDE_binary 选项按它定义）同名冲突；不清掉挂载
# 会双源并存——轻则旧版遮蔽，重则 defconfig 把符号解析坏静默丢弃（插件"消失"）
rm -rf package/feeds/kenzo/luci-app-adguardhome
rm -rf package/luci-app-adguardhome
git clone --depth=1 https://github.com/rufengsuixing/luci-app-adguardhome.git package/luci-app-adguardhome
[ -f package/luci-app-adguardhome/Makefile ] || { echo "错误：luci-app-adguardhome 克隆失败，插件将缺失"; exit 1; }

# SmartDNS：luci feed（及 kenzo 源）也提供 luci-app-smartdns 与 smartdns
# 二进制包，与本地 pymumu lede 分支克隆同名。不清掉挂载时构建采用 feed 副本，
# 其控制器 order 未被菜单排序段改动，SmartDNS 会沉到服务菜单末尾（实测）；
# 二进制版本也可能与克隆版不一致
rm -rf package/feeds/luci/luci-app-smartdns package/feeds/kenzo/luci-app-smartdns
rm -rf package/feeds/kenzo/smartdns
git clone --depth=1 -b lede https://github.com/pymumu/luci-app-smartdns package/luci-app-smartdns
git clone --depth=1 https://github.com/pymumu/openwrt-smartdns package/smartdns
[ -f package/luci-app-smartdns/Makefile ] || { echo "错误：luci-app-smartdns 克隆失败，插件将缺失"; exit 1; }
# 挂载必须确实消失，否则构建仍取 feed 副本而菜单排序的 grep 链只查本地克隆，查不出这种错位
for p in package/feeds/luci/luci-app-smartdns package/feeds/kenzo/luci-app-smartdns package/feeds/kenzo/smartdns; do
  [ -e "$p" ] && { echo "错误：$p 挂载未清除，SmartDNS 将采用 feed 副本（菜单沉底/版本漂移）"; exit 1; }
done

# Alist：固件内置版停用（按需求）。内置版升级 Alist 必须重新编译整个固件，
# 而 Alist 官方迭代很快；建议用 Docker 方式安装（固件已带 dockerman），
# 升级只需拉取新镜像即可。需要恢复内置版时取消注释下面两行，并在
# .config-lede 里同时打开 CONFIG_PACKAGE_luci-app-alist=y
# rm -rf package/luci-app-alist
# git clone --depth=1 https://github.com/sbwml/luci-app-alist package/alist

# OpenClash（PassWall2/SSR Plus+ 移除后的替代）：small 源自带，且与 vernesong
# master 同版同步（0.47.156），feeds install -a 自动挂载为
# package/feeds/small/luci-app-openclash，此处无需克隆。kenzo 源的
# luci-app-openclaw 是另一个插件，不构成重名冲突。
# 依赖 dnsmasq-full/bash/curl/ca-bundle/ip-full/ruby/ruby-yaml/kmod-tun/unzip
# 及 fw4 下的 kmod-nft-tproxy/kmod-inet-diag/luci-compat 已在 .config-lede 钉死。


# ==================== 控制器 index 缓存兼容 ====================
# LuCI 会把所有控制器的 index() 用 string.dump 序列化进 /tmp/luci-indexcache，
# 反序列化后文件局部 upvalue 会按名绑定到不存在的同名全局（=nil）。凡 index()
# 里引用文件局部变量的控制器，首次访问正常、第二次起全站报
# "attempt to index upvalue ... (a nil value)"（本次 aliddns 即踩此坑）。
# 把 require 挪进 index() 内部使其成为 index 自己的局部变量即可规避；
# passwall/passwall2 的控制器自带 "-- not available" 标记，作者已规避，无需处理。
sed -i -e 's|^local fs = require "nixio.fs"$||' \
       -e 's|^function index()$|function index()\n\tlocal fs = require "nixio.fs"|' \
       feeds/kenzo/luci-app-aliddns/luasrc/controller/aliddns.lua
sed -i 's|^function index()$|function index()\n\tlocal nixio = require "nixio"|' \
       feeds/kenzo/luci-app-dnsfilter/luasrc/controller/dnsfilter.lua \
       feeds/kenzo/luci-app-gost/luasrc/controller/gost.lua


# ==================== 依赖修复 ====================

# v2ray-geodata：唯一有效来源是下方 MosDNS 段克隆的 sbwml 版（package/geodata）。
# 旧版在此克隆的 package/v2ray-geodata 会被 MosDNS 段的 find 删除后重新克隆，
# 属死代码，已移除；这里只摘掉 packages feed 的挂载避免同名双源
rm -rf package/feeds/packages/v2ray-geodata

# 修复循环依赖问题
# 注：luci 插件在 feed 中的真实路径是 feeds/luci/applications/<app>/，
# 旧脚本引用的 feeds/small/ 从未存在（kenzok8/openwrt-packages 的挂载名是 kenzo），
# 且其目标包（bypass/natmap/torbp/mia）在当前源中已不存在，故一并移除。
sed -i 's|select miniupnpd|select miniupnpd \&\& !PACKAGE_miniupnpd|g' feeds/packages/net/miniupnpd-iptables/Makefile 2>/dev/null || true
sed -i 's|depends on baresip-mod-avcodec|depends on baresip-mod-avcodec \&\& !PACKAGE_baresip-mod-avformat|g' feeds/packages/net/baresip-mod-avformat/Makefile 2>/dev/null || true
sed -i 's|select mentohust|select mentohust \&\& !PACKAGE_mentohust|g' feeds/packages/net/mentohust/Makefile 2>/dev/null || true
sed -i 's|select kmod-oaf|select kmod-oaf \&\& !PACKAGE_kmod-oaf|g' feeds/packages/kernel/kmod-oaf/Makefile 2>/dev/null || true

# 注意：不要在这里删除 packages 源的 gost 副本。scripts/feeds install 按
# feeds.conf 的顺序取第一个提供者挂载（packages 排在 kenzo 之前），gost 实际
# 挂载的就是 packages 的副本；删掉它的源码会让 luci-app-gost 的 gost 依赖
# 无法解析，直接导致 package/install Error 255
# （"cannot find dependency gost for luci-app-gost"）。kenzo 的 v3.3.0 因此被
# packages 的 v3.2.2 遮蔽，属可接受取舍。

# golang版本修复
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang

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
# 注意：grep 无匹配时命令会展开成没有输入文件的 sed（"sed: no input files"），
# 属正常跳过，已加 2>/dev/null || true 消除噪音。

sed -i 's/"Argon 主题设置"/"主题设置"/g' $(grep "Argon 主题设置" -rl ./) 2>/dev/null || true
sed -i 's/"AdGuard Home"/"AdGuard"/g' $(grep "AdGuard Home" -rl ./) 2>/dev/null || true
sed -i 's/"Aria2 配置"/"Aria2"/g' $(grep "Aria2 配置" -rl ./) 2>/dev/null || true
sed -i 's/"实时流量监测"/"流量"/g' $(grep "实时流量监测" -rl ./) 2>/dev/null || true
sed -i 's/"Alist 文件列表"/"Alist"/g' $(grep "Alist 文件列表" -rl ./) 2>/dev/null || true
sed -i 's/"挂载点"/"磁盘挂载"/g' $(grep "挂载点" -rl ./) 2>/dev/null || true
sed -i 's/"Npc"/"Nps穿透"/g' $(grep "Npc" -rl ./) 2>/dev/null || true
sed -i 's/"Frp 内网穿透"/"Frp穿透"/g' $(grep "Frp 内网穿透" -rl ./) 2>/dev/null || true
sed -i 's/"FTP 服务器"/"FTP服务器"/g' $(grep "FTP 服务器" -rl ./) 2>/dev/null || true
sed -i 's/"TTYD 终端"/"终端"/g' $(grep "TTYD 终端" -rl ./) 2>/dev/null || true
sed -i 's/"网络存储"/"存储"/g' $(grep "网络存储" -rl ./) 2>/dev/null || true
sed -i 's/"NPS 内网穿透客户端"/"NPS穿透"/g' $(grep "NPS 内网穿透客户端" -rl ./) 2>/dev/null || true


# ==================== 界面文字修改 ====================

sed -i '/msgstr/s/"带宽监控"/"监视"/g' feeds/luci/applications/luci-app-nlbwmon/po/zh-cn/nlbwmon.po
sed -i '/msgid "Reboot"/{n;s/msgstr "重启"/msgstr "重启设备"/;}' feeds/luci/modules/luci-base/po/zh-cn/base.po


# ==================== 菜单排序 ====================
# 【存储组 admin/nas】按需求：Aria2 -> 硬盘休眠 -> 网络共享 -> FTP服务器。
# 当前 luci master 把 aria2/hd_idle/samba4 注册在 admin/services（上游动过
# 分组，旧固件里它们在 nas），必须先把组搬回 admin/nas，否则三者会混进
# 服务菜单。组内 order 钉死 60/61/62；FTP服务器（vsftpd）无 order，按
# dispatcher 行为排最后，无需改动。
sed -i 's/{"admin", "services", "aria2"}/{"admin", "nas", "aria2"}/' feeds/luci/applications/luci-app-aria2/luasrc/controller/aria2.lua
sed -i 's/{"admin", "services", "hd_idle"}/{"admin", "nas", "hd_idle"}/' feeds/luci/applications/luci-app-hd-idle/luasrc/controller/hd_idle.lua
sed -i 's/{"admin", "services", "samba4"}/{"admin", "nas", "samba4"}/' feeds/luci/applications/luci-app-samba4/luasrc/controller/samba4.lua
sed -i 's/cbi("aria2"), _("Aria2 Settings"))/cbi("aria2"), _("Aria2 Settings"), 60)/' feeds/luci/applications/luci-app-aria2/luasrc/controller/aria2.lua
sed -i 's/cbi("hd_idle"), _("HDD Idle"), 60)/cbi("hd_idle"), _("HDD Idle"), 61)/' feeds/luci/applications/luci-app-hd-idle/luasrc/controller/hd_idle.lua
sed -i 's/cbi("samba4"), _("Network Shares"))\.dependent/cbi("samba4"), _("Network Shares"), 62).dependent/' feeds/luci/applications/luci-app-samba4/luasrc/controller/samba4.lua

# 【服务组 admin/services】按需求：UPnP -> Frp穿透 -> 网络唤醒 -> 微信推送
# -> AdGuard -> 阿里DDNS -> SmartDNS -> OpenClash -> DNS过滤器。上游各应用的
# order 交错（upnp 无序号、dnsfilter=9、openclash=50、aliddns=58、smartdns=60、
# wechatpush=30、adguardhome=10、wol=90、frpc=100），顺序随版本漂移，这里
# 全部显式钉死 10~18。Gost=100 等不在本需求内，按各自 order 落位（在本组
# 9 项之后）。
sed -i 's/cbi("upnp\/upnp"), _("UPnP"))/cbi("upnp\/upnp"), _("UPnP"), 10)/' feeds/luci/applications/luci-app-upnp/luasrc/controller/upnp.lua
sed -i 's/cbi("frp\/basic"), _("Frp Setting"), 100)/cbi("frp\/basic"), _("Frp Setting"), 11)/' feeds/luci/applications/luci-app-frpc/luasrc/controller/frp.lua
sed -i 's/form("wol"), _("Wake on LAN"), 90)/form("wol"), _("Wake on LAN"), 12)/' feeds/luci/applications/luci-app-wol/luasrc/controller/wol.lua
sed -i 's/_("微信推送"), 30)/_("微信推送"), 13)/' package/luci-app-wechatpush/luasrc/controller/serverchan.lua
sed -i 's/_("AdGuard"), 10)/_("AdGuard"), 14)/' package/luci-app-adguardhome/luasrc/controller/AdGuardHome.lua
sed -i 's/cbi("aliddns"), _("AliDDNS"), 58)/cbi("aliddns"), _("AliDDNS"), 15)/' feeds/kenzo/luci-app-aliddns/luasrc/controller/aliddns.lua
sed -i 's/cbi("smartdns\/smartdns"), _("SmartDNS"), 60)/cbi("smartdns\/smartdns"), _("SmartDNS"), 16)/' package/luci-app-smartdns/luasrc/controller/smartdns.lua
sed -i 's/alias("admin", "services", "openclash", "client"), _("OpenClash"), 50)/alias("admin", "services", "openclash", "client"), _("OpenClash"), 17)/' feeds/small/luci-app-openclash/luasrc/controller/openclash.lua
sed -i 's/_("DNS Filter"), 9)/_("DNS Filter"), 18)/' feeds/kenzo/luci-app-dnsfilter/luasrc/controller/dnsfilter.lua

# 【系统组 admin/system】按需求：系统 -> 终端 -> 管理权 -> 软件包。上游：
# system=1、admin=2、packages(ttyd 的 terminal.lua 也是 10，与软件包撞号靠
# 名字兜底)、startup=45 起。终端提前到 2，管理权/软件包顺延 3/4；启动项/
# 计划任务/挂载点等(45+)保持原值，自然排在其后。终端控制器标题是英文
# "TTYD Terminal"（po 翻译为 TTYD 终端、再被改名段转成 终端），锚定用英文。
sed -i 's/_("TTYD Terminal"), 10)/_("TTYD Terminal"), 2)/' feeds/luci/applications/luci-app-ttyd/luasrc/controller/terminal.lua
sed -i 's/cbi("admin_system\/admin"), _("Administration"), 2)/cbi("admin_system\/admin"), _("Administration"), 3)/' feeds/luci/modules/luci-mod-admin-full/luasrc/controller/admin/system.lua
sed -i 's/action_packages"), _("Software"), 10)/action_packages"), _("Software"), 4)/' feeds/luci/modules/luci-mod-admin-full/luasrc/controller/admin/system.lua

# DNS过滤器标题去空格：显示名来自 zh-cn po 的 msgstr "DNS 过滤器"
sed -i 's/msgstr "DNS 过滤器"/msgstr "DNS过滤器"/' feeds/kenzo/luci-app-dnsfilter/po/zh-cn/dnsfilter.po

# 构建日志验证：所有菜单补丁必须全部命中
grep -q '{"admin", "nas", "aria2"}' feeds/luci/applications/luci-app-aria2/luasrc/controller/aria2.lua && \
grep -q '_("Aria2 Settings"), 60)' feeds/luci/applications/luci-app-aria2/luasrc/controller/aria2.lua && \
grep -q '_("HDD Idle"), 61)' feeds/luci/applications/luci-app-hd-idle/luasrc/controller/hd_idle.lua && \
grep -q '_("Network Shares"), 62)' feeds/luci/applications/luci-app-samba4/luasrc/controller/samba4.lua && \
grep -q '_("UPnP"), 10)' feeds/luci/applications/luci-app-upnp/luasrc/controller/upnp.lua && \
grep -q '_("Frp Setting"), 11)' feeds/luci/applications/luci-app-frpc/luasrc/controller/frp.lua && \
grep -q '_("Wake on LAN"), 12)' feeds/luci/applications/luci-app-wol/luasrc/controller/wol.lua && \
grep -q '_("微信推送"), 13)' package/luci-app-wechatpush/luasrc/controller/serverchan.lua && \
grep -q '_("AdGuard"), 14)' package/luci-app-adguardhome/luasrc/controller/AdGuardHome.lua && \
grep -q '_("AliDDNS"), 15)' feeds/kenzo/luci-app-aliddns/luasrc/controller/aliddns.lua && \
grep -q '_("SmartDNS"), 16)' package/luci-app-smartdns/luasrc/controller/smartdns.lua && \
grep -q '_("OpenClash"), 17)' feeds/small/luci-app-openclash/luasrc/controller/openclash.lua && \
grep -q '_("DNS Filter"), 18)' feeds/kenzo/luci-app-dnsfilter/luasrc/controller/dnsfilter.lua && \
grep -q 'cbi("admin_system/system"), _("System"), 1)' feeds/luci/modules/luci-mod-admin-full/luasrc/controller/admin/system.lua && \
grep -q '_("TTYD Terminal"), 2)' feeds/luci/applications/luci-app-ttyd/luasrc/controller/terminal.lua && \
grep -q '_("Administration"), 3)' feeds/luci/modules/luci-mod-admin-full/luasrc/controller/admin/system.lua && \
grep -q '_("Software"), 4)' feeds/luci/modules/luci-mod-admin-full/luasrc/controller/admin/system.lua && \
grep -q 'msgstr "DNS过滤器"' feeds/kenzo/luci-app-dnsfilter/po/zh-cn/dnsfilter.po || \
{ echo "错误：菜单排序/标题补丁未命中，请检查对应 feed/克隆的上游改动"; exit 1; }


# ==================== 清理删除 ====================

# 清除 coremark 定时任务
sed -i '/\* \* \* \/etc\/coremark.sh/d' feeds/packages/utils/coremark/*

# 删除冲突/问题插件。qBittorrent 系列上游仍在（luci feed 的 luci-app-qbittorrent
# + packages 源的 qBittorrent/qBittorrent-static，2026-09 核实 200），编译重且
# .config 未选，保留删除行兜底防被依赖链拉入。luci-app-mia 已从上游消失
# （404），其删除行属空操作，已移除。
rm -rf feeds/luci/applications/luci-app-qbittorrent
rm -rf feeds/packages/net/qBittorrent-static
rm -rf feeds/packages/net/qBittorrent