// lib/page/changelog/widgets/announcements_tab.dart
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/changelog/widgets/announcement_card.dart';
import 'package:zephyr/page/changelog/widgets/changelog_status_bar.dart';
import 'package:zephyr/page/changelog/widgets/search_input.dart';
import 'package:zephyr/service/update/ntfy/ntfy_service.dart';
import 'package:zephyr/util/context/context_extensions.dart';
import 'package:zephyr/widgets/toast.dart';

class AnnouncementsTab extends StatefulWidget {
  const AnnouncementsTab({super.key});

  @override
  State<AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<AnnouncementsTab>
    with AutomaticKeepAliveClientMixin {
  final List<NtfyMessage> _allMessages = <NtfyMessage>[];

  StreamSubscription<NtfyMessage>? _messageSub;
  StreamSubscription<NtfyStatus>? _statusSub;

  NtfyStatus _status = NtfyStatus.disconnected;

  /// 当前搜索关键词（小写，已按空白拆分）。
  List<String> _tokens = const <String>[];

  /// 是否展示顶部「临时通知」提示条。
  bool _showNotice = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _allMessages
      ..clear()
      ..addAll(NtfyService.I.recentMessages);

    _status = NtfyService.I.isRunning
        ? NtfyStatus.connected
        : NtfyStatus.disconnected;

    _messageSub = NtfyService.I.messages.listen((msg) {
      if (!mounted) return;
      setState(() => _allMessages.insert(0, msg));
    });

    _statusSub = NtfyService.I.status.listen((status) {
      if (!mounted) return;
      setState(() => _status = status);
    });

    _loadNoticeState();
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────
  // 提示条状态
  // ─────────────────────────────────────────────────────────────────

  Future<void> _loadNoticeState() async {
    final dismissed = await _NtfyNoticePrefs.isDismissed();
    if (!mounted) return;
    setState(() => _showNotice = !dismissed);
  }

  Future<void> _dismissNotice() async {
    setState(() => _showNotice = false);
    await _NtfyNoticePrefs.dismiss();
  }

  // ─────────────────────────────────────────────────────────────────
  // 过滤 + 分组
  // ─────────────────────────────────────────────────────────────────

  /// 按搜索词过滤。
  ///
  /// 支持多词 AND：`"服务器 维护"` → 消息里同时含「服务器」和「维护」。
  ///
  /// 搜索范围包括：
  ///   - 正文
  ///   - 标题（含回退标题「Breeze 公告」，所以搜「公告」能命中）
  ///   - 标签
  ///   - 主题名（一般没用，但聊胜于无）
  List<NtfyMessage> get _filtered {
    if (_tokens.isEmpty) return _allMessages;
    return _allMessages.where((m) {
      final haystack = StringBuffer()
        ..write(m.message.toLowerCase())
        ..write(' ')
        ..write(announcementDisplayTitle(m).toLowerCase());
      for (final t in m.tags) {
        haystack
          ..write(' ')
          ..write(t.toLowerCase());
      }
      haystack
        ..write(' ')
        ..write(m.topic.toLowerCase());
      final text = haystack.toString();
      return _tokens.every(text.contains);
    }).toList();
  }

  /// 公告的显示标题：优先用 ntfy 消息自带的 title，为空时回退到「Breeze 公告」。
  String announcementDisplayTitle(NtfyMessage m) {
    final raw = m.title?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return 'Breeze 公告';
  }

  /// 把过滤后的消息按本地日期分组，输出展平的列表条目。
  List<_AnnEntry> _buildEntries(List<NtfyMessage> messages) {
    final entries = <_AnnEntry>[];
    DateTime? currentDay;
    final buffer = <NtfyMessage>[];

    void flush() {
      if (buffer.isEmpty || currentDay == null) return;
      entries.add(_AnnHeaderEntry(currentDay, buffer.length));
      for (final m in buffer) {
        entries.add(_AnnMessageEntry(m, _tokens));
      }
      buffer.clear();
    }

    for (final msg in messages) {
      final day = _dayKey(msg.createdAt);
      if (currentDay != day) {
        flush();
        currentDay = day;
      }
      buffer.add(msg);
    }
    flush();
    return entries;
  }

  // ─────────────────────────────────────────────────────────────────
  // 交互
  // ─────────────────────────────────────────────────────────────────

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法打开链接: $urlString')));
      }
    }
  }

  Future<void> _reconnect() async {
    await NtfyService.I.stop();
    await NtfyService.I.start();
  }

  Future<void> _deleteMessage(NtfyMessage msg) async {
    setState(() => _allMessages.removeWhere((m) => m.id == msg.id));
    NtfyService.I.removeMessageById(msg.id);
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空全部公告'),
        content: const Text('清空后无法恢复。要清空内存中的全部公告吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(_allMessages.clear);
    NtfyService.I.clearRecentMessages();
    // ★ 清空后重新展示「临时通知」提示，提醒用户这套机制。
    await _NtfyNoticePrefs.reset();
    if (!mounted) return;
    setState(() => _showNotice = true);
  }

  Future<void> _copyMessage(NtfyMessage msg) async {
    final text = (msg.title?.isNotEmpty ?? false)
        ? '${msg.title}\n\n${msg.message}'
        : msg.message;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showSuccessToast('已复制到剪贴板');
  }

  void _onQueryChanged(String raw) {
    final tokens = raw
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    setState(() => _tokens = tokens);
  }

  // ─────────────────────────────────────────────────────────────────
  // 构建
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final filtered = _filtered;
    final entries = _buildEntries(filtered);

    return Column(
      children: [
        SearchInput(hintText: '搜索公告…', onChanged: _onQueryChanged),
        if (_showNotice) _NtfyNoticeBanner(onDismiss: _dismissNotice),
        ChangelogStatusBar(
          status: _status,
          totalCount: _allMessages.length,
          visibleCount: filtered.length,
          onReconnect: _reconnect,
          onClearAll: _allMessages.isEmpty ? null : _clearAll,
        ),
        Expanded(
          child: entries.isEmpty
              ? _EmptyState(
                  hasAny: _allMessages.isNotEmpty,
                  hasQuery: _tokens.isNotEmpty,
                  status: _status,
                  onRefresh: _reconnect,
                )
              : RefreshIndicator(
                  onRefresh: _reconnect,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      switch (entry) {
                        case _AnnHeaderEntry(:final date, :final count):
                          return Padding(
                            padding: EdgeInsets.only(
                              top: index == 0 ? 4 : 18,
                              bottom: 8,
                            ),
                            child: _DayHeader(date: date, count: count),
                          );
                        case _AnnMessageEntry(:final message, :final tokens):
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AnnouncementCard(
                              message: message,
                              onTap: message.click?.trim().isNotEmpty == true
                                  ? () => _launchUrl(message.click!)
                                  : null,
                              onDelete: () => _deleteMessage(message),
                              onCopy: () => _copyMessage(message),
                              onOpenLink:
                                  message.click?.trim().isNotEmpty == true
                                  ? () => _launchUrl(message.click!)
                                  : null,
                              highlightTokens: tokens,
                            ),
                          );
                      }
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 「临时通知」提示条
// ─────────────────────────────────────────────────────────────────────

/// 提示条的显隐状态持久化。
class _NtfyNoticePrefs {
  _NtfyNoticePrefs._();

  static const String _kDismissedKey = 'ntfy_notice_dismissed_v1';

  static Future<bool> isDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kDismissedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> dismiss() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDismissedKey, true);
    } catch (_) {}
  }

  static Future<void> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kDismissedKey);
    } catch (_) {}
  }
}

/// 公告 Tab 顶部「临时通知」提示条。
class _NtfyNoticeBanner extends StatelessWidget {
  const _NtfyNoticeBanner({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = const Color(0xFFFFF3E0); // 浅橙
    final fg = const Color(0xFF8D4E00); // 深橙
    final border = const Color(0xFFFFCC80);

    final panelBg = isDark ? fg.withValues(alpha: 0.18) : bg;
    final iconColor = isDark ? border : fg;
    final titleColor = isDark ? border : fg;
    final bodyColor = isDark
        ? border.withValues(alpha: 0.9)
        : fg.withValues(alpha: 0.85);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? border.withValues(alpha: 0.4) : border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '临时通知',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '这些公告来自 ntfy.sh，服务器仅保留 12 小时。'
                    '重要内容请以「更新日志」Tab 为准。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: bodyColor,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '不再提示',
              icon: Icon(Icons.close, size: 18, color: iconColor),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 列表条目 & 分组
// ─────────────────────────────────────────────────────────────────────

sealed class _AnnEntry {
  const _AnnEntry();
}

class _AnnHeaderEntry extends _AnnEntry {
  const _AnnHeaderEntry(this.date, this.count);
  final DateTime date;
  final int count;
}

class _AnnMessageEntry extends _AnnEntry {
  const _AnnMessageEntry(this.message, this.tokens);
  final NtfyMessage message;
  final List<String> tokens;
}

/// 把本地时间截断到「天」。
DateTime _dayKey(DateTime dt) {
  final local = dt.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// 日期标签：今天 / 昨天 / N 天前 / yyyy-MM-dd。
String _dayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(date).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '昨天';
  if (diff > 1 && diff < 7) return '$diff 天前';
  return DateFormat('yyyy-MM-dd').format(date);
}

/// 分组头。左边日期、右边条数，中间一条淡线。
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date, required this.count});

  final DateTime date;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          _dayLabel(date),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count 条',
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 空状态
// ─────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasAny,
    required this.hasQuery,
    required this.status,
    required this.onRefresh,
  });

  final bool hasAny;
  final bool hasQuery;
  final NtfyStatus status;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final String text;
    if (hasQuery) {
      text = '没有匹配的公告';
    } else {
      text = '暂无公告';
    }
    final statusText = _statusText(status);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasQuery
                        ? Icons.search_off_outlined
                        : Icons.notifications_none_outlined,
                    size: 56,
                    color: context.textColor.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    text,
                    style: TextStyle(
                      color: context.textColor.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: context.textColor.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusText(NtfyStatus status) {
    return switch (status) {
      NtfyStatus.connected => '已连接服务器，等待新公告\n（公告仅保留 12 小时）',
      NtfyStatus.connecting => '正在连接…',
      NtfyStatus.reconnecting => '连接断开，正在重连…',
      NtfyStatus.error => '连接出错，下拉重试',
      NtfyStatus.disconnected => '通知未启用',
    };
  }
}
