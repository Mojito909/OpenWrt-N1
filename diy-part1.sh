 #!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# 添加feed源
echo 'src-git kenzo https://github.com/kenzok8/openwrt-packages' >> feeds.conf.default
# small 提供 luci-app-openclash（与 vernesong master 同版同步）及代理核心。
# PassWall/PassWall2/SSR Plus+ 虽已不再启用，但 small 必须保留，否则 OpenClash
# 本体无法挂载、代理核心依赖无法解析（package/install 阶段直接 Error 255）。
# 用它替换 passwall_packages，避免两源并存造成 17 个同名包重复定义
# （opkg Error 255 的来源）。
echo 'src-git small https://github.com/kenzok8/small' >> feeds.conf.default


# 注释掉可能有问题的源
# echo 'src-git fichenx https://github.com/fichenx/openwrt-package' >> feeds.conf.default
# echo 'src-git kenzo https://github.com/kenzok8/openwrt-packages' >> feeds.conf.default
# echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall' >> feeds.conf.default
