# Chloe · Home / Explore / Wishlist

这是在你上传的 MONO Midterm 工程上完成的本地实现与交接包。目标是把 Chloe 的模块补齐到可以进入 Xcode 验证和团队整合的程度。**当前不是已经通过 iPhone 模拟器测试、接上 Firebase 或已提交 GitHub PR 的版本。**

## 先打开哪一个

1. 在 Mac 上解压整个文件夹，双击根目录 `MonArchive.xcodeproj`。
2. 在 Xcode 顶部选择 `MonArchive` scheme，以及任意 iPhone Simulator。最低 iOS 17。
3. 按 `⌘R`。原来的 Onboarding 仍保留；完成或登录后进入 Explore。
4. 首页右上角心形打开 Wishlist；搜索栏打开 Search finds；点击推荐卡片进入详情。
5. 查看外观参考：`Explore_Design_Preview.png`。用浏览器打开 `Explore_Interactive_Preview.html` 可以点击保存、移除、撤销、筛选和搜索。它是独立设计原型，**不是 SwiftUI 的运行证据**，保存状态仅在当前页面会话中有效。
6. `Explore_Figma_Reference.svg` 可以拖进 Figma 作为参考板。尚未写入团队 Figma；SVG 不等于已经完成原生 Figma 组件与 Auto Layout。

## 已实现的内容

| 工作项 | 这版的实现 | 当前验证状态 |
| --- | --- | --- |
| Home / Explore | 实时日期、搜索入口、Wishlist 入口、统一图片展示框、推荐轮播、类别浏览 | 代码完成；待 iOS 编译和实机/模拟器验证 |
| 猜你喜欢 | 本地规则：收集偏好 + 已保存类别 + 现有收藏类别；优先展示未保存的发现 | 有生产逻辑的 XCTest 用例；未运行 |
| Wishlist | 添加、移除、共享心形状态、保存中防重复点击、成功反馈、撤销移除 | 本地仓库实现；有持久化/失败用例；未运行 |
| 本地持久化 | 原子 JSON 写入；缺失文件视为空；损坏/未知版本报错并保留原文件 | 有测试代码；待 Mac 执行 |
| 搜索与结果 | 标题/作者信息/描述/类别关键词，多关键词同时匹配、类别筛选、标题和价格排序 | 有纯逻辑测试；未运行 |
| 收藏库搜索 | 原有 Archive Search 补充无结果提示和清空所有筛选 | 待模拟器验证 |
| Empty / Loading / Error | 初次加载、无商品、空 Wishlist、无搜索结果、加载失败重试、保存失败重试 | Preview 场景与状态代码已准备 |
| 尺寸与可访问性 | 自适应网格、44pt 主要控件、无固定横向定位、VoiceOver 文本，大字号单列 | 有 SE / Pro Max / 大字号 Preview；未做设备验证 |
| 数据接口 | 可替换的 Catalog 与 Wishlist 仓库协议 | Fei 实际 Firebase adapter 尚未提供 |
| Git / PR | 本地分支 `chloe-home-explore`，差异补丁和 PR 文案 | 未连接团队 remote，未推送或创建 PR |
| Figma | SVG 参考板 + 点击预览 | 尚未加入团队 Figma 或获得 Crystal 视觉验收 |

## 哪些文件是你负责的

- `MonArchive/HomeView.swift`：Explore 首页与导航，保留收藏日历及 Lab 入口。
- `MonArchive/Explore/ExploreCore.swift`：搜索、排序、去重、推荐规则。
- `MonArchive/Explore/ExploreRepositories.swift`：数据协议与本地 Wishlist。
- `MonArchive/Explore/ExploreStore.swift`：页面状态、持久化调用、反馈与防重复保存。
- `MonArchive/Explore/ExploreComponents.swift`：卡片、图片、心形、筛选、状态与反馈组件。
- `MonArchive/Explore/ExploreSearchView.swift`：搜索、Wishlist、推荐详情。
- `MonArchive/Explore/ExplorePreviewData.swift`：仅 Debug 的内存数据、Empty/Loading/Error Preview。
- `MonArchive/ArchiveSearchView.swift`：只补无结果恢复操作。
- `MonArchive/ShopPicks.swift`：仅让已有商品模型遵循 Codable，用于保存快照。

工程文件只添加 Explore 文件编译引用、共享 scheme；签名团队、Bundle ID 和其他人的功能文件保持原配置。`RootTabView.swift`、Collection、Create、Profile、Social、Onboarding 和 Lab 没有改写。Home 中保留了通往 Profile/Lab 的原回调。

## 数据和边界

- 仍使用原工程的 4 条 eBay 示例，不是实时商品接口。价格和库存未经在线核验，界面明确标注示例并要求在 eBay 确认。
- Wishlist 保留商品快照，所以推荐列表移除某条后，已保存条目仍能展示和删除。
- 默认 Wishlist 是此设备的本地演示数据，不是按账号隔离的线上数据。最终接入认证系统时必须换成 Fei 的 UID 范围仓库；账号切换应重建模块实例，不能把本地演示文件当作其他账号的云端数据。
- 搜索发现与搜索个人收藏是两个入口。个人对象/回忆搜索继续使用 Collection 中已有的 Archive Search。
- Pages 里的“用户自定义类别”需要 Collection 的共享类别模型配合。目前共享 `CollectionCategory` 只有 4 种，因此本版的筛选和推荐也支持这 4 种。没有单方面扩展共享 enum，以免破坏 Fei/Crystal 的模块；详见接口约定。
- 其他分工中的“移除 Friends’ Collections”、编辑 Profile、Onboarding 删除教程、Lab 模板、银行卡支付链接、全局字体和导航栏调整属于对应 Owner/Crystal，未混入此 PR。

## Mac 上的验证

先在 Terminal 进入解压文件夹：

```bash
swift test
xcodebuild -project MonArchive.xcodeproj -scheme MonArchive -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

`swift test` 使用根目录的 Package.swift，对真实生产模型、仓库和 Store 运行测试，不测试 SwiftUI 布局。12 个 XCTest 方法覆盖关键词匹配、排序、去重、推荐顺序、快照编解码、本地文件往返、损坏文件保留、未知版本、保存失败/重试/撤销、初始加载失败、空目录及重复点击。

iOS 的手动检查表在 `QA_CHECKLIST.md`。仓库中也附有 GitHub Actions 工作流，提交到 GitHub 后才能运行。

此交付环境没有 Swift/Xcode，编译、XCTest 和模拟器验证均未执行。已经执行的是：工程 OpenStep plist 解析、45 个 Swift 源文件引用和单次编译成员检查、共享 scheme/SVG/资源 JSON 检查、设计原型 JS 语法检查、SVG 参考板栅格化及人工查看、git diff 空白检查。浏览器渲染进程受环境限制，HTML 的点击行为和尺寸尚未在浏览器自动测试中验证。

## 安全提交到团队 GitHub

不要把整个项目目录覆盖到队友最新代码上。完整工程适合先独立运行；团队整合使用随包的 `chloe-home-explore.patch`。

1. 用 GitHub Desktop 克隆团队**最新**仓库，切换到基准分支，Fetch/Pull。
2. 创建 `chloe-home-explore` 分支。在 Repository → Open in Terminal 中打开这个克隆。
3. 把本包根目录的 patch 放在克隆外，用以下命令先检查：

```bash
git apply --check /实际路径/chloe-home-explore.patch
```

4. 只有检查成功，再执行：

```bash
git apply /实际路径/chloe-home-explore.patch
```

若出现冲突，先保留双方代码进行人工整合，尤其是 `HomeView.swift`、`ShopPicks.swift` 和 `project.pbxproj`；不要加 `--force` 或覆盖队友文件。

5. 按上面命令完成测试与 iOS build，再按 QA 清单跑模拟器。使用你自己的 GitHub 身份 Commit，然后 Publish branch / Push。
6. 创建 PR，使用 `PR_DESCRIPTION.md`，填写真实测试结果和 Figma 链接。让 Crystal 审查公共文件与视觉一致性；让 Fei 审查协议及账号数据隔离。

交付压缩包提供源码与补丁；本地分支的 commit 记录另见 WORK_LOG.txt，压缩包不携带 Git 历史。它们是从上传压缩包建立的本地工作记录，不代表 GitHub 上已有贡献。使用 patch 后以自己的已配置身份提交，可以保留清晰的个人贡献记录。

## Presentation 可以讲什么

“我负责把 Explore 从静态推荐页补成一个完整的发现与保存流程。用户可以按兴趣浏览推荐，搜索和筛选商品，再将喜欢的对象保存到 Wishlist。所有入口共享保存状态，移除后可以撤销，加载和保存失败也有清楚反馈。数据层通过两个仓库接口与页面分开，接入团队 Firebase 时可以保留同一套页面和交互。”

介绍云端和适配结果时，务必使用当时实际完成的验证状态。
