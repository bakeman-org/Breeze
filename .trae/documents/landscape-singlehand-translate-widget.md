# 横屏 + 单手可拖拽 FAB + 漫画翻译 + 桌面小部件

## Context

用户提出 4 个新功能，需要在 `ai-porting` 分支上分阶段实施。现状调研结论：

- **横屏**：仅阅读器内已支持（[reader_orientation_controller.dart](file:///home/etcix/code/flutter/breeze/lib/page/comic_read/controller/reader_orientation_controller.dart)），启动时 [app_services.dart:250-255](file:///home/etcix/code/flutter/breeze/lib/main_entry_deps/app_services.dart#L250) 锁定手机竖屏。平板检测 `isTabletWithOutContext()` 阈值 600px（[debouncer.dart:37-54](file:///home/etcix/code/flutter/breeze/lib/util/debouncer.dart)）。部分页面已有响应式（bookshelf/comic_follow 用 `LayoutBuilder`+宽度阈值切换 grid/list）。
- **单手 FAB**：已有 `leftHandModeEnabled` 全局开关（[global_setting.dart:144](file:///home/etcix/code/flutter/breeze/lib/config/global/global_setting.dart#L144)），comic_info/discover/reader 已支持左右对齐，但**无可拖拽 FAB、无位置持久化**。
- **翻译**：完全未实现，仅 [content_network_setting_page.dart:82](file:///home/etcix/code/flutter/breeze/lib/page/setting/global/content_network_setting_page.dart#L82) 有 `Icons.translate_outlined` 占位。reader 渲染管线清晰：[ReadImageWidget](file:///home/etcix/code/flutter/breeze/lib/page/comic_read/widgets/image/read_image_widget.dart) → [ImageDisplay](file:///home/etcix/code/flutter/breeze/lib/page/comic_read/widgets/image/image_display.dart)（本地 `FileImage`，`imagePath` 可拿到 bytes 喂 OCR）。WindHttp 客户端可复用。
- **小部件**：完全未配置 home_widget。Android 包名 `com.zephyr.breeze`，minSdk = flutter 默认。`UnifiedComicDownload` 实体有 `cover`（JSON 含 url/path）、`storageRoot`、`comicId`、`source`、`title`，可作小部件数据源。无 deep link scheme。

用户确认：横屏全应用、FAB 关键页面（详情/阅读/追更/书架）、翻译用 OCR+在线 API、小部件显示下载漫画+小部件内浏览+插件入口+详情/收藏入口。

## 实施策略：4 阶段独立提交

每个阶段独立可验证、可回滚。建议每阶段完成后 `new_context` 开新会话执行下一阶段（避免上下文爆炸）。

---

## 阶段 1：全应用横屏 + 响应式布局

### 改动点

1. **解除竖屏锁定** — [app_services.dart:250-255](file:///home/etcix/code/flutter/breeze/lib/main_entry_deps/app_services.dart#L250)
   - 删除非平板的 `setPreferredOrientations([portraitUp, portraitDown])` 调用
   - 改为：平板保持不锁；手机也允许 `landscapeLeft/right`（用户旋转系统自动跟随）
   - 阅读器内 [reader_orientation_controller.dart](file:///home/etcix/code/flutter/breeze/lib/page/comic_read/controller/reader_orientation_controller.dart) 现有的 `setLandscape/restorePortrait` 逻辑改为「阅读器内根据 `readSetting.landscapeReader` 强制横屏，退出时释放回系统跟随」——保留现有行为，只是退出后不再强制竖屏

2. **响应式布局补全** — 扫描 lib/ 下所有未做宽度适配的列表/网格页：
   - 已有：[bookshelf_page.dart:107](file:///home/etcix/code/flutter/breeze/lib/page/bookshelf/view/bookshelf_page.dart#L107)、[comic_follow_page.dart:143-156](file:///home/etcix/code/flutter/breeze/lib/page/comic_follow/view/comic_follow_page.dart#L143)
   - 待补：发现页 discover、搜索结果 search_result、bika/eh 首页列表、设置页 more（已用 `ConstrainedBox(maxWidth: 768)` 居中，横屏 OK）、comic_info 详情（横屏做双栏：左侧封面+操作，右侧章节+预览）
   - 模式：`LayoutBuilder` 取 `constraints.maxWidth`，≥720 用 grid/双栏，<720 保持 list/单栏。复用 comic_follow 已有的 `_buildGrid/_buildList` 切换模式

3. **详情页双栏** — [comic_info.dart](file:///home/etcix/code/flutter/breeze/lib/page/comic_info/view/comic_info.dart) `_infoView`
   - 横屏（width ≥ 720）：`Row` 左栏（封面+操作+元数据，固定宽度 360）+ 右栏（章节列表+预览+推荐，Expanded）
   - 竖屏：保持现有单栏 `CustomScrollView`

4. **Reader 横屏阅读设置保留** — `readSetting.landscapeReader` 已存在，不动

### 关键文件
- `lib/main_entry_deps/app_services.dart`
- `lib/page/comic_info/view/comic_info.dart`
- `lib/source/bika/view/bika_home_page.dart`、`bika_favorites_page.dart`、`bika_search_page.dart`
- `lib/source/eh/view/eh_home_page.dart`、`eh_favorites_page.dart`、`eh_search_page.dart`
- `lib/page/discover/view/discover_page.dart`
- `lib/page/search_result/`（如需）

### 验证
- 手机转横屏，所有列表页自动切 grid（≥720）或保持单栏
- 详情页横屏出现双栏布局
- 阅读器内横屏行为不变

---

## 阶段 2：可拖拽 + 位置持久化 FAB group

### 改动点

1. **FAB 位置存储** — 新增 ObjectBox 实体 `FabPosition`（或用 SharedPreferences 存 `Map<String, List<double>>`，key=页面标识，value=[dx,dy]）。**推荐 SharedPreferences**：FAB 位置数量少（4 页），无需 ObjectBox 事务开销。新增 `FabPositionStore` 工具类（`lib/util/fab_position_store.dart`），提供 `getOffset(String pageKey)` / `saveOffset(String pageKey, Offset)`。

2. **可拖拽 FAB 容器** — 新建 `lib/widgets/draggable_fab_group.dart`：
   - `StatefulWidget`，内部用 `Positioned` + `GestureDetector(onPanUpdate)` 在 `Stack` 内拖动
   - 拖动结束时调用 `FabPositionStore.saveOffset(pageKey, offset)`
   - 边界约束：用 `MediaQuery.of(context).size` + FAB 自身尺寸 clamp，避免拖出屏幕
   - 初始位置：读 store，无记录则回退到 `leftHandModeEnabled ? Alignment.centerLeft : Alignment.centerRight`
   - 长按重置位置（可选，防用户拖到死角）

3. **4 个关键页面接入**：
   - [comic_info_fabs.dart](file:///home/etcix/code/flutter/breeze/lib/page/comic_info/widgets/comic_info_fabs.dart) — 包成 `DraggableFabGroup(pageKey: 'comic_info', child: ComicInfoFabGroup(...))`，移除 `MiuixFabPosition` 用法（改为 Stack 内自由定位）
   - [comic_read.dart](file:///home/etcix/code/flutter/breeze/lib/page/comic_read/view/comic_read.dart) — 阅读器现有 auto-read FAB ([comic_read_auto_read_part.dart:59-64](file:///home/etcix/code/flutter/breeze/lib/page/comic_read/view/parts/comic_read_auto_read_part.dart#L59)) 改为可拖拽，pageKey `'reader_auto_read'`
   - [comic_follow_page.dart](file:///home/etcix/code/flutter/breeze/lib/page/comic_follow/view/comic_follow_page.dart) — 当前无 FAB，新增 `DraggableFabGroup(pageKey: 'follow', child: 读FAB组(刷新/筛选未读)）`
   - [bookshelf_page.dart](file:///home/etcix/code/flutter/breeze/lib/page/bookshelf/view/bookshelf_page.dart) — 当前 FAB（如有）包成可拖拽，pageKey `'bookshelf'`

4. **单手模式语义升级** — `leftHandModeEnabled` 现在仅控制初始对齐方向；用户拖拽后位置持久化覆盖初始值。设置页文案改为「单手模式（初始位置）」

### 关键文件
- `lib/util/fab_position_store.dart`（新）
- `lib/widgets/draggable_fab_group.dart`（新）
- `lib/page/comic_info/widgets/comic_info_fabs.dart`
- `lib/page/comic_read/view/parts/comic_read_auto_read_part.dart`
- `lib/page/comic_follow/view/comic_follow_page.dart`
- `lib/page/bookshelf/view/bookshelf_page.dart`
- `lib/page/setting/global/app_behavior_setting_page.dart`（文案）

### 验证
- 详情页 FAB 可拖拽，杀进程重启位置保留
- 阅读器 auto-read 按钮可拖拽
- 追更页新增的 FAB 可拖拽
- 拖到屏幕边缘不越界

---

## 阶段 3：实验性漫画翻译（OCR + 在线 API）

### 改动点

1. **依赖** — `pubspec.yaml` 新增：
   - `google_mlkit_text_recognition: ^0.14.0`（OCR，支持中日韩）
   - 复用现有 `wind_http` 或 `http` 做翻译 API 调用

2. **设置** — `GlobalSettingState` 新增字段（[global_setting.dart:117-160](file:///home/etcix/code/flutter/breeze/lib/config/global/global_setting.dart#L117)）：
   ```dart
   @Default(false) bool enableTranslation,        // 实验性开关
   @Default('google') String translationProvider, // 'google'|'deepl'|'custom'
   @Default('') String translationApiKey,
   @Default('zh') String translationTargetLang,
   ```
   在 [app_behavior_setting_page.dart](file:///home/etcix/code/flutter/breeze/lib/page/setting/global/app_behavior_setting_page.dart) 加「实验性功能」分组，入口 `enableTranslation` + 子页配置 provider/key/lang

3. **翻译服务** — 新建 `lib/service/translation/`：
   - `translation_service.dart`：`Future<List<TranslatedBlock>> translateImage(String imagePath)` 
     - 读 `File(imagePath).readAsBytes()` → `InputImage.fromBytes(...)`
     - `TextRecognizer(script: TextRecognitionScript.chinese)` 跑 OCR，拿到 `List<TextBlock>`（含 `rect` 和 `text`）
     - 按 provider 调翻译 API（google: `https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=zh&dt=t&q=<text>`，无需 key；deepl: POST with key）
     - 返回 `[{rect: Rect, original: String, translated: String}]`
   - `translation_api.dart`：封装 HTTP 调用，复用 `WindHttp` 模式

4. **阅读器浮层** — 新建 `lib/page/comic_read/view/parts/comic_read_translation_part.dart`（part of comic_read.dart）：
   - 在 [ReadImageWidget](file:///home/etcix/code/flutter/breeze/lib/page/comic_read/widgets/image/read_image_widget.dart#L56) 的 `ImageDisplay` 上方叠一层 `CustomPaint`/`Stack`，按 `TranslatedBlock.rect` 绘制译文文本框（半透明底 + 译文）
   - 触发：阅读器顶栏新增「翻译」按钮（仅在 `enableTranslation=true` 时显示），点击对当前页执行翻译并缓存结果
   - 翻译进行中显示 loading 蒙层

5. **缓存** — 翻译结果按 `comicId:chapterId:pageIndex` 存内存 `Map`，同一页不重复 OCR

### 关键文件
- `pubspec.yaml`
- `lib/config/global/global_setting.dart`
- `lib/service/translation/translation_service.dart`（新）
- `lib/service/translation/translation_api.dart`（新）
- `lib/page/comic_read/view/parts/comic_read_translation_part.dart`（新）
- `lib/page/comic_read/widgets/image/read_image_widget.dart`（叠加 overlay）
- `lib/page/setting/global/app_behavior_setting_page.dart`

### 验证
- 设置开启翻译，阅读器顶栏出现翻译按钮
- 点击翻译，当前页 OCR → 译文浮层覆盖原文位置
- 切页后重新点击翻译生效
- 关闭翻译开关后浮层消失

---

## 阶段 4：桌面小部件（下载漫画浏览 + 插件/详情/收藏入口）

### 改动点

1. **依赖** — `pubspec.yaml` 新增 `home_widget: ^0.7.0`（iOS 14+ / Android 21+）

2. **Deep link scheme** — 注册 `breeze://` scheme：
   - AndroidManifest.xml `<intent-filter>` 新增 `<data android:scheme="breeze"/>` + `<action android:VIEW"/>`
   - iOS Info.plist 新增 `CFBundleURLTypes` + `breeze`
   - 新建 `lib/util/deep_link.dart`：解析 `breeze://comic/{id}?from={source}` → `ComicInfoRoute`、`breeze://plugin` → 插件页、`breeze://favorite` → 收藏页

3. **数据喂给小部件** — 新建 `lib/service/home_widget/home_widget_service.dart`：
   - `updateWidgetData()`：查 `objectbox.unifiedDownloadBox`（[model.dart:571](file:///home/etcix/code/flutter/breeze/lib/object_box/model.dart#L571)）取最近 N 条 `deleted=false` 的下载，序列化为 JSON（title/comicId/source/coverPath）
   - 调 `HomeWidget.saveWidgetData('recent_comics', jsonStr)` + `HomeWidget.updateWidget(name: 'BreezeRecentWidget')`
   - 触发点：下载完成时（[download_queue_manager.dart](file:///home/etcix/code/flutter/breeze/lib/service/download/download_queue_manager.dart) 完成回调）、app 启动时

4. **Android 原生小部件** — 新建：
   - `android/app/src/main/res/xml/breeze_recent_widget_info.xml`：AppWidgetProvider 元数据（4×3 格子，可缩放）
   - `android/app/src/main/java/com/zephyr/breeze/BreezeRecentWidgetProvider.kt`：`AppWidgetProvider`，`onUpdate` 读 `HomeWidget` 存的 JSON，用 `RemoteViewsService` + `RemoteViewsFactory` 渲染 ListView（封面+标题）
   - `android/app/src/main/AndroidManifest.xml`：注册 `<receiver android:name=".BreezeRecentWidgetProvider">` + `<intent-filter APPWIDGET_UPDATE>` + `<meta-data APPWIDGET_PROVIDER>`
   - ListView item 点击 → 发 `breeze://comic/{id}` intent

5. **iOS WidgetKit** — 新建 `ios/BreezeWidget/` Widget Extension target：
   - `BreezeWidget.swift`：`Widget` 配置（`.systemSmall/.systemMedium`），用 `AppGroup` 读 `UserDefaults` 存的 JSON
   - `Info.plist`：`NSExtension` 配置
   - 需 Xcode 手动加 target + App Group（文档说明，CI 无法自动）
   - **iOS 部分本阶段仅出代码骨架 + 文档**，用户需在 Xcode 内手动加 target

6. **插件入口** — [plugin_registry_service.dart:49-59](file:///home/etcix/code/flutter/breeze/lib/plugin/plugin_registry_service.dart#L49) 暴露的 `PluginInfo` 列表喂给小部件第二个数据字段 `plugins`，小部件底部显示「插件」入口按钮，点击 `breeze://plugin`

### 关键文件
- `pubspec.yaml`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/xml/breeze_recent_widget_info.xml`（新）
- `android/app/src/main/java/com/zephyr/breeze/BreezeRecentWidgetProvider.kt`（新）
- `android/app/src/main/java/com/zephyr/breeze/BreezeRemoteViewsFactory.kt`（新）
- `android/app/src/main/java/com/zephyr/breeze/BreezeRemoteViewsService.kt`（新）
- `ios/BreezeWidget/`（新，骨架 + 文档）
- `lib/service/home_widget/home_widget_service.dart`（新）
- `lib/util/deep_link.dart`（新）
- `lib/service/download/download_queue_manager.dart`（完成回调触发更新）

### 验证
- Android 桌面长按 → 添加 Breeze 小部件 → 显示最近下载漫画列表
- 点击列表项进入对应漫画详情页
- 点击「插件」入口进入插件页
- 下载新漫画后小部件自动刷新
- iOS 需用户在 Xcode 加 target 后才能验证

---

## 执行顺序建议

1. **阶段 1 先做**（横屏），因为响应式布局改动会影响阶段 2 的 FAB 定位逻辑
2. **阶段 2**（可拖拽 FAB），独立于翻译和小部件
3. **阶段 3**（翻译）和 **阶段 4**（小部件）可任意顺序，互不依赖

**每阶段完成后建议 `new_context` 开新会话执行下一阶段**，避免单次上下文过大。每阶段独立提交到 `ai-porting`。

## 全局验证

每阶段完成后：
- `dart run build_runner build`（如改了 freezed/router）
- `flutter analyze` 零 error
- 手动验证该阶段的功能点
- 提交到 `ai-porting` 分支
