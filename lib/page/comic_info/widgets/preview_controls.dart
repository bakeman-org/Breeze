import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_info/models/preview_prefs.dart';
import 'package:zephyr/util/context/context_extensions.dart';

/// 预览区块右上角的控制条：范围选择 + 刷新。
class PreviewControls extends StatelessWidget {
  const PreviewControls({
    super.key,
    required this.mode,
    required this.count,
    required this.start,
    required this.end,
    required this.totalPages,
    required this.onSelectionChanged,
    required this.onRefresh,
  });

  final PreviewMode mode;
  final int count;
  final int start;
  final int end;
  final int totalPages;

  /// (mode, count, start, end)
  final void Function(PreviewMode mode, int count, int start, int end)
  onSelectionChanged;
  final VoidCallback onRefresh;

  String get _label {
    switch (mode) {
      case PreviewMode.top:
        return '前 $count 张';
      case PreviewMode.tail:
        return '后 $count 张';
      case PreviewMode.range:
        return '$start-$end';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 范围选择胶囊。
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () async {
            final result = await showDialog<PreviewSelection>(
              context: context,
              builder: (_) => PreviewPickerDialog(
                initialMode: mode,
                initialCount: count,
                initialStart: start,
                initialEnd: end,
                maxPages: totalPages,
              ),
            );
            if (result != null) {
              onSelectionChanged(
                result.mode,
                result.count,
                result.start,
                result.end,
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tune, size: 14),
                const SizedBox(width: 4),
                Text(
                  _label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: '刷新预览',
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: onRefresh,
        ),
      ],
    );
  }
}

/// 预览参数对话框的返回值。
class PreviewSelection {
  const PreviewSelection({
    required this.mode,
    required this.count,
    required this.start,
    required this.end,
  });

  final PreviewMode mode;
  final int count;
  final int start;
  final int end;
}

/// 预览参数选择对话框。
class PreviewPickerDialog extends StatefulWidget {
  const PreviewPickerDialog({
    super.key,
    required this.initialMode,
    required this.initialCount,
    required this.initialStart,
    required this.initialEnd,
    required this.maxPages,
  });

  final PreviewMode initialMode;
  final int initialCount;
  final int initialStart;
  final int initialEnd;

  /// 0 表示总页数未知，跳过上界校验。
  final int maxPages;

  @override
  State<PreviewPickerDialog> createState() => _PreviewPickerDialogState();
}

class _PreviewPickerDialogState extends State<PreviewPickerDialog> {
  late PreviewMode _mode;
  late final TextEditingController _countController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _countController = TextEditingController(
      text: widget.initialCount.toString(),
    );
    _startController = TextEditingController(
      text: widget.initialStart.toString(),
    );
    _endController = TextEditingController(text: widget.initialEnd.toString());
  }

  @override
  void dispose() {
    _countController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _applyCountPreset(int n) {
    setState(() {
      _countController.text = n.toString();
      _error = null;
    });
  }

  void _applyRangePreset(int start, int end) {
    setState(() {
      _startController.text = start.toString();
      _endController.text = end.toString();
      _error = null;
    });
  }

  void _submit() {
    final maxPages = widget.maxPages;

    if (_mode == PreviewMode.top || _mode == PreviewMode.tail) {
      final n = int.tryParse(_countController.text.trim());
      if (n == null) {
        setState(() => _error = '请输入有效数字');
        return;
      }
      if (n < 1) {
        setState(() => _error = '数量不能小于 1');
        return;
      }
      if (maxPages > 0 && n > maxPages) {
        Navigator.of(context).pop(
          PreviewSelection(
            mode: _mode,
            count: maxPages,
            start: widget.initialStart,
            end: widget.initialEnd,
          ),
        );
        return;
      }
      Navigator.of(context).pop(
        PreviewSelection(
          mode: _mode,
          count: n,
          start: widget.initialStart,
          end: widget.initialEnd,
        ),
      );
      return;
    }

    // range 模式。
    final start = int.tryParse(_startController.text.trim());
    final end = int.tryParse(_endController.text.trim());
    if (start == null || end == null) {
      setState(() => _error = '请输入有效数字');
      return;
    }
    if (start < 1) {
      setState(() => _error = '起始页不能小于 1');
      return;
    }
    if (end < start) {
      setState(() => _error = '结束页不能小于起始页');
      return;
    }
    if (maxPages > 0 && start > maxPages) {
      setState(() => _error = '起始页不能超过总页数 $maxPages');
      return;
    }
    Navigator.of(context).pop(
      PreviewSelection(
        mode: _mode,
        count: widget.initialCount,
        start: start,
        end: end,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('预览范围'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.maxPages > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '本章共 ${widget.maxPages} 页',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            SegmentedButton<PreviewMode>(
              segments: const [
                ButtonSegment(
                  value: PreviewMode.top,
                  label: Text('前 N 张'),
                  icon: Icon(Icons.vertical_align_top, size: 16),
                ),
                ButtonSegment(
                  value: PreviewMode.tail,
                  label: Text('后 N 张'),
                  icon: Icon(Icons.vertical_align_bottom, size: 16),
                ),
                ButtonSegment(
                  value: PreviewMode.range,
                  label: Text('范围'),
                  icon: Icon(Icons.tune, size: 16),
                ),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) {
                setState(() {
                  _mode = s.first;
                  _error = null;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_mode == PreviewMode.top || _mode == PreviewMode.tail) ...[
              TextField(
                controller: _countController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _mode == PreviewMode.top ? '前 N 张' : '后 N 张',
                  isDense: true,
                  suffixText: '张',
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _countChip(20),
                  _countChip(50),
                  _countChip(100),
                  if (widget.maxPages > 0)
                    ActionChip(
                      label: Text('全部 (${widget.maxPages})'),
                      onPressed: () => _applyCountPreset(widget.maxPages),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    )
                  else
                    _countChip(200),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _startController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '从（页）',
                        isDense: true,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('—'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _endController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '到（页）',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _rangeChip('1-20', 1, 20),
                  _rangeChip('1-50', 1, 50),
                  _rangeChip('1-100', 1, 100),
                  if (widget.maxPages > 0)
                    _rangeChip('全部 (1-${widget.maxPages})', 1, widget.maxPages),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: colorScheme.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(t.common.ok)),
      ],
    );
  }

  Widget _countChip(int n) {
    return ActionChip(
      label: Text('$n'),
      onPressed: () => _applyCountPreset(n),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _rangeChip(String label, int start, int end) {
    return ActionChip(
      label: Text(label),
      onPressed: () => _applyRangePreset(start, end),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
