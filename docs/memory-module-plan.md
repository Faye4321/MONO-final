# MonArchive 记忆模块方案（修订版）

> 状态：P0–P3 代码已完成，待在 Xcode 中编译验证
> 分支：`feature/memory-module`（基于 `feature/picked-for-you`）

## 1. 背景

MonArchive 面向 BJD、K-pop 小卡、黑胶唱片、电影海报的收藏者，目标是把藏品管理、个人收藏记忆和交易整合在一个地方。

现有的垂直工具擅长回答「这是什么、我有没有」，但收藏者真正在意的是「在哪里得到、和谁一起、为什么珍贵」，这些信息散落在相册、Notes、Excel、购物平台和社交媒体里。

本模块让每件藏品同时拥有两类数据：

- **标准数据**：名称、价格、品相、稀有度
- **个人数据**：时间、地点、同行的人、照片、笔记、意义

## 2. 设计原则

1. **先存后补**：除了藏品照片，所有个人字段都是选填。
2. **自动填充只给建议**：照片 EXIF 里的日期只作为建议显示，用户点了才写入。EXIF 时间是拍照时间，不一定是入手时间。
3. **批量优先**：一次签售或开专可能拿到很多件，同一事件（Moment）可以关联多件藏品。
4. **私密默认**：所有个人数据只存在本机，默认不分享；同行的人只是文本标签，不关联任何账号。
5. **记忆跟着藏品走**：藏品「转出」后进入 Past Collection，记忆保留。
6. **数据不能丢**：读取失败时不覆盖原文件；提供导出。

## 3. 数据模型

```
CollectibleItem（已有，新增字段）
  + pricePaid: Double?          标准数据：实付价格（USD）
  + condition: ItemCondition?   标准数据：品相
  + rarity: Rarity?             标准数据：稀有度
  + meaning: String             个人数据：一句话意义
  + meaningTag: MeaningTag?     个人数据：意义标签
  + imageFileName: String?      照片改为文件存储（替代内联 imageData）
  + partedOn: Date?             转出日期（P3）

Moment（新增，一个事件对应多件藏品）
  id, kind（acquired / milestone / farewell）
  date, datePrecision（day / month / year）
  placeName, placeKind（event / store / online / trade / gift / other）
  companions: [String]
  photoFileNames: [String]
  note: String
  itemIDs: [UUID]
```

藏品的「记忆时间线」= 所有 `itemIDs` 包含该藏品的 Moment，按日期排序。

### 存储

- `archive.json`：保存用户创建的藏品、对预置藏品的修改（overrides）、所有 Moment。
- `Images/`：藏品照片和记忆照片，以 jpg 文件保存，JSON 里只存文件名。
- 首次启动时，把旧版 `uploaded-objects.json` 里的内联图片迁移成文件。
- 解码失败时把原文件重命名为 `archive.corrupt-<时间戳>.json`，不覆盖。

## 4. 触点与优先级

| 优先级 | 触点 | 内容 |
|---|---|---|
| **P0** | 存储重构 | archive.json + Images/，迁移旧数据，预置藏品也能保存修改与记忆，解码失败不覆盖 |
| **P0** | 数据模型 | `Moment`、标准数据字段、意义字段 |
| **P0** | 创建流程 | 第 3 步填标准数据（价格 / 品相 / 稀有度）；第 4 步「ADD YOUR MEMORY」单独填记忆（意义、日期 + 精度、地点 + 类型、同行、照片、笔记），可「SKIP FOR NOW」；EXIF 日期作为建议；可并入最近的 Moment |
| **P0** | 藏品详情页 | 标准数据区 + 「我的记忆」时间线；添加记忆；EDIT OBJECT 可用 |
| **P0** | 隐私 | 全部私密、仅存本机，页面上明确提示 |
| **P0** | 导出 | 个人页导出 archive.json |
| **P1** | CSV 批量导入 | 从「文件」导入；同一日期 + 地点 + 同行的行自动合并为一个 Moment |
| **P1** | 批量补记忆 | 记忆编辑器可一次关联多件已有藏品 |
| **P1** | 个人页 Collection Journey | 统计（记忆数 / 地点数 / 同行人数）+ 按月份的时间线 |
| **P2** | 检索 | 按名称、创作者、意义、地点、同行、笔记搜索；按品类、品相、稀有度筛选 |
| **P2** | 地点与人物索引 | 个人页列出所有地点、同行的人及次数，点击进入检索 |
| **P2** | 货架记忆标记 | 有记忆的藏品在货架上显示标记 |
| **P3** | eBay 回访确认 | 从 Picked for You 跳转 eBay 后回到 App，询问「买到了吗」；确认后生成藏品 + 获得记忆（价格、渠道、日期预填） |
| **P3** | Past Collection | 转出藏品：生成「告别」记忆，移出货架，记忆保留 |
| **P3** | 记忆分享卡 | 单条记忆导出为图片；每个字段需逐项勾选，默认全不勾选 |

## 5. 移出路线图

| 项目 | 原因 |
|---|---|
| 来历传承（把记忆转给买家） | 卖家有动机编造故事抬价，平台无法核实；会泄露前任主人隐私 |
| 自动读取 eBay 订单 | 需要用户级 OAuth 和 Order API，当前架构拿不到；P3 用「回访确认」替代 |
| 基于意义的推荐引擎 | 当前只有静态商品列表，不具备条件 |
| 足迹地图 | 当前只存地点名称，不存坐标；P2 先做地点列表 |
| 好友账号关联 | 涉及未授权第三方的隐私与同意问题 |
| 「那年今日」、年度报告、首页 This Month 卡片 | 记忆不在首页单独成模块，只整合在添加 Object 流程和藏品详情页 |

## 6. 成功指标

- 入库时至少填写 1 个个人字段的比例
- 有记忆的藏品占全部藏品的比例
- 入库后 7 天内回看详情页的比例
- CSV 导入的使用率与平均导入件数

## 7. 已知风险

- 本方案的核心假设「收藏者愿意记录」尚未经过用户访谈验证，建议在 P1 完成后做 5–8 人可用性测试。
- 数据只在本机，换机前需手动导出；iCloud 同步留待后续。
- 照片 EXIF 读取依赖 PhotosPicker 返回的原始数据，部分来源（截图、社交媒体保存图）没有 EXIF。

## 8. 实现对照

| 优先级 | 功能 | 文件 |
|---|---|---|
| P0 | 数据模型 | `Models.swift`（标准数据、意义、partedOn）、`Memory.swift`（Moment、MomentDraft、PriceText） |
| P0 | 存储与迁移 | `CollectionStore.swift`、`ImageStore.swift`（照片文件、EXIF 日期） |
| P0 | 创建流程 | `CreateFlowView.swift`（第 3 步 Object Details，第 4 步 Your Memory） |
| P0 | 详情页 / 编辑 | `ItemDetailView.swift`（标准数据、意义、记忆时间线、ItemEditSheet） |
| P0 | 记忆编辑器 | `MomentEditorView.swift`、`MemoryComponents.swift` |
| P0 | 导出 | `ProfileView.swift` → ARCHIVE DATA |
| P1 | CSV 导入 | `CSVImporter.swift`、`ProfileView.swift` → IMPORT FROM CSV |
| P1 | 批量补记忆 | `MomentEditorView.swift` → ObjectPickerView |
| P1 | Journey 统计 + 收藏日历 | `JourneyViews.swift`（统计、地点 / 人物列表）、`CollectionCalendarView.swift`（月份卡片、叠放、全屏翻阅）；挂在 `ProfileView.swift` |
| P2 | 检索 | `ArchiveSearchView.swift`；入口在 `CollectionView.swift` 右上角 |
| P2 | 地点与人物索引 | `JourneyViews.swift` → IndexRow |
| P2 | 货架记忆标记 | `ShelfDetailView.swift` → MemoryBadge |
| P3 | eBay 回访确认 | `HomeView.swift`（记录打开的商品）、`RootTabView.swift`（回到前台时询问） |
| P3 | Past Collection | `ItemDetailView.swift` → FarewellSheet；`JourneyViews.swift` → PastCollectionSection |
| P3 | 分享卡 | `ShareCard.swift` |

### CSV 模板

```csv
title,category,creator,year,price,condition,rarity,meaning,note,date,place,place_type,with,memory_note
EJ Yukiakari Fansign,photocard,&TEAM,2025,88,near mint,rare,第一次见本人,,2025-03-02,Seoul fansign,event,小A;小B,排了三个小时
K Yukiakari Fansign,photocard,&TEAM,2025,40,mint,limited,,,2025-03-02,Seoul fansign,event,小A;小B,
FOR YOU,album,Tatsuro Yamashita,1982,48,good,common,,,2024-08,Amoeba Music,store,,
```

前两行日期、地点、同行相同，导入后会合并成一条记忆。

## 9. 变更记录

- **首页不再放记忆模块**：删除 This Month 卡片。记忆只在「添加 Object」第 4 步录入，在藏品详情页查看和补充；个人页的 Collection Journey 暂时保留。
- **Picked for You**：下一张卡片在右侧露出约 22pt 作为可滑动提示；商品图由 `scripts/fetch_pick_images.sh` 在 Mac 上下载进 `Assets.xcassets`（`pick_<itemId>`），白底相框展示。
- **eBay 开发者账号注册被拒**：不再依赖 eBay API，商品数据保持静态。
- **个人页 Collection Journey 改为收藏日历**（只读，不提供录入）：保留统计（MEMORIES / PLACES / PEOPLE，后两项可点开列表进入搜索）；原时间线和地点 / 人物标签换成按月份叠放的日历卡片。
  - 每张卡片：左上月份 + 年份，右上小日历（有记忆的日子画红圈），中部文字记录（笔记 → 意义 → 自动生成），下部一条记忆一组照片拼贴；空月份纯色留白。
  - 只精确到年或未填日期的记忆放在当年最后一张「Sometime」卡片。
  - 交互：左右滑或点露出的边切换月份；点红圈日期高亮当天；点照片组进入藏品；点卡片进入全屏上下翻阅。
  - 照片拼贴用缩略图缓存；支持 VoiceOver 切换月份和「减少动态效果」。
- **日历与藏品打通**：日历显示收藏中的每一件藏品，实时从 `CollectionStore` 读取。
  - 藏品新增 `addedOn`（加入日期），创建、CSV 导入、eBay 购买时自动记录；EDIT OBJECT 可修改。
  - 位置规则：有日期的「获得」记忆 → 记忆日期；否则 → `addedOn`；都没有 → 当年「Sometime」卡片。里程碑、告别记忆另外出现在各自日期。
  - 示例藏品（SeedData）使用固定的 2026 年 5–10 月示例日期，仅用于演示（`SeedData.itemsWithDemoDates`）。
  - 藏品详情页新增「SEE IN JOURNEY」，打开全屏日历并翻到该藏品所在月份；ME 页统计新增 OBJECTS。
  - 删除所有页面上的「PRIVATE · STORED ONLY ON THIS DEVICE」提示。
- **合并 Crystal 提供的 Lab 与开屏引导**（来自 `MONO-Lab-Xcode-v1.zip`）：
  - Lab 拼贴编辑器（`LabModels / LabImageServices / LabFlowViews / LabEditorViews.swift`）作为底部第 4 个标签 LAB；首页 Collage Studio 卡片跳转到 LAB。通过 `ArchiveLabCollectionProvider` 读取收藏中的真实藏品照片。
  - 开屏引导（`OnboardingFlow.swift`、`MonoLogoView.swift`）：开屏动画 → 欢迎页 → 登录 / 注册（本地，未接账号服务）→ 新用户**必须**添加第一件藏品（使用现有 Create 流程）→ 5 页功能导览（EXPLORE / COLLECTION / CREATE / LAB / ME）。
  - 未合并：她的首页、`BrandTheme`、`Models`、`ContentView`、App 入口（与现有代码重复或冲突），以及 `FirstCollectionUploadView`（由现有 Create 流程替代，保证藏品被保存）。
- **开屏引导改版**：注册后 → 欢迎过渡页（Welcome, 名字 · 3 quick steps）→ ① 你收藏什么（多选，影响 Create 默认类别与 Picked for You 排序）→ ② 添加第一件藏品（必须）→ 完成回报页（展示刚保存的藏品，可选导览或跳过）→ ③ 功能导览（可跳过）→ You're all set → Explore。每个设置步骤顶部显示「SETTING UP YOUR ARCHIVE · N OF 3」进度条。注册时填写的名字同步到 ME 页。
- **导览指针**：导览期间绘制自己的底部导航栏，指针与其对齐，不再依赖系统导航栏（iOS 26 为悬浮样式，位置无法推算）。
- **收藏日历卡片**：内容从顶部排列、超出部分裁掉，修复卡片向上溢出遮挡标题的问题；照片组改为一行 3 组（全屏 6 组）。
- **ME 页精简**：删除 MY COLLECTIONS 与 COLLECTION JOURNEY 两个板块（日历只保留在 Explore 页），以及仅供它们使用的代码。ME 页保留个人卡片、Past Collection 与 Archive Data。
