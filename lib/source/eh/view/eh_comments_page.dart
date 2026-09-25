import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/source/eh/api/eh_client.dart';
import 'package:zephyr/source/eh/models/eh_models.dart';
import 'package:zephyr/source/eh/view/widgets/eh_gallery_list_item.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class EhCommentsPage extends StatefulWidget {
  const EhCommentsPage({super.key, required this.gid, required this.token});

  final String gid;
  final String token;

  @override
  State<EhCommentsPage> createState() => _EhCommentsPageState();
}

class _EhCommentsPageState extends State<EhCommentsPage> {
  bool _loading = true;
  bool _loginRequired = false;
  Object? _error;
  List<EhGalleryComment> _comments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loginRequired = false;
      _error = null;
    });
    try {
      final detail = await fetchEhGalleryDetail(widget.gid, widget.token);
      if (!mounted) return;
      setState(() {
        _comments = detail.comments;
        _loading = false;
      });
    } on EhLoginRequiredException {
      if (!mounted) return;
      setState(() {
        _loginRequired = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final detail = await fetchEhGalleryDetail(widget.gid, widget.token);
      if (!mounted) return;
      setState(() {
        _comments = detail.comments;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      showErrorToast(e.toString());
    }
  }

  String _scoreLabel(int score) {
    return score > 0 ? '+$score' : '$score';
  }

  @override
  Widget build(BuildContext context) {
    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: t.eh.comments,
        navigationIcon: MiuixIconButton(
          onPressed: () => context.maybePop(),
          child: const Icon(Icons.arrow_back),
        ),
      ),
      content: (padding) => Material(
        type: MaterialType.transparency,
        child: Padding(padding: padding, child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loginRequired) {
      return Center(
        child: Text(
          t.eh.loginRequired,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(t.eh.networkError, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            MiuixButton(onPressed: _load, child: Text(t.eh.retry)),
          ],
        ),
      );
    }
    if (_comments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [EhListEmptyView()],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        itemCount: _comments.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) =>
            _CommentItem(comment: _comments[index], scoreLabel: _scoreLabel),
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  const _CommentItem({required this.comment, required this.scoreLabel});

  final EhGalleryComment comment;
  final String Function(int) scoreLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  comment.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (comment.score != 0) ...[
                Icon(
                  comment.score > 0
                      ? Icons.thumb_up
                      : Icons.thumb_down,
                  size: 14,
                  color: comment.score > 0
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 4),
                Text(
                  scoreLabel(comment.score),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: comment.score > 0
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
          Text(
            comment.postedAt,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(comment.content, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
