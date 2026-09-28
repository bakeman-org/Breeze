# 漫画翻译图片集生成 + 国内 API + 编辑器

## Context

当前翻译是临时浮层：离开图片即消失，Google 翻译国内不可直连且效果一般。用户要求升级为「生成完整翻译图片集」：原图/译文图双向对比、国内可直连的翻译 API、后台批量渲染整章翻译图片、翻译编辑器手动修正。用户原话「自行设计探索和实现，尽可能减少 token」——自主决策，分阶段提交。

## 关键决策（自主确定）

1. **国内 API = 百度翻译**：`https://fanyi-api.baidu.com/api/trans/vip/translate`，参数 `q/from/to/appid/salt/sign`，`sign = md5(appid + q + salt + 密钥)`。`crypto: ^3.0.6` 已在 pubspec，直接用 `md5.convert`。免费额度足够个人使用，国内直连。保留 google/deepl 可插拔。
2. **生成图片的气泡填充 = 白底黑字**（漫画通行做法），与浮层的黑底白字区分；浮层模式保持不变。
3. **译文图片存储 = `.translated/` 同级目录**：`<原图所在目录>/.translated/<原文件名>.png`；同目录 `.translated/<原文件名>.json` 存 `List<TranslatedBlock>` 供编辑器加载。
4. **阅读器三态切换**：off → overlay（实时浮层，现状）→ image（显示已生成的译文 PNG，无则回退原图）。顶栏翻译按钮长按改为「翻译整章」（后台任务），单击仍切换模式。
5. **编辑器 MVP = 仅文本编辑**：加载原图 + blocks JSON，点气泡改译文，保存后重渲染 PNG + 更新 JSON。不做 rect 拖拽（复杂度高，后续再议）。

## 复用要点

- `_TranslationPainter._drawFittedText`（[translation_overlay.dart#L137-L164](file:///home/etcix/code/flutter/breeze/lib/page/comic_read/widgets/image/translation_overlay.dart#L137-L164)）：字号自适应+裁剪逻辑，渲染 PNG 时复用（改画到 `ui.PictureRecorder` 的 Canvas）。
- `TranslationService.translateImage`（[translation_service.dart#L37-L103](file:///home/etcix/code/flutter/breeze/lib/service/translation/translation_service.dart#L37-L103)）：OCR + 翻译 + 归一化 rect，渲染器直接消费其返回的 `List<TranslatedBlock>`。
- `DownloadAssetStore.writeBytesAtomically`（[download_asset_store.dart#L242-L264](file:///home/etcix/code/flutter/breeze/lib/service/download/download_asset_store.dart#L242-L264)）：原子写 PNG 字节到磁盘。
- `fetch` HTTP 包装（translation_api.dart 已用）：百度 API 同样用 `fetch(query: ...)`。
- `TranslationController` 单例（[translation_service.dart#L121-L280](file:///home/etcix/code/flutter/breeze/lib/service/translation/translation_service.dart#L121-L280)）：扩展模式切换 + 批量任务状态。

## 分阶段实现

### Phase 1：百度翻译 API + provider 接入
- [translation_api.dart](file:///home/etcix/code/flutter/breeze/lib/service/translation/translation_api.dart)：`switch` 加 `case 'baidu'` → `_baidu(text, appId, secretKey, targetLang)`：`salt = Random().nextInt(1<<32).toString()`，`sign = md5.convert(utf8.encode(appId + q + salt + secretKey)).toString()`，`fetch(baiduUrl, query: {q, from:'auto', to, appid, salt, sign})`，解析 `data['trans_result']` 数组拼接 `dst`。
- [global_setting.dart#L146-L149](file:///home/etcix/code/flutter/breeze/lib/config/global/global_setting.dart#L146-L149)：加 `@Default('') String baiduAppId, @Default('') String baiduSecretKey`。
- [app_behavior_setting_page.dart](file:///home/etcix/code/flutter/breeze/lib/page/setting/global/app_behavior_setting_page.dart)：providers 列表加 `'baidu'`；`baidu` 选中时显示 appId + secretKey 两个输入项（复用 `_translationApiKey` 模式）。
- i18n：`zh_CN/en_US.i18n.json` translation 段加 `providerBaidu`/`baiduAppId`/`baiduSecretKey` 等键。
- `build_runner` 重新生成 freezed/json + `dart run slang` 重生成 i18n。
- 验证：`flutter analyze` 零 error + `dart format` + 设置页选百度、填 appId/secret、翻译一页成功。

### Phase 2：译文图片渲染器（PNG 落盘）
- 新建 `lib/service/translation/translation_image_renderer.dart`：
  - `class TranslationImageRenderer`：
    - `static Future<String?> render({required String imagePath, required List<TranslatedBlock> blocks})`：加载原图 `ui.Image`（`ImmutableBuffer`+`ImageDescriptor`→`decodeImage`）→ `PictureRecorder`+`Canvas` 按原图像素尺寸 → `drawImage(original)` → 逐 block：`canvas.drawRRect(白底圆角)` + `_drawFittedText`（黑字，从 overlay 提取共用逻辑）→ `picture.toImage` → `pngBytes = await image.toByteData(format: png)` → `writeBytesAtomically` 到 `.translated/<basename>.png` → 返回路径。
    - `static Future<void> saveBlocksJson(String imagePath, List<TranslatedBlock> blocks)`：`.translated/<basename>.json` 写 `jsonEncode(blocks.map(toJson))`。
    - `static translatedPathFor(String imagePath)` → `dirname/.translated/basename.png`；`blocksJsonPathFor` 同理。
    - `static Future<List<TranslatedBlock>?> loadBlocks(String imagePath)`：读 JSON 反序列化。
- 提取 `_drawFittedText` 到 `translation_overlay.dart` 的顶层函数或独立 `lib/service/translation/text_fit_painter.dart`，overlay 和 renderer 共用（overlay 传黑底白字参数，renderer 传白底黑字）。
- 验证：单页渲染后 `.translated/` 目录出现 PNG + JSON，PNG 用图片查看器打开文字填充正确。

### Phase 3：阅读器原图/译文切换
- `TranslationController` 加 `final viewMode = ValueNotifier<TranslationViewMode>(off)`，`enum TranslationViewMode { off, overlay, image }`。`toggleAutoMode` 改为 `cycleViewMode`：off→overlay→image→off。image 模式时停止自动翻译派发（仅显示已有 PNG）。
- [image_display.dart#L281-L285](file:///home/etcix/code/flutter/breeze/lib/page/comic_read/widgets/image/image_display.dart#L281-L285)：`Positioned.fill(TranslationOverlay)` 外层加 `ValueListenableBuilder<TranslationViewMode>`：image 模式时查 `TranslationImageRenderer.translatedPathFor(imagePath)` 是否存在 → 存在则 `Image.file(translatedPath)` 替换原图显示，overlay 隐藏；overlay 模式保持现状。
- [app_bar.dart#L94-L125](file:///home/etcix/code/flutter/breeze/lib/page/comic_read/widgets/chrome/app_bar.dart#L94-L125)：按钮图标随 mode 变化（off=translate 图标灰、overlay=translate 主色、image=photo_library 主色），单击 `cycleViewMode`。
- i18n 加 mode 切换 toast 文案。
- 验证：单击按钮三态循环，image 模式显示已生成 PNG，overlay 模式浮层正常。

### Phase 4：后台批量翻译任务
- 新建 `lib/service/translation/translation_batch_service.dart`：
  - `class TranslationBatchService` 单例：`final progress = ValueNotifier<BatchProgress?>`（`{completed, total, failed, currentImagePath}`）；`bool isRunning`。
  - `Future<void> runChapter({required List<String> imagePaths, ...})`：串行遍历，每页 `translateImage` → `TranslationImageRenderer.render` + `saveBlocksJson` → 更新 progress；失败页跳过计数；可 `cancel()`（`_cancelled = true` 循环退出）。
  - 完成后 toast 汇总（成功 N / 失败 M）。
- comic_read 页面：从页面状态取当前章节 `List<ReadModeEntry>` → 解析每页本地 `imagePath`（用 `DownloadAssetStore` 同样逻辑，或等 PictureBloc 已加载后读 `state.imagePath`）。最简方案：遍历 `_registeredPages` + 未构建页用 `DownloadAssetStore.findExisting()` 兜底解析路径。
- [app_bar.dart](file:///home/etcix/code/flutter/breeze/lib/page/comic_read/widgets/chrome/app_bar.dart)：长按改为「翻译整章」→ 启动 `TranslationBatchService.runChapter`，进度用顶部线性进度条或 toast。
- 验证：长按按钮，后台逐页渲染，`.translated/` 目录逐个生成 PNG，完成后切 image 模式可连续阅读整章译文。

### Phase 5：翻译编辑器
- 新建 `lib/page/comic_read/translation_editor/translation_editor_page.dart`：
  - `@RoutePage()`，参数 `imagePath`。加载原图 + `TranslationImageRenderer.loadBlocks(imagePath)`。
  - UI：`Stack` 显示原图 + 每个 block 的 `Positioned`（归一化 rect × 显示尺寸）半透明可点击矩形；点击弹出 `TextDialog` 编辑 `translated` 文本。
  - 保存：更新内存 blocks → `saveBlocksJson` + `render`（重渲染 PNG）→ toast + 返回。
- [router.dart#L68](file:///home/etcix/code/flutter/breeze/lib/config/router/router.dart)：加 `AutoRoute(page: TranslationEditorRoute.page)`；跑 `build_runner` 生 `router.gr.dart`。
- [app_bar.dart](file:///home/etcix/code/flutter/breeze/lib/page/comic_read/widgets/chrome/app_bar.dart)：image 模式时按钮区加「编辑当前页」入口（`context.pushRoute(TranslationEditorRoute(imagePath: ...))`）。
- i18n 加编辑器文案。
- 验证：image 模式进入编辑器，改某气泡译文，保存后阅读器译文图即时更新。

## 每阶段验证
- `/home/etcix/Downloads/temp/flutter/bin/flutter analyze`（需 `dangerouslyDisableSandbox: true`）零 error
- `/home/etcix/Downloads/temp/flutter/bin/dart format lib/`
- 每阶段 commit（不 push），commit message 描述阶段
- build_runner：`/home/etcix/Downloads/temp/flutter/bin/dart run build_runner build --delete-conflicting-outputs`
- slang：`/home/etcix/Downloads/temp/flutter/bin/dart run slang`

## 不改动
- `lib/widgets/draggable_fab_group.dart`、`lib/util/fab_position_store.dart`
- `android/app/build.gradle.kts` 的 ML Kit 中文依赖
- 既有浮层 overlay 的黑底白字样式（仅抽取共用绘制函数）
