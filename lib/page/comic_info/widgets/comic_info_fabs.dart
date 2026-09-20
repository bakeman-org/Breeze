import 'package:material_ui/material_ui.dart';

/// 漫画详情页的浮动操作按钮组。
///
/// 自下而上排列：
///   1. 阅读 / 继续阅读（主按钮，extended，始终显示）
///   2. 下载 或 导出（二选一，根据 `isDownloaded` 切换）
///   3. 回到顶部（滚动超过阈值后淡入）
///
/// 支持左手模式：整组按钮切到屏幕左下角。
class ComicInfoFabGroup extends StatelessWidget {
  const ComicInfoFabGroup({
    super.key,
    required this.scrollController,
    required this.hasHistory,
    required this.isLeftHanded,
    required this.isDownloaded,
    required this.onRead,
    this.onDownload,
    this.onExport,
  });

  final ScrollController scrollController;
  final bool hasHistory;
  final bool isLeftHanded;

  /// 当前漫画是否已经下载。true → 显示导出；false → 显示下载。
  final bool isDownloaded;

  final VoidCallback onRead;

  /// 未下载时点击主「下载」FAB 触发的回调。
  /// 为 null 时不显示下载按钮（例如页面还没加载完）。
  final VoidCallback? onDownload;

  /// 已下载时点击「导出」FAB 触发的回调。
  /// 为 null 时不显示导出按钮。
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    // 已下载 → 导出；未下载 → 下载。对应的回调为 null 时退化为不显示。
    final VoidCallback? secondaryAction = isDownloaded ? onExport : onDownload;
    final IconData secondaryIcon = isDownloaded
        ? Icons.save_alt_rounded
        : Icons.download_rounded;
    final String secondaryTooltip = isDownloaded ? '导出' : '下载';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isLeftHanded
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        // 回到顶部：滚动超过阈值才淡入。
        _ScrollToTopFab(
          scrollController: scrollController,
          isLeftHanded: isLeftHanded,
        ),
        if (secondaryAction != null) ...[
          const SizedBox(height: 12),
          _MiniFab(
            icon: secondaryIcon,
            tooltip: secondaryTooltip,
            onPressed: secondaryAction,
          ),
        ],
        const SizedBox(height: 12),
        _ReadFab(hasHistory: hasHistory, onPressed: onRead),
      ],
    );
  }
}

/// 阅读主按钮。历史存在时显示「继续阅读」，否则「开始阅读」。
class _ReadFab extends StatelessWidget {
  const _ReadFab({required this.hasHistory, required this.onPressed});

  final bool hasHistory;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      icon: Icon(
        hasHistory ? Icons.history_rounded : Icons.menu_book_rounded,
        size: 18,
      ),
      label: Text(hasHistory ? '继续阅读' : '开始阅读'),
    );
  }
}

/// 次级圆形 FAB（下载 / 导出 / 回到顶部共用）。
class _MiniFab extends StatelessWidget {
  const _MiniFab({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: null,
      tooltip: tooltip,
      onPressed: onPressed,
      child: Icon(icon, size: 20),
    );
  }
}

/// 「回到顶部」FAB。滚动超过阈值后淡入，点击平滑滚回顶部。
class _ScrollToTopFab extends StatefulWidget {
  const _ScrollToTopFab({
    required this.scrollController,
    required this.isLeftHanded,
  });

  final ScrollController scrollController;
  final bool isLeftHanded;

  @override
  State<_ScrollToTopFab> createState() => _ScrollToTopFabState();
}

class _ScrollToTopFabState extends State<_ScrollToTopFab> {
  static const double _showThreshold = 800;

  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final next = widget.scrollController.offset > _showThreshold;
    if (next == _visible) return;
    setState(() => _visible = next);
  }

  void _scrollToTop() {
    if (!widget.scrollController.hasClients) return;
    widget.scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 180),
        child: IgnorePointer(
          ignoring: !_visible,
          child: _MiniFab(
            icon: Icons.vertical_align_top_rounded,
            tooltip: '回到顶部',
            onPressed: _scrollToTop,
          ),
        ),
      ),
    );
  }
}
