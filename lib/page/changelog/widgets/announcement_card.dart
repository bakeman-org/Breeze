// lib/page/changelog/widgets/announcement_card.dart
import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/service/update/ntfy/ntfy_service.dart';

class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({
    super.key,
    required this.message,
    this.onTap,
    required this.onDelete,
    required this.onCopy,
    this.onOpenLink,
    this.highlightTokens = const <String>[],
  });

  final NtfyMessage message;
  final VoidCallback? onTap;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  final VoidCallback? onOpenLink;

  /// 搜索关键词（小写），用于高亮匹配片段。
  final List<String> highlightTokens;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final title = message.title?.trim();
    final hasTitle = title != null && title.isNotEmpty;
    final highlightColor = colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shadowColor: Colors.transparent,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: hasTitle
                        ? Text.rich(
                            TextSpan(
                              children: _highlight(
                                text: title,
                                tokens: highlightTokens,
                                base: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                                highlight: highlightColor,
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              Icon(
                                _iconForPriority(message.priority),
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Breeze 公告',
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: '更多',
                    icon: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onSelected: (v) {
                      switch (v) {
                        case 'copy':
                          onCopy();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                        case 'open':
                          onOpenLink?.call();
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'copy', child: Text('复制')),
                      if (onOpenLink != null)
                        const PopupMenuItem(value: 'open', child: Text('打开链接')),
                      const PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  children: _highlight(
                    text: message.message,
                    tokens: highlightTokens,
                    base: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      height: 1.5,
                    ),
                    highlight: highlightColor,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (message.tags.isNotEmpty) ...[
                    for (final tag in message.tags.take(3)) ...[
                      _SmallTag(text: tag),
                      const SizedBox(width: 6),
                    ],
                  ],
                  const Spacer(),
                  Text(
                    _formatTime(message.createdAt),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (message.click != null &&
                      message.click!.trim().isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForPriority(int? priority) {
    if (priority == null) return Icons.campaign_outlined;
    if (priority >= 4) return Icons.priority_high_rounded;
    return Icons.campaign_outlined;
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return DateFormat('yyyy-MM-dd').format(local);
  }
}

/// 把 [text] 里匹配 [tokens] 的片段拆成 `TextSpan`，匹配部分加底色+加粗。
///
/// - `tokens` 为空时直接返回单段（无高亮）。
/// - 支持多词 AND，不同词的匹配区间会自动合并，避免重叠染色。
List<TextSpan> _highlight({
  required String text,
  required List<String> tokens,
  TextStyle? base,
  required Color highlight,
}) {
  if (tokens.isEmpty || text.isEmpty) {
    return [TextSpan(text: text, style: base)];
  }

  final lower = text.toLowerCase();
  final intervals = <(int, int)>[];

  for (final token in tokens) {
    if (token.isEmpty) continue;
    var start = 0;
    while (true) {
      final idx = lower.indexOf(token, start);
      if (idx < 0) break;
      intervals.add((idx, idx + token.length));
      start = idx + token.length;
    }
  }

  if (intervals.isEmpty) {
    return [TextSpan(text: text, style: base)];
  }

  // 合并重叠区间
  intervals.sort((a, b) => a.$1.compareTo(b.$1));
  final merged = <(int, int)>[];
  for (final iv in intervals) {
    if (merged.isEmpty || iv.$1 > merged.last.$2) {
      merged.add(iv);
    } else {
      merged[merged.length - 1] = (
        merged.last.$1,
        math.max(merged.last.$2, iv.$2),
      );
    }
  }

  final spans = <TextSpan>[];
  var cursor = 0;
  for (final iv in merged) {
    if (cursor < iv.$1) {
      spans.add(TextSpan(text: text.substring(cursor, iv.$1), style: base));
    }
    spans.add(
      TextSpan(
        text: text.substring(iv.$1, iv.$2),
        style: base?.copyWith(
          backgroundColor: highlight.withValues(alpha: 0.22),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    cursor = iv.$2;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor), style: base));
  }
  return spans;
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
