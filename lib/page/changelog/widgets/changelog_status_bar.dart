// lib/page/changelog/widgets/changelog_status_bar.dart
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/service/update/ntfy/ntfy_service.dart';
import 'package:zephyr/util/context/context_extensions.dart';

class ChangelogStatusBar extends StatelessWidget {
  const ChangelogStatusBar({
    super.key,
    required this.status,
    required this.totalCount,
    required this.visibleCount,
    required this.onReconnect,
    required this.onClearAll,
  });

  final NtfyStatus status;
  final int totalCount;
  final int visibleCount;
  final Future<void> Function() onReconnect;
  final Future<void> Function()? onClearAll;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      NtfyStatus.connected => ('已连接', Colors.green, Icons.cloud_done_outlined),
      NtfyStatus.connecting => (
        '连接中',
        Colors.orange,
        Icons.cloud_sync_outlined,
      ),
      NtfyStatus.reconnecting => (
        '重连中',
        Colors.orange,
        Icons.cloud_sync_outlined,
      ),
      NtfyStatus.disconnected => ('未启用', Colors.grey, Icons.cloud_off_outlined),
      NtfyStatus.error => ('连接出错', Colors.red, Icons.error_outline),
    };

    final showCount = totalCount == visibleCount
        ? '共 $totalCount 条'
        : '$visibleCount / $totalCount 条';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 12, color: color)),
            ),
            Text(
              showCount,
              style: TextStyle(
                fontSize: 12,
                color: context.textColor.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh, size: 16),
              visualDensity: VisualDensity.compact,
              tooltip: '重新连接',
              onPressed: () => onReconnect(),
            ),
            if (onClearAll != null)
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                visualDensity: VisualDensity.compact,
                tooltip: '清空全部',
                onPressed: () => onClearAll!(),
              ),
          ],
        ),
      ),
    );
  }
}
