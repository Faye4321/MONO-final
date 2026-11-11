# Explore 推荐卡片留白修正

根据 iPhone 截图，460pt 的外层高度和内部最小高度让价格下方出现大段留白。

- 轮播移除固定高度与 GeometryReader，使用内容的实际高度。
- 推荐最多 6 张，使用 HStack 直接测量全部卡片，长标题也能参与高度计算。
- 卡片宽度继续按容器计算，保留滑动与下一张露出的提示。
- 价格行之后只保留卡片内边距；相邻卡片需要对齐的空间放在说明与价格上方。
- 大字号单卡使用自然高度，避免伸长。

代码改动只在 `MonArchive/HomeView.swift`。`compact-featured-cards.patch` 是针对上一版 Chloe 实现的单文件补丁；完整 `chloe-home-explore.patch` 仍基于最初上传的 Midterm 工程。

已完成结构与差异检查，尚未在 Xcode/模拟器验证。团队仓库 `Faye4321/MONO-final` 未能读取或推送：当前 GitHub 连接由管理员禁用，CLI 未登录，网络拉取也被拒绝。此包未与团队最新代码比对，不能用整个目录覆盖队友更新；如需手动整合，先比较 HomeView，再只应用本次布局改动。
