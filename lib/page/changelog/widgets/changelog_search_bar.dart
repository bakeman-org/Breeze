// lib/page/changelog/widgets/changelog_search_bar.dart
import 'package:material_ui/material_ui.dart';

/// 公告 Tab 的搜索栏。
///
/// 特点：
///   - 内部管理 [TextEditingController]，输入即时响应；
///   - `suffixIcon` 的显示/隐藏与文本同步，清除按钮永远正确出现；
///   - 通过 [onChanged] 把最新文本交给父级做过滤。
class ChangelogSearchBar extends StatefulWidget {
  const ChangelogSearchBar({
    super.key,
    required this.onChanged,
    this.hintText = '搜索公告…',
  });

  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  State<ChangelogSearchBar> createState() => _ChangelogSearchBarState();
}

class _ChangelogSearchBarState extends State<ChangelogSearchBar> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _clear() {
    _ctrl.clear();
    setState(() {});
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _ctrl,
        onChanged: (v) {
          // 先刷新本地状态（更新 suffixIcon），再上报父级。
          setState(() {});
          widget.onChanged(v);
        },
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _ctrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: _clear,
                  tooltip: '清除',
                ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }
}
