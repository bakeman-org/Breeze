import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/changelog/local_issue/remote_issue.dart';

/// 一个可折叠的「远端 issue」分组。
///
/// 只负责展示；打开外部链接的回调由父级提供。
class RemoteIssuesSection extends StatelessWidget {
  final List<RemoteIssue> issues;
  final bool expanded;
  final VoidCallback onToggle;
  final Future<void> Function(RemoteIssue) onOpen;
  final Future<void> Function()? onRefresh;
  final bool loading;
  final String? error;

  const RemoteIssuesSection({
    super.key,
    required this.issues,
    required this.expanded,
    required this.onToggle,
    required this.onOpen,
    this.onRefresh,
    this.loading = false,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.cloud_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'GitHub (${issues.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                if (loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (onRefresh != null)
                  IconButton(
                    tooltip: '刷新远端',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: () => onRefresh!(),
                  ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            )
          else if (issues.isEmpty && !loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                '暂无远端 issue',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final issue in issues)
            _RemoteIssueTile(issue: issue, onTap: () => onOpen(issue)),
        ],
      ],
    );
  }
}

class _RemoteIssueTile extends StatelessWidget {
  final RemoteIssue issue;
  final VoidCallback onTap;

  const _RemoteIssueTile({required this.issue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          issue.isClosed ? Icons.check_circle : Icons.cloud_queue_outlined,
          color: issue.isClosed ? Colors.green : scheme.primary,
          size: 28,
        ),
        title: Text(
          issue.title,
          style: theme.textTheme.titleMedium?.copyWith(
            decoration: issue.isClosed ? TextDecoration.lineThrough : null,
            color: issue.isClosed ? theme.disabledColor : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primary.withAlpha(28),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#${issue.number}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              for (final label in issue.labels.take(3))
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: scheme.tertiary),
                ),
              Text(
                _shortDate(issue.updatedAt),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        trailing: Icon(Icons.open_in_new, size: 18, color: theme.hintColor),
      ),
    );
  }

  String _shortDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return DateFormat('yyyy-MM-dd').format(d);
  }
}
