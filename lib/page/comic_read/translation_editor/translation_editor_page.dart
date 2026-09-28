// lib/page/comic_read/translation_editor/translation_editor_page.dart
// 翻译编辑器：加载原图 + blocks JSON，点气泡改译文，保存后重渲染 PNG。

import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/service/translation/translation_image_renderer.dart';
import 'package:zephyr/service/translation/translation_service.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class TranslationEditorPage extends StatefulWidget {
  const TranslationEditorPage({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<TranslationEditorPage> createState() => _TranslationEditorPageState();
}

class _TranslationEditorPageState extends State<TranslationEditorPage> {
  List<TranslatedBlock>? _blocks;
  double? _aspectRatio;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final blocks = await TranslationImageRenderer.loadBlocks(widget.imagePath);
    final ratio = await _resolveAspectRatio(widget.imagePath);
    if (!mounted) return;
    setState(() {
      _blocks = blocks;
      _aspectRatio = ratio;
      _loading = false;
    });
  }

  Future<double> _resolveAspectRatio(String path) async {
    final completer = Completer<double>();
    final imageProvider = ResizeImage(FileImage(File(path)), width: 128);
    final stream = imageProvider.resolve(ImageConfiguration.empty);
    ImageStreamListener? listener;
    listener = ImageStreamListener((info, _) {
      if (!completer.isCompleted) {
        completer.complete(
          info.image.width.toDouble() / info.image.height.toDouble(),
        );
      }
    });
    stream.addListener(listener);
    return completer.future
        .timeout(const Duration(seconds: 5), onTimeout: () => 0.75)
        .whenComplete(() {
          if (listener != null) stream.removeListener(listener);
        });
  }

  Future<void> _save() async {
    final blocks = _blocks;
    if (blocks == null) return;
    setState(() => _saving = true);
    try {
      await TranslationImageRenderer.render(
        imagePath: widget.imagePath,
        blocks: blocks,
      );
      await TranslationImageRenderer.saveBlocksJson(widget.imagePath, blocks);
      if (!mounted) return;
      showSuccessToast(t.translation.editorSavedToast);
      context.pop();
    } catch (e) {
      showErrorToast(t.translation.translationFailed(error: e.toString()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editBlock(int index) async {
    final blocks = _blocks;
    if (blocks == null || index >= blocks.length) return;
    var value = blocks[index].translated;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.translation.editDialogTitle),
        content: TextFormField(
          initialValue: value,
          autofocus: true,
          maxLines: 4,
          onChanged: (v) => value = v,
          decoration: InputDecoration(
            hintText: t.translation.editDialogHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            child: Text(t.common.cancel),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(t.common.ok),
            onPressed: () => Navigator.pop(context, value),
          ),
        ],
      ),
    );
    if (result == null) return;
    setState(() {
      final b = blocks[index];
      blocks[index] = TranslatedBlock(
        rect: b.rect,
        original: b.original,
        translated: result,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.translation.editorTitle),
        actions: [
          if (_blocks != null && !_saving)
            IconButton(
              icon: const Icon(Icons.save_outlined),
              onPressed: _save,
              tooltip: t.translation.editorSave,
            ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final blocks = _blocks;
    if (blocks == null || blocks.isEmpty) {
      return Center(child: Text(t.translation.editorNoBlocks));
    }
    final ratio = _aspectRatio ?? 0.75;
    return SingleChildScrollView(
      child: Center(
        child: AspectRatio(
          aspectRatio: ratio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(widget.imagePath),
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
              ..._buildBlockOverlays(blocks),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBlockOverlays(List<TranslatedBlock> blocks) {
    return [
      for (var i = 0; i < blocks.length; i++)
        Positioned.fromRect(
          rect: Rect.fromLTWH(
            blocks[i].rect.left,
            blocks[i].rect.top,
            blocks[i].rect.width,
            blocks[i].rect.height,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _editBlock(i),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                border: Border.all(color: Colors.white54, width: 0.5),
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  blocks[i].translated,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }
}
