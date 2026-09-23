/// GitHub 远端 issue 的精简只读模型。
class RemoteIssue {
  final int number;
  final String title;
  final String body;
  final String state; // 'open' / 'closed'
  final String htmlUrl;
  final List<String> labels;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RemoteIssue({
    required this.number,
    required this.title,
    required this.body,
    required this.state,
    required this.htmlUrl,
    required this.labels,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOpen => state == 'open';
  bool get isClosed => state == 'closed';

  factory RemoteIssue.fromJson(Map<String, dynamic> json) {
    return RemoteIssue(
      number: json['number'] as int,
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      state: (json['state'] as String?) ?? 'open',
      htmlUrl: (json['html_url'] as String?) ?? '',
      labels: ((json['labels'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList(),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
