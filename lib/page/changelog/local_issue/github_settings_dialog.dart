import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/changelog/local_issue/github_settings.dart';
import 'package:zephyr/widgets/toast.dart';

/// 打开「GitHub 远端设置」对话框。返回时表示用户已关闭对话框。
Future<void> showGitHubSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _GitHubSettingsDialog(),
  );
}

class _GitHubSettingsDialog extends StatefulWidget {
  const _GitHubSettingsDialog();

  @override
  State<_GitHubSettingsDialog> createState() => _GitHubSettingsDialogState();
}

class _GitHubSettingsDialogState extends State<_GitHubSettingsDialog> {
  late final TextEditingController _ownerCtrl;
  late final TextEditingController _repoCtrl;
  late final TextEditingController _tokenCtrl;

  bool _obscure = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = GitHubSettings.I;
    _ownerCtrl = TextEditingController(text: s.owner);
    _repoCtrl = TextEditingController(text: s.repo);
    _tokenCtrl = TextEditingController(text: s.token);
  }

  @override
  void dispose() {
    _ownerCtrl.dispose();
    _repoCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_ownerCtrl.text.trim().isEmpty ||
        _repoCtrl.text.trim().isEmpty ||
        _tokenCtrl.text.trim().isEmpty) {
      showInfoToast('owner / repo / token 都不能为空');
      return;
    }
    setState(() => _saving = true);
    await GitHubSettings.I.save(
      owner: _ownerCtrl.text,
      repo: _repoCtrl.text,
      token: _tokenCtrl.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    showInfoToast('GitHub 设置已保存');
    Navigator.pop(context);
  }

  Future<void> _clear() async {
    await GitHubSettings.I.clear();
    if (!mounted) return;
    showInfoToast('GitHub 设置已清空');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configured = GitHubSettings.I.isConfigured;
    return AlertDialog(
      title: const Text('GitHub 远端'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '把本地 issue 推送到 GitHub。未配置时本地 issue 依然正常工作。',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ownerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Owner',
                  hintText: 'bakeman-org',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _repoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Repository',
                  hintText: 'Breeze',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tokenCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Personal Access Token',
                  hintText: 'ghp_…',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Token 需要 repo 或 issues:write 权限；建议使用 fine-grained PAT '
                '并限定到单个仓库。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (configured) TextButton(onPressed: _clear, child: const Text('清空')),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}
