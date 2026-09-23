import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GitHub 远端配置（owner / repo / token），持久化到 SharedPreferences。
///
/// **本地 issue 功能不依赖本类** —— 未配置 GitHub 时本地部分照常工作，
/// 只是不会出现远端分组、也无法 push / close 远端 issue。
class GitHubSettings extends ChangeNotifier {
  GitHubSettings._();

  /// 全局单例。
  static final GitHubSettings I = GitHubSettings._();

  static const _kOwner = 'github_owner';
  static const _kRepo = 'github_repo';
  static const _kToken = 'github_token';

  /// 编译期 fallback：`--dart-define=GITHUB_OWNER=...` 之类可以覆盖。
  static const _defaultOwner = String.fromEnvironment(
    'GITHUB_OWNER',
    defaultValue: 'bakeman-org',
  );
  static const _defaultRepo = String.fromEnvironment(
    'GITHUB_REPO',
    defaultValue: 'Breeze',
  );
  static const _defaultToken = String.fromEnvironment('GITHUB_TOKEN');

  String _owner = _defaultOwner;
  String _repo = _defaultRepo;
  String _token = _defaultToken;

  String get owner => _owner;
  String get repo => _repo;
  String get token => _token;

  bool get isConfigured =>
      _owner.isNotEmpty && _repo.isNotEmpty && _token.isNotEmpty;

  String get slug => '$_owner/$_repo';

  /// 从磁盘加载一次。通常只需在 app 启动早期调用一次。
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _owner = prefs.getString(_kOwner) ?? _defaultOwner;
    _repo = prefs.getString(_kRepo) ?? _defaultRepo;
    _token = prefs.getString(_kToken) ?? _defaultToken;
    notifyListeners();
  }

  Future<void> save({
    required String owner,
    required String repo,
    required String token,
  }) async {
    _owner = owner.trim();
    _repo = repo.trim();
    _token = token.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kOwner, _owner);
    await prefs.setString(_kRepo, _repo);
    await prefs.setString(_kToken, _token);
    notifyListeners();
  }

  Future<void> clear() async {
    _owner = _defaultOwner;
    _repo = _defaultRepo;
    _token = _defaultToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kOwner);
    await prefs.remove(_kRepo);
    await prefs.remove(_kToken);
    notifyListeners();
  }
}
