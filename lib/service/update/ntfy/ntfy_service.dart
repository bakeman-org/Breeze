// lib/service/update/ntfy/ntfy_service.dart
//
// ntfy 订阅服务（单文件版）。
//
// 用途：管理员（你）通过 `curl -d "消息" ntfy.sh/<topic>` 推一条消息，
// 所有订阅该 topic 的 Breeze 用户都能立刻收到通知。
//
// 实现：ntfy 的 streaming JSON API —— 对 `https://<server>/<topic>/json`
// 发起长连接 HTTP GET，服务器持续把事件按行 JSON 推回来，客户端一直读。
//
// 稳定性设计：
//   - 看门狗：90 秒无数据强制重连（ntfy 每 ~45 秒一次 keepalive）
//   - 状态去抖：reconnecting 这类中间态延迟发出，避免 UI 闪屏
//   - 稳定连接 >30 秒才重置指数退避，避免「秒断秒连」死循环
//
// 限制：
//   - 只在 App 前台时可靠收消息；App 被杀后需要重新进 App 才会重连。
//     要后台常驻，需要配合 Android 前台服务（本文件暂未做）。
//   - 不做本地持久化；消息只在内存里保留最近 100 条。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:zephyr/main.dart';

// ─────────────────────────────────────────────────────────────────────
// 消息模型
// ─────────────────────────────────────────────────────────────────────

/// 单条 ntfy 消息。
class NtfyMessage {
  const NtfyMessage({
    required this.id,
    required this.time,
    required this.event,
    required this.topic,
    required this.message,
    this.title,
    this.priority,
    this.tags = const <String>[],
    this.click,
  });

  final String id;
  final int time;
  final String event;
  final String topic;
  final String message;
  final String? title;
  final int? priority;
  final List<String> tags;
  final String? click;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(time * 1000);

  factory NtfyMessage.fromJson(Map<String, dynamic> json) {
    return NtfyMessage(
      id: json['id']?.toString() ?? '',
      time: _toInt(json['time'], 0),
      event: json['event']?.toString() ?? 'message',
      topic: json['topic']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      title: json['title']?.toString(),
      priority: json['priority'] is num
          ? (json['priority'] as num).toInt()
          : null,
      tags:
          (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      click: json['click']?.toString(),
    );
  }

  static NtfyMessage? tryParse(String line) {
    final text = line.trim();
    if (text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      return NtfyMessage.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}

int _toInt(dynamic value, int fallback) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

// ─────────────────────────────────────────────────────────────────────
// 连接状态
// ─────────────────────────────────────────────────────────────────────

enum NtfyStatus { connecting, connected, reconnecting, disconnected, error }

// ─────────────────────────────────────────────────────────────────────
// 服务
// ─────────────────────────────────────────────────────────────────────

class NtfyService {
  NtfyService._();
  static final NtfyService I = NtfyService._();

  static const String defaultServer = 'https://ntfy.sh';

  /// ⚠️ 改成你自己的随机 topic（`openssl rand -hex 12`）。
  static const String defaultTopic = 'breeze-notify-dev';

  static const int recentLimit = 100;

  /// 看门狗超时：这么久没收到任何字节就重连。
  ///
  /// ntfy.sh 每 ~45 秒发一次 keepalive，90 秒足够安全。
  static const Duration _watchdogTimeout = Duration(seconds: 90);

  /// 连接维持超过这个时长，才认为「稳定」，重置退避。
  static const Duration _stabilityThreshold = Duration(seconds: 30);

  // ── 消息 / 状态流 ───────────────────────────────────────────────

  final _messages = StreamController<NtfyMessage>.broadcast();
  final _statusCtrl = StreamController<NtfyStatus>.broadcast();

  Stream<NtfyMessage> get messages => _messages.stream;
  Stream<NtfyStatus> get status => _statusCtrl.stream;

  // ── 最近消息缓存 ─────────────────────────────────────────────────

  final List<NtfyMessage> _recent = <NtfyMessage>[];

  List<NtfyMessage> get recentMessages => List.unmodifiable(_recent);

  void clearRecentMessages() {
    _recent.clear();
  }

  /// 按 id 删除一条消息。
  void removeMessageById(String id) {
    _recent.removeWhere((m) => m.id == id);
  }

  // ── 外部回调 ─────────────────────────────────────────────────────

  /// ntfy 收到消息时的回调（用于系统通知）。
  ///
  /// 在主流程里绑定它：
  /// ```dart
  /// NtfyService.I.onMessage = (msg) { showNotification(...); };
  /// ```
  void Function(NtfyMessage message)? onMessage;

  // ── 内部状态 ─────────────────────────────────────────────────────

  HttpClient? _client;
  StreamSubscription<String>? _lineSub;
  bool _running = false;
  bool _stopRequested = false;
  int _retryDelaySec = 1;

  String _server = defaultServer;
  String _topic = defaultTopic;

  String get server => _server;
  String get topic => _topic;
  bool get isRunning => _running;

  // ── 状态去抖 ────────────────────────────────────────────────────

  NtfyStatus _lastEmittedStatus = NtfyStatus.disconnected;
  NtfyStatus? _pendingStatus;
  Timer? _statusTimer;

  // ── 公共 API ─────────────────────────────────────────────────────

  /// 启动订阅。重复调用幂等。
  Future<void> start({String? server, String? topic}) async {
    if (_running) return;
    _running = true;
    _stopRequested = false;
    _server = (server?.trim().isNotEmpty ?? false)
        ? server!.trim()
        : defaultServer;
    _topic = (topic?.trim().isNotEmpty ?? false) ? topic!.trim() : defaultTopic;

    _emitStatus(NtfyStatus.connecting);
    unawaited(_loop());
  }

  /// 停止订阅并关闭当前连接。
  Future<void> stop() async {
    _stopRequested = true;
    _running = false;

    // 先抢下引用再置空，避免 _connectOnce 的 finally 再次访问。
    final sub = _lineSub;
    _lineSub = null;
    final client = _client;
    _client = null;

    try {
      await sub?.cancel();
    } catch (_) {}
    try {
      client?.close(force: true);
    } catch (_) {}

    _emitStatus(NtfyStatus.disconnected);
  }

  /// 切换主题（先停旧连接，再起新连接）。
  Future<void> switchTopic(String topic) async {
    await stop();
    await start(server: _server, topic: topic);
  }

  void dispose() {
    unawaited(stop());
    _statusTimer?.cancel();
    unawaited(_messages.close());
    unawaited(_statusCtrl.close());
  }

  // ── 内部：主循环 ─────────────────────────────────────────────────

  Future<void> _loop() async {
    while (!_stopRequested) {
      final attemptStart = DateTime.now();
      try {
        await _connectOnce();
      } catch (e, st) {
        logger.w('[Ntfy] connection error: $e', error: e, stackTrace: st);
        _emitStatus(NtfyStatus.error);
      }
      if (_stopRequested) break;

      // 连接维持够久 → 视为稳定，退避重置。
      final held = DateTime.now().difference(attemptStart);
      if (held >= _stabilityThreshold) {
        _retryDelaySec = 1;
      }

      _emitStatus(NtfyStatus.reconnecting);
      final delay = Duration(seconds: _retryDelaySec);
      _retryDelaySec = (_retryDelaySec * 2).clamp(1, 60);
      try {
        await Future.delayed(delay);
      } catch (_) {
        break;
      }
    }
  }

  /// 建立一次连接并读到流结束。
  Future<void> _connectOnce() async {
    // ★ 加 ?since=all：让服务器先重放缓存的历史消息（默认 12 小时），
    //   然后继续推新消息。
    //
    //   不加这个参数时，GET /<topic>/json 只会推「订阅之后」的新消息，
    //   重启 App 后看不到之前发的任何公告 —— 这就是「已连接但 0 条」的根因。
    //
    //   想只拉短窗口的话可以改成 ?since=1h / ?since=30m，
    //   all 覆盖 ntfy.sh 的默认保留期，最稳。
    final uri = Uri.parse('$_server/$_topic/json?since=all');
    logger.d('[Ntfy] connecting to $uri');

    // ★ connectionTimeout 放宽到 30 秒；idleTimeout 给一个很大的值
    //   （只影响池化空闲连接，不影响正在读取的流）。
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(hours: 1);
    _client = client;

    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/x-ndjson');
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('ntfy HTTP ${response.statusCode}');
      }

      _emitStatus(NtfyStatus.connected);

      // 看门狗：超时无数据就强制断开。
      Timer? watchdog;
      void kick() {
        watchdog?.cancel();
        watchdog = Timer(_watchdogTimeout, () {
          logger.w('[Ntfy] watchdog fired, forcing reconnect');
          try {
            client.close(force: true);
          } catch (_) {}
        });
      }

      kick();

      final lineStream = response
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      final sub = lineStream.listen(
        (line) {
          kick();
          _onLine(line);
        },
        onError: (Object e) {
          logger.w('[Ntfy] stream error: $e');
        },
        cancelOnError: true,
      );
      _lineSub = sub;

      try {
        await sub.asFuture<void>();
      } catch (_) {
        // 取消/断流都走这里，交给外层循环重连。
      } finally {
        watchdog?.cancel();
        if (identical(_lineSub, sub)) _lineSub = null;
      }
    } finally {
      if (identical(_client, client)) {
        try {
          client.close(force: true);
        } catch (_) {}
        _client = null;
      }
    }
  }

  // ── 内部：单行处理 ───────────────────────────────────────────────

  void _onLine(String line) {
    final msg = NtfyMessage.tryParse(line);
    if (msg == null) return;
    // `open` / `keepalive` / `poll_request` 是协议事件，不上报。
    if (msg.event != 'message') return;

    // ★ 按 id 去重：since=all 会重放缓存消息，同一条不能重复插入。
    if (msg.id.isNotEmpty && _recent.any((m) => m.id == msg.id)) {
      return;
    }

    _recent.insert(0, msg);
    if (_recent.length > recentLimit) {
      _recent.removeRange(recentLimit, _recent.length);
    }

    _messages.add(msg);
    onMessage?.call(msg);
  }

  // ── 内部：状态去抖 ───────────────────────────────────────────────
  void _emitStatus(NtfyStatus s) {
    if (_statusCtrl.isClosed) return;

    // 立即发出的状态：connected / disconnected
    // 其它中间态（connecting / reconnecting / error）延迟 400ms，
    // 若期间又变化则取消，避免 UI 闪烁。
    final immediate = s == NtfyStatus.connected || s == NtfyStatus.disconnected;

    _pendingStatus = s;
    _statusTimer?.cancel();

    _statusTimer = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 400),
      () {
        final next = _pendingStatus;
        _pendingStatus = null;
        if (next == null || _statusCtrl.isClosed) return;
        if (next == _lastEmittedStatus) return;
        _lastEmittedStatus = next;
        _statusCtrl.add(next);
      },
    );
  }
}
