import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/comic_read/method/image_size_cache_store.dart';
import 'package:zephyr/page/comic_read/widgets/layout/read_layout.dart';

/// 已测页高度的滑动窗口大小。
///
/// JM 同章各页尺寸高度一致，取样再多也不会更准。16 条足够稳定，
/// 同时不会让"某一页是跨页大图"这种异常值长期影响估算。
const int _kSampleLimit = 16;

/// 兜底高宽比：整章都没测出任何一页时使用。
///
/// 1.42 是 JM 页在常见分辨率下的典型比例（如 1080×1530）。
/// 之前写死的 1.2 让未测页的估算比真实高度矮约 18%——滑动条跳页时
/// 200 页的累计误差可达数千像素，`jumpTo` 落点严重偏前，再靠
/// `observerController` 精修，就表现为"流水式从头加载"。
const double _kDefaultAspect = 1.42;

/// 图片尺寸状态。
///
/// 除精确缓存（[sizeCache] / [resolvedIndices]）外，额外维护
/// [estimatedHeight]——本章已测页高度的中位数，用于估算未测页。
class ImageSizeState {
  final Map<int, Size> sizeCache;
  final Set<int> resolvedIndices;
  final double defaultWidth;
  final double defaultHeight;

  /// 本章已测页高度的中位数（像素）。
  ///
  /// - `> 0` 表示本章已有测量样本，未测页用它估算。
  /// - `0` 表示整章都没测过，走 [defaultHeight] 兜底。
  final double estimatedHeight;

  ImageSizeState({
    required this.sizeCache,
    required this.resolvedIndices,
    required this.defaultWidth,
    required this.defaultHeight,
    this.estimatedHeight = 0,
  });

  /// 取某页的展示尺寸。
  ///
  /// 优先级：
  ///   1. 已测量 → 精确值；
  ///   2. 未测量但本章已有样本 → 中位数估算（JM 同章页尺寸高度一致，
  ///      测到 3~5 页后误差基本可以忽略）；
  ///   3. 整章都没测过 → 兜底 [defaultHeight]。
  ///
  /// 三种情况都会填满 width/height，调用方不需要判空。
  Size getSizeValue(int index) {
    if (resolvedIndices.contains(index)) {
      return sizeCache[index]!;
    }
    if (estimatedHeight > 0) {
      return Size(defaultWidth, estimatedHeight);
    }
    return Size(defaultWidth, defaultHeight);
  }
}

class ImageSizeCubit extends Cubit<ImageSizeState> {
  static const Duration _saveDebounceDuration = Duration(milliseconds: 300);

  final int count;
  final double defaultWidth;
  final double defaultHeight;
  final String sourceTag;
  final List<String> pageKeys;
  final int chapterOrder;
  final ImageSizeCacheStore _cacheStore;

  /// 已测页高度的滑动窗口。中位数在这里算，不在 `getSizeValue` 里重算——
  /// 后者是每页每帧都要走的路径。
  final List<double> _recentHeights = <double>[];

  Timer? _saveTimer;
  bool _hasPendingSave = false;
  bool _isFlushing = false;
  bool _isDisposed = false;

  ImageSizeCubit({
    required this.count,
    required this.defaultWidth,
    required this.defaultHeight,
    required this.sourceTag,
    required this.pageKeys,
    required this.chapterOrder,
    required bool hydrateOnInit,
    required Map<int, Size> initialCache,
    required Set<int> initialResolved,
  }) : _cacheStore = ImageSizeCacheStore(
         sourceTag: sourceTag,
         pageKeys: pageKeys,
       ),
       super(
         ImageSizeState(
           sizeCache: initialCache,
           resolvedIndices: initialResolved,
           defaultWidth: defaultWidth,
           defaultHeight: defaultHeight,
         ),
       ) {
    // 从初始（已 hydrate 的）缓存构建中位数样本。
    for (final index in initialResolved) {
      final size = initialCache[index];
      if (size != null && size.height > 0) {
        _recentHeights.add(size.height);
      }
    }
    _trimSamples();
    _emitWithEstimate();

    if (hydrateOnInit) {
      unawaited(_hydrateFromDisk());
    }
  }

  factory ImageSizeCubit.create({
    required double defaultWidth,
    required int count,
    required String sourceTag,
    required List<String> pageKeys,
    required int chapterOrder,
    Map<int, Size>? persistedCache,
  }) {
    // 兜底高宽比从 1.2 改为 1.42：这是跳页是否"秒出"的关键差异。
    // 见文件头 _kDefaultAspect 说明。
    final double defaultHeight = defaultWidth * _kDefaultAspect;

    final initialCache = <int, Size>{};
    final initialResolved = <int>{};

    // 先用默认尺寸填满所有页，保证第一帧每一项都有确定高度。
    for (int i = 0; i < count; i++) {
      initialCache[i] = Size(defaultWidth, defaultHeight);
    }

    // 再用持久化的精确尺寸覆盖。
    if (persistedCache != null && persistedCache.isNotEmpty) {
      for (final entry in persistedCache.entries) {
        if (entry.key < 0 || entry.key >= count) continue;
        // 持久化以本地页索引为键，运行时以章节哈希索引为键，这里做映射。
        final cacheIndex = resolveStableSizeCacheIndex(
          chapterOrder: chapterOrder,
          localPageIndex: entry.key,
        );
        initialCache[cacheIndex] = entry.value;
        initialResolved.add(cacheIndex);
      }
    }

    return ImageSizeCubit(
      count: count,
      defaultWidth: defaultWidth,
      defaultHeight: defaultHeight,
      sourceTag: sourceTag,
      pageKeys: pageKeys,
      chapterOrder: chapterOrder,
      hydrateOnInit: persistedCache == null,
      initialCache: initialCache,
      initialResolved: initialResolved,
    );
  }

  ({Size size, bool isCached}) getSize(int index) {
    final size = state.getSizeValue(index);
    final isCached = state.resolvedIndices.contains(index);
    return (size: size, isCached: isCached);
  }

  void updateSize(int index, Size newSize) {
    final isAlreadyResolved = state.resolvedIndices.contains(index);
    final isSizeChanged = state.sizeCache[index] != newSize;

    if (!isAlreadyResolved || isSizeChanged) {
      final newCache = Map<int, Size>.from(state.sizeCache);
      newCache[index] = newSize;
      final newResolved = Set<int>.from(state.resolvedIndices);
      newResolved.add(index);

      // 同一页重复测量时，旧值先移出窗口再加新值，避免样本被同一页占满。
      if (isAlreadyResolved) {
        final old = state.sizeCache[index];
        if (old != null && old.height > 0) {
          _recentHeights.remove(old.height);
        }
      }
      if (newSize.height > 0) {
        _recentHeights.add(newSize.height);
      }
      _trimSamples();

      emit(
        ImageSizeState(
          sizeCache: newCache,
          resolvedIndices: newResolved,
          defaultWidth: state.defaultWidth,
          defaultHeight: state.defaultHeight,
          estimatedHeight: _median(_recentHeights),
        ),
      );
      _markDirtyAndScheduleSave();
    }
  }

  Future<void> _hydrateFromDisk() async {
    try {
      final persisted = await _cacheStore.readIndexedSizes(
        pageKeys: pageKeys,
        count: count,
      );
      if (persisted.isEmpty || _isDisposed) return;

      final newCache = Map<int, Size>.from(state.sizeCache);
      final newResolved = Set<int>.from(state.resolvedIndices);
      var changed = false;

      for (final entry in persisted.entries) {
        // 与 create 一致：本地页索引 → 运行时章节哈希索引。
        final cacheIndex = resolveStableSizeCacheIndex(
          chapterOrder: chapterOrder,
          localPageIndex: entry.key,
        );
        newCache[cacheIndex] = entry.value;
        newResolved.add(cacheIndex);

        // 补齐中位数样本。
        if (entry.value.height > 0) {
          _recentHeights.add(entry.value.height);
        }
        changed = true;
      }

      if (changed) {
        _trimSamples();
        emit(
          ImageSizeState(
            sizeCache: newCache,
            resolvedIndices: newResolved,
            defaultWidth: state.defaultWidth,
            defaultHeight: state.defaultHeight,
            estimatedHeight: _median(_recentHeights),
          ),
        );
      }
    } catch (_) {}
  }

  void _trimSamples() {
    if (_recentHeights.length > _kSampleLimit) {
      _recentHeights.removeRange(0, _recentHeights.length - _kSampleLimit);
    }
  }

  void _emitWithEstimate() {
    if (_isDisposed) return;
    emit(
      ImageSizeState(
        sizeCache: state.sizeCache,
        resolvedIndices: state.resolvedIndices,
        defaultWidth: state.defaultWidth,
        defaultHeight: state.defaultHeight,
        estimatedHeight: _median(_recentHeights),
      ),
    );
  }

  /// 中位数。用中位数而不是平均值：偶尔一页跨页大图不该把整章的估算带偏。
  static double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = List<double>.from(values)..sort();
    return sorted[sorted.length ~/ 2];
  }

  void _markDirtyAndScheduleSave() {
    _hasPendingSave = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounceDuration, () {
      unawaited(flushNow());
    });
  }

  Future<void> flushNow() async {
    if (_isDisposed || !_hasPendingSave) return;
    if (_isFlushing) return;

    _isFlushing = true;
    _hasPendingSave = false;
    try {
      // 运行时索引（章节哈希）→ 本地页索引，持久化层只认本地页索引。
      final localSizes = <int, Size>{};
      final localResolved = <int>{};
      final max = count < pageKeys.length ? count : pageKeys.length;
      for (var i = 0; i < max; i++) {
        final runtimeIndex = resolveStableSizeCacheIndex(
          chapterOrder: chapterOrder,
          localPageIndex: i,
        );
        if (!state.resolvedIndices.contains(runtimeIndex)) continue;
        final size = state.sizeCache[runtimeIndex];
        if (size == null) continue;
        localSizes[i] = size;
        localResolved.add(i);
      }
      await _cacheStore.write(
        pageKeys: pageKeys,
        sizeCache: localSizes,
        resolvedIndices: localResolved,
        count: count,
      );
    } catch (_) {
      _hasPendingSave = true;
    } finally {
      _isFlushing = false;
    }
  }

  Future<({int recordCount, int fileBytes, String filePath})>
  getCacheStats() async {
    return _cacheStore.getStats();
  }

  Future<void> debugPrintCacheStats() async {
    final stats = await getCacheStats();
    logger.d(
      '[ImageSizeCache] source=$sourceTag records=${stats.recordCount} '
      'bytes=${stats.fileBytes} path=${stats.filePath}',
    );
  }

  @override
  Future<void> close() async {
    _saveTimer?.cancel();
    await flushNow();
    _isDisposed = true;
    return super.close();
  }
}
