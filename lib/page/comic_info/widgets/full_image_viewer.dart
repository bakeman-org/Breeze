import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/comic_read/json/common_ep_info_json/common_ep_info_json.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/widgets/picture_bloc/bloc/picture_bloc.dart';
import 'package:zephyr/widgets/picture_bloc/models/picture_info.dart';

/// 全屏图片查看器，支持左右滑动切换上一张/下一张。
class FullImageViewer extends StatefulWidget {
  const FullImageViewer({
    super.key,
    required this.docs,
    required this.initialIndex,
    required this.comicId,
    required this.from,
  });

  final List<Doc> docs;
  final int initialIndex;
  final String comicId;
  final String from;

  @override
  State<FullImageViewer> createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<FullImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  /// 当前页是否处于放大状态（放大时禁用 PageView 滚动）。
  bool _currentPageZoomed = false;

  @override
  void initState() {
    super.initState();
    final total = widget.docs.length;
    _currentIndex = total == 0 ? 0 : widget.initialIndex.clamp(0, total - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.docs.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          total == 0 ? '' : '${_currentIndex + 1} / $total',
          style: const TextStyle(fontSize: 15),
        ),
      ),
      body: total == 0
          ? const Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.white54),
            )
          : PageView.builder(
              controller: _pageController,
              itemCount: total,
              physics: _currentPageZoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              onPageChanged: (i) {
                setState(() {
                  _currentIndex = i;
                  _currentPageZoomed = false;
                });
              },
              itemBuilder: (context, index) {
                final doc = widget.docs[index];
                return _FullImageViewerItem(
                  key: ValueKey(
                    'full:${doc.storageChapterId}|${doc.fileServer}|${doc.path}',
                  ),
                  doc: doc,
                  comicId: widget.comicId,
                  from: widget.from,
                  onZoomChanged: (zoomed) {
                    if (!mounted || index != _currentIndex) return;
                    if (_currentPageZoomed == zoomed) return;
                    setState(() => _currentPageZoomed = zoomed);
                  },
                );
              },
            ),
    );
  }
}

class _FullImageViewerItem extends StatelessWidget {
  const _FullImageViewerItem({
    super.key,
    required this.doc,
    required this.comicId,
    required this.from,
    required this.onZoomChanged,
  });

  final Doc doc;
  final String comicId;
  final String from;
  final ValueChanged<bool> onZoomChanged;

  @override
  Widget build(BuildContext context) {
    final resolvedChapterId = doc.storageChapterId.trim().isNotEmpty
        ? doc.storageChapterId
        : comicId;

    final pictureInfo = PictureInfo(
      from: from,
      url: doc.fileServer,
      path: doc.path,
      cartoonId: comicId,
      chapterId: resolvedChapterId,
      pictureType: PictureType.page,
      extern: doc.extern,
    );

    return BlocProvider(
      create: (_) => PictureBloc()..add(GetPicture(pictureInfo)),
      child: BlocBuilder<PictureBloc, PictureLoadState>(
        builder: (context, state) {
          switch (state.status) {
            case PictureLoadStatus.initial:
              return const Center(
                child: CircularProgressIndicator(color: Colors.white54),
              );
            case PictureLoadStatus.failure:
              return const Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.white54),
              );
            case PictureLoadStatus.success:
              final imagePath = state.imagePath;
              if (imagePath == null || imagePath.isEmpty) {
                return const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                  ),
                );
              }
              return _ZoomableImage(
                imagePath: imagePath,
                onZoomChanged: onZoomChanged,
              );
          }
        },
      ),
    );
  }
}

/// 可缩放单张图片。
///
/// 双击：以双击点为锚放大到 2.5 倍；再次双击还原。
/// 缩放 > 1 时启用拖动并上报父级；缩放为 1 时让 PageView 接管滑动。
class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.imagePath, required this.onZoomChanged});

  final String imagePath;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  static const double _doubleTapScale = 2.5;
  static const double _resetThreshold = 1.01;

  final TransformationController _controller = TransformationController();
  TapDownDetails? _doubleTapDetails;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTransformChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _controller.value.getMaxScaleOnAxis();
    final zoomed = scale > _resetThreshold;
    if (zoomed == _isZoomed) return;
    setState(() => _isZoomed = zoomed);
    widget.onZoomChanged(zoomed);
  }

  void _handleDoubleTap() {
    if (_isZoomed) {
      _controller.value = Matrix4.identity();
      return;
    }

    final details = _doubleTapDetails;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (details == null || renderBox == null || !renderBox.hasSize) return;

    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final matrix = Matrix4.identity()
      ..translateByDouble(
        renderBox.size.width / 2 - localPosition.dx * _doubleTapScale,
        renderBox.size.height / 2 - localPosition.dy * _doubleTapScale,
        0,
        1,
      )
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);

    _controller.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1.0,
        maxScale: 5.0,
        panEnabled: _isZoomed,
        scaleEnabled: true,
        child: Center(
          child: Image.file(
            File(widget.imagePath),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.white54),
            ),
          ),
        ),
      ),
    );
  }
}
