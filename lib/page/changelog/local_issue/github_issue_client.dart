import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:zephyr/page/changelog/local_issue/github_settings.dart';
import 'package:zephyr/page/changelog/local_issue/local_issue.dart';
import 'package:zephyr/page/changelog/local_issue/remote_issue.dart';

/// 通过 GitHub REST API 与远端仓库通信。
///
/// 无参构造时读取 [GitHubSettings.I]，因此调用方通常只需
/// `GitHubIssueClient()`。也可以显式传入 owner/repo/token 覆盖。
class GitHubIssueClient {
  final String owner;
  final String repo;
  final String token;
  final http.Client _client;

  GitHubIssueClient({
    String? owner,
    String? repo,
    String? token,
    http.Client? client,
  }) : owner = owner ?? GitHubSettings.I.owner,
       repo = repo ?? GitHubSettings.I.repo,
       token = token ?? GitHubSettings.I.token,
       _client = client ?? http.Client();

  bool get isConfigured =>
      owner.isNotEmpty && repo.isNotEmpty && token.isNotEmpty;

  static const _apiBase = 'https://api.github.com';

  Map<String, String> get _headers => {
    'Accept': 'application/vnd.github+json',
    'Authorization': 'Bearer $token',
    'X-GitHub-Api-Version': '2022-11-28',
    'Content-Type': 'application/json',
  };

  // ─────────────────────── POST issue ───────────────────────

  /// 以新 issue 的形式提交到 GitHub。返回更新后的 LocalIssue（含 number/url）。
  Future<LocalIssue> postIssue(LocalIssue issue) async {
    final labels = <String>[
      'local-issue',
      'priority:${_priorityBucket(issue.priority)}',
      ...issue.tags,
    ];

    final body = StringBuffer()
      ..writeln(issue.body.isEmpty ? '_No body._' : issue.body)
      ..writeln()
      ..writeln('---')
      ..writeln('_Mirrored from local tracker • id: `${issue.id}`_')
      ..writeln('_Created at: ${issue.createdAt.toIso8601String()}_');

    final resp = await _client.post(
      Uri.parse('$_apiBase/repos/$owner/$repo/issues'),
      headers: _headers,
      body: jsonEncode({
        'title': issue.title,
        'body': body.toString(),
        'labels': labels,
      }),
    );

    if (resp.statusCode != 201) {
      throw GitHubIssueException(_describeError('Create issue', resp));
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    issue.githubNumber = data['number'] as int?;
    issue.githubUrl = data['html_url'] as String?;
    return issue;
  }

  // ─────────────────────── 状态 ───────────────────────

  Future<void> closeIssue(int number) async {
    await _setState(number, 'closed');
  }

  Future<void> reopenIssue(int number) async {
    await _setState(number, 'open');
  }

  Future<void> _setState(int number, String state) async {
    final resp = await _client.patch(
      Uri.parse('$_apiBase/repos/$owner/$repo/issues/$number'),
      headers: _headers,
      body: jsonEncode({'state': state}),
    );
    if (resp.statusCode != 200) {
      throw GitHubIssueException(_describeError('Set state=$state', resp));
    }
  }

  // ─────────────────────── 拉取 ───────────────────────

  /// 拉取远端 issue 列表。默认拉所有状态（含 closed）。
  Future<List<RemoteIssue>> listIssues({
    String state = 'all',
    int perPage = 50,
    int page = 1,
  }) async {
    final uri = Uri.parse('$_apiBase/repos/$owner/$repo/issues').replace(
      queryParameters: {
        'state': state,
        'per_page': '$perPage',
        'page': '$page',
        'sort': 'updated',
        'direction': 'desc',
      },
    );
    final resp = await _client.get(uri, headers: _headers);
    if (resp.statusCode != 200) {
      throw GitHubIssueException(_describeError('List issues', resp));
    }
    final list = jsonDecode(resp.body) as List;
    return list
        .whereType<Map<String, dynamic>>()
        // issues API 把 PR 也算作 issue，这里过滤掉。
        .where((e) => e['pull_request'] == null)
        .map(RemoteIssue.fromJson)
        .toList();
  }

  // ─────────────────────── 工具 ───────────────────────

  String _priorityBucket(int p) {
    if (p < 10) return 'critical';
    if (p < 30) return 'high';
    if (p < 70) return 'medium';
    return 'low';
  }

  /// 把常见 HTTP 状态码翻译成人话，附加在错误信息里。
  String _describeError(String what, http.Response resp) {
    final hint = switch (resp.statusCode) {
      401 => '（token 无效或已过期）',
      403 => '（token 权限不足，需要 repo 或 issues:write）',
      404 => '（仓库不存在，或 token 无权访问）',
      410 => '（该仓库已禁用 Issues 功能，请到仓库 Settings → Features 启用）',
      422 => '（请求内容被拒绝，检查 labels 或字段）',
      _ => '',
    };
    debugPrint('$what failed (${resp.statusCode}): ${resp.body}');
    return '$what failed (${resp.statusCode})$hint: ${resp.body}';
  }
}

class GitHubIssueException implements Exception {
  final String message;
  GitHubIssueException(this.message);

  @override
  String toString() => 'GitHubIssueException: $message';
}
