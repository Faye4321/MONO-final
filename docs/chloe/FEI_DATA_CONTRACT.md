# Explore / Wishlist · Fei 接口约定

当前两个协议都在 `ExploreRepositories.swift`，调用隔离于 MainActor。适配器内部可以 await Firebase SDK；不要用同步网络阻塞 UI，也不要把管理员凭据或 marketplace secret 写进客户端。

| 接口 | 返回/写入约定 |
| --- | --- |
| `fetchPicks() async throws -> [ShopPick]` | 当前可公开发现的商品列表；无结果返回 `[]`，请求失败 throw；稳定唯一 `itemId`，不要使用每次随机 UUID |
| `fetchSavedPicks() async throws -> [SavedPick]` | 当前登录用户的保存快照；空列表成功返回 `[]`，禁止把鉴权/断网错误转换为空列表 |
| `setSaved(_:saved:) async throws` | 按 `pick.id` 幂等 upsert/delete；只有持久化成功才返回；已有条目保留原 savedAt；失败 throw |

`ShopPick` 使用原有字段：`itemId`, `category`, `title`, `subtitle`, `priceUSD`, `note`, `imageName`, `imageURL`。`SavedPick` 包含 `pick` 与 `savedAt`。云端存储不要求照搬 Swift JSON 的枚举/日期编码，可在适配器转换成 Firebase 字段。

建议 Catalog 文档用稳定 ID；Wishlist 存到 `users/{uid}/wishlist/{itemId}`，规则只允许当前 UID 读写。保存完整显示快照，避免商品目录下架后 Wishlist 消失。Catalog 只返回公开发现内容，不能把 Private Collection 混入推荐。

注入位置只有 `RootTabView` 创建 `HomeView` 的地方：

```swift
HomeView(
    onProfileTapped: { selection = .me },
    onOpenLab: { selection = .lab },
    catalogProvider: yourCatalogAdapter,
    wishlistProvider: yourUIDScopedWishlistAdapter
)
```

上面的 adapter 变量名仅表示团队之后提供的实际实例，不是已经存在的类型或实现。两个参数现在默认走本地实现，因此工程不会因缺少 Firebase 库而新增依赖。

**生命周期：** Home 用 StateObject 保留 Store。认证用户改变时，要让该 Home 实例的 `.id(currentUID)` 改变（未登录使用稳定 guest ID），或在认证根视图重建 Home；仅替换 initializer 参数不会自动替换已经存在的 StateObject。不要在账号 A 的 Store 上直接改成账号 B 的仓库。飞行中请求应随旧模块一起结束，避免旧账户内容流入新模块。

**当前版本约束：**

1. `CollectionCategory` 是全组共享的 4 种 enum，尚未支持用户自定义类别。先与 Crystal/Fei 统一为稳定类别 ID + 展示名等共享模型，再调整本模块筛选与推荐映射。不要把未知 rawValue 强行映射到 vinyl。
2. `ShopPick.itemWebURL` 当前按 eBay itemId 生成 URL。若推荐以后包含用户藏品、其他卖家或播放资源，先统一来源类型与链接模型，再扩展详情 CTA；不应给非 eBay 内容伪造 eBay ID。
3. 当前采用刷新读取及每次单条写入，未声称已支持跨设备实时订阅、离线写入队列、冲突合并或自动迁移本地 Wishlist。若 Firebase 离线 SDK 返回的是本地入队而非服务端确认，请明确团队的成功状态口径。
4. 对接时应把真实 Catalog 来源/更新时间映射给 UI，替换当前“Curated sample listings”说明。不能只换接口却保留演示标签，也不能在演示阶段隐藏该说明。
5. 推荐规则完全在设备端按类别运行。后端未来若负责排序，应明确谁拥有最终顺序，避免服务端排名再次被客户端覆盖。
6. 原工程从 eBay 返回后的购买确认流程继续保留；最终上线前，Collection Owner 应复核实际成交价输入，不能把示例商品标价当作用户真实支付金额。

对接验收：两个账户交替登录、空云端、断网、权限被拒绝、同一条重复保存、保存成功后重启、Catalog 下架后删除 Wishlist、取消/重试、Private Collection 隔离。
