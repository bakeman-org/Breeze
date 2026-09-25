# Bika / E-Hentai 原生化重构计划

## Context

用户要求把哔咔（bika）与 E-Hentai 从 QuickJS 插件改为**原生 Dart 独立实现**（告别 QuickJS 沙箱链路），UI 仿照 haka_comic（哔咔）与 EhViewer_CN_SXJ（EH）的页面形态，能复用就复用；完成后从内置插件清单移除这两个插件。用户已确认：全新独立页面、EH 尽量全功能、bika 与 EH 同时开工。

参考项目：
- `/home/etcix/code/flutter/haka_comic`：bika API 全套（登录/分类/排行/搜索/详情/章节/图片/评论/点赞/收藏/签到），HMAC-SHA256 签名（`lib/network/utils.dart:29-90`），双线路 host（picaapi.picacomic.com / picaapi.go2778.com），图片 URL 构造（`models.dart:49-107`）。
- `/home/etcix/code/flutter/EhViewer_CN_SXJ`：EhUrl/EhSite 常量（`client/EhUrl.java:34-134`）、登录 cookie（`EhCookieStore.java:32-57`：ipb_member_id/ipb_pass_hash/igneous）、画廊列表 HTML 解析（`parser/GalleryListParser.java`）、GalleryInfo 模型（`data/GalleryInfo.java:107-138`）、EhClient 方法集（`EhClient.java:45-210`）。

breeze 已具备：`WindHttp`（Rust reqwest 封装，支持代理/自定义头/下载）、`crypto` 与 `html` 依赖、Miuix 组件库、auto_route、ObjectBox、下载队列、阅读器。

## 约束

- 新代码**不写注释**（用户持续要求）
- 页面/生成文件规则照旧：`*.g.dart`/`*.freezed.dart`/`router.gr.dart`/`lib/src/rust/` 勿手改
- 涉及 objectbox 模型、auto_route 路由需重新生成（build_runner 一把出）
- 验证命令：`flutter analyze --no-pub`；冒烟 `flutter run -d linux`（需 `dangerouslyDisableSandbox`）
- 插件代码在本阶段**不删**，最后一个阶段统一移除

## 总体架构

新增 `lib/source/` 目录，两个独立实现 + 一个共享集成层：

```
lib/source/
├── core/                        # 共享集成层
│   ├── source_registry.dart     # 原生源注册表：id(bika/eh) → 入口路由、封面加载、下载分发
│   ├── native_image_fetch.dart  # 原生图片下载（WindHttp，带来源专属 headers/线路重写）
│   └── history_bridge.dart      # 接入 breeze 历史/下载/本地收藏（复用 ObjectBox 实体，sourceId=bika/eh）
├── bika/
│   ├── api/                     # bika_client.dart（签名 headers + host 切换）、endpoints
│   ├── models/                  # ComicItem/Chapter/ImageDetail/Comment/Profile 等
│   ├── auth/                    # authorization token 持久化（复用 UserSetting.bikaSettingData）
│   ├── cubit/                   # 每页面一个 cubit
│   └── view/                    # login/home(分类+推荐)/rank/search/detail/comments/mine/settings
└── eh/
    ├── api/                     # eh_url.dart、eh_client.dart、gallery_list_parser.dart、
    │                            # gallery_detail_parser.dart、gallery_page_parser.dart（图片页 imgkey 解析）
    ├── auth/                    # cookie 管理（新增 UserSetting.ehSettingData 字段）
    ├── models/                  # GalleryInfo/GalleryDetail/GalleryTag/Comment/PreviewSet
    ├── cubit/
    └── view/                    # login(cookie)/home(分类+热门+最新)/search(高级)/detail(标签+评论+预览)/
                                 # reader_bridge/comments/favorites/mytags/settings(site 切换 e/ex)
```

UI 形态仿原应用（页面结构、功能布局对照 haka/EhViewer），但组件与视觉用 breeze 现有 Miuix 体系（与全应用一致）。**阅读器复用 breeze 现有 comic_read**：为原生源实现同构的章节快照加载（喂原生图片列表给现有阅读器），不重写阅读器（这是"能复用就复用"的最大件）。

## 实施步骤

### 阶段 A：共享集成层（先行，半天级）
1. `lib/source/core/source_registry.dart`：注册 `bika`/`eh` 两个原生 sourceId，提供封面/图片加载分发（native_image_fetch），接入 `lib/network/http/picture/picture.dart` 的 `getCachePicture`/`downloadImageWithRetry` 分支（原生源走 WindHttp 直取，bika 保留 go2778 重写开关）。
2. `lib/object_box/model.dart`：`UserSetting` 增加 `ehSettingData` 字段（复用 `bikaSettingData` 存 bika 原生登录态与设置）；跑 build_runner。
3. auto_route 注册新页面路由（随阶段 B/C 页面逐步加）。
4. 下载队列分发：`lib/service/download/` 中按 sourceId 分流到原生图片抓取。

### 阶段 B：bika 原生（与阶段 C 并行）
1. API 层：移植 haka `lib/network/http.dart` + `utils.dart` → `bika_client.dart`（WindHttp + crypto HMAC 签名 + 双线路切换 + `bikaImageAcceleration` 图片重写沿用现有全局开关）。
2. 模型层：移植 haka `models.dart` 所需子集。
3. 页面（Miuix 组件实现，结构对照 haka views）：
   - 登录页（账密登录，token 持久化；签到按钮）
   - 首页（分类宫格 + 推荐/最新/汉化分页流）
   - 排行榜页（haka rank 结构）
   - 搜索页（关键字 + 分类筛选）
   - 详情页（封面/标签/章节/评论入口/点赞收藏）
   - 评论页（列表/回复/点赞，复用 breeze 评论页交互形态）
   - 个人中心 + 设置页（线路切换主/备、账号管理、图片质量）
4. 阅读接入：实现 bika 章节快照 provider → 现有阅读器；收藏/历史写入 source_registry 桥接。

### 阶段 C：EH 原生（与阶段 B 并行）
1. API 层：移植 EhUrl/EhCookieStore/GalleryListParser/GalleryDetailParser/图片页解析（`html` 包替代 Jsoup；WindHttp 带 cookie headers；站点常量 e-hentai/exhentai）。
2. 模型层：GalleryInfo/GalleryDetail/GalleryTag/Comment。
3. 页面：
   - 登录页（cookie 粘贴/手动录入三件套 ipb_member_id/ipb_pass_hash/igneous，支持 e/ex 站点切换）
   - 首页（分类树 + 热门 + 最新分页流，列表卡片仿 EhViewer 紧凑行/缩略图布局）
   - 搜索（关键字 + 分类位掩码筛选 + 高级搜索项：星级/语言/排序）
   - 详情页（预览图集、标签分组、评分、收藏、种子入口）
   - 评论页（读取/发表/回复）
   - 排行/热门页、远端收藏页、watched 标签页、我的标签管理
   - 设置页（站点切换、GP/限制显示）
4. 阅读接入：gallery 图片页解析 → 现有阅读器；下载/历史/本地收藏经 source_registry 桥接。

### 阶段 D：入口与插件移除
1. 应用入口：分类/首页聚合处把 bika、eh 作为一等入口（原生页面路由），移除对应插件入口逻辑。
2. 从 `rust/build.rs` 内置插件清单移除 breeze-plugin-bika-comic、EH 插件；清理 `disableBika` 相关开关与 `lib/config/bika/bika_setting.dart` 旧结构（迁移路径已由原生登录态接管）。
3. 清理插件侧死代码（仅限这两个插件相关分支）。

## 关键复用清单

| 能力 | 复用点 |
|------|--------|
| HTTP | `WindHttp`（lib/network/http/wind_http.dart，含代理四态联动） |
| HTML 解析 | `html` 包（pubspec 已有） |
| 签名 | `crypto` 包（pubspec 已有） |
| 阅读器 | 现有 comic_read（喂原生章节快照） |
| 下载/书架/历史 | ObjectBox 实体 + lib/service/download 队列（按 sourceId 分流） |
| 图片缓存 | picture.dart 缓存体系（新增原生分支） |
| 设置存储 | UserSetting.bikaSettingData（bika）/ 新增 ehSettingData（eh） |
| i18n | slang 双语文件 |

## 验证

1. `flutter analyze --no-pub`：lib/ 零新增告警。
2. build_runner / slang 重生成无冲突。
3. `flutter run -d linux` 冒烟：启动无异常，bika/eh 入口可进入。
4. 手动验证（需真实网络）：bika 登录→分类→详情→阅读→评论；eh 贴 cookie→列表→详情→阅读→收藏。沙箱内无法完成外网请求的，标记为用户手测项。
5. 阶段 D 后确认内置二进制不再捆绑两个插件 bundle、应用内无残留入口。

## 风险与说明

- EH 为 HTML 解析型 API，页面结构变动易碎；解析器按 EhViewer 的容错写法（多套 parse 策略）移植。
- exhentai 匿名不可用，未登录/cookie 失效需明确 sad-panda 等价提示页。
- 工程量大：bika（全功能移植 haka）与 EH（尽量全功能）并行推进，分 PR 级提交（阶段 A→B/C→D 各自可运行）。
- 两个参考项目接口细节以移植时实际代码为准，本计划不预填端点常量。
