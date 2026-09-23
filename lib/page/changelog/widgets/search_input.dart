// lib/page/changelog/widgets/search_input.dart
import 'package:material_ui/material_ui.dart';

/// 通用搜索输入框。
///
/// 两种用法：
///
/// **1. 完全托管**
/// ```dart
/// SearchInput(
///   hintText: '搜索公告…',
///   onChanged: (v) => setState(() => _query = v),
/// )
/// ```
///
/// **2. 外部托管（快捷键 requestFocus / 右侧挂动作按钮）**
/// ```dart
/// SearchInput(
///   controller: _searchCtrl,
///   focusNode: _searchFocus,
///   hintText: 'grep title / body / tags...  (Ctrl+F)',
///   onChanged: (v) => setState(() => _query = v),
///   trailing: [
///     IconButton(icon: Icon(_mode.icon), onPressed: _showGroupPicker),
///     IconButton(icon: Icon(Icons.refresh), onPressed: _reload),
///   ],
/// )
/// ```
class SearchInput extends StatefulWidget {
  const SearchInput({
    super.key,
    required this.onChanged,
    this.hintText = '搜索…',
    this.controller,
    this.focusNode,
    this.trailing = const [],
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 8),
    this.autofocus = false,
    this.clearTooltip = '清除',
  });

  final ValueChanged<String> onChanged;
  final String hintText;

  /// 外部 controller。传入时组件不再拥有其生命周期。
  final TextEditingController? controller;

  /// 外部 focusNode。传入时组件不再拥有其生命周期。
  final FocusNode? focusNode;

  /// 右侧附加动作（通常是一排 IconButton）。
  final List<Widget> trailing;

  /// 自定义内边距。issue Tab 传 `EdgeInsets.fromLTRB(16, 12, 16, 4)`。
  final EdgeInsetsGeometry padding;

  final bool autofocus;
  final String clearTooltip;

  @override
  State<SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<SearchInput> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  late final bool _ownsCtrl;
  late final bool _ownsFocus;

  @override
  void initState() {
    super.initState();
    _ownsCtrl = widget.controller == null;
    _ownsFocus = widget.focusNode == null;
    _ctrl = widget.controller ?? TextEditingController();
    _focus = widget.focusNode ?? FocusNode();
    _ctrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    if (_ownsCtrl) _ctrl.dispose();
    if (_ownsFocus) _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _clear() {
    _ctrl.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
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
                        tooltip: widget.clearTooltip,
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          if (widget.trailing.isNotEmpty) ...[
            const SizedBox(width: 8),
            ...widget.trailing,
          ],
        ],
      ),
    );
  }
}
