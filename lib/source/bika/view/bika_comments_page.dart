import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/config/global/accent.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/source/bika/api/bika_api.dart';
import 'package:zephyr/source/bika/models/bika_models.dart';
import 'package:zephyr/source/bika/view/widgets/bika_avatar_image.dart';
import 'package:zephyr/source/bika/view/widgets/bika_comic_card.dart';
import 'package:zephyr/widgets/miuix_field_colors.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class BikaCommentsPage extends StatefulWidget {
  const BikaCommentsPage({super.key, required this.comicId});

  final String comicId;

  @override
  State<BikaCommentsPage> createState() => _BikaCommentsPageState();
}

class _BikaCommentsPageState extends State<BikaCommentsPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();

  bool _loading = true;
  Object? _error;
  List<Comment> _comments = [];
  int _page = 1;
  int _pages = 1;
  bool _loadingMore = false;
  bool _sending = false;

  final Set<String> _expanded = {};
  final Map<String, List<SubComment>> _subComments = {};
  final Set<String> _subLoading = {};
  final Set<String> _subFailed = {};
  final Map<String, bool> _likeOverrides = {};
  final Map<String, bool> _subLikeOverrides = {};
  String _replyTarget = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 400) _loadMore();
  }

  bool _isLiked(String uid, bool isLiked) => _likeOverrides[uid] ?? isLiked;

  int _likesCountOf(Comment comment) {
    final liked = _isLiked(comment.uid, comment.isLiked);
    final base = comment.isLiked ? comment.likesCount - 1 : comment.likesCount;
    return base + (liked ? 1 : 0);
  }

  bool _subIsLiked(String uid, bool isLiked) =>
      _subLikeOverrides[uid] ?? isLiked;

  int _subLikesCountOf(SubComment comment) {
    final liked = _subIsLiked(comment.uid, comment.isLiked);
    final base = comment.isLiked ? comment.likesCount - 1 : comment.likesCount;
    return base + (liked ? 1 : 0);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await fetchBikaComicComments(
        CommentsPayload(id: widget.comicId, page: 1),
      );
      if (!mounted) return;
      setState(() {
        _comments = List.from(resp.comments.docs);
        _pages = resp.comments.pages;
        _page = 1;
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
      final resp = await fetchBikaComicComments(
        CommentsPayload(id: widget.comicId, page: 1),
      );
      if (!mounted) return;
      setState(() {
        _comments = List.from(resp.comments.docs);
        _pages = resp.comments.pages;
        _page = 1;
        _error = null;
        _expanded.clear();
        _subComments.clear();
        _subFailed.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _error != null) return;
    if (_page >= _pages) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final resp = await fetchBikaComicComments(
        CommentsPayload(id: widget.comicId, page: next),
      );
      if (!mounted) return;
      setState(() {
        _page = next;
        _pages = resp.comments.pages;
        final existing = _comments.map((c) => c.uid).toSet();
        _comments.addAll(
          resp.comments.docs.where((c) => !existing.contains(c.uid)),
        );
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      showErrorToast(e.toString());
    }
  }

  Future<void> _toggleLike(Comment comment) async {
    try {
      await likeBikaComment(comment.uid);
      if (!mounted) return;
      setState(
        () => _likeOverrides[comment.uid] = !_isLiked(
          comment.uid,
          comment.isLiked,
        ),
      );
    } catch (e) {
      showErrorToast(e.toString());
    }
  }

  Future<void> _toggleSubLike(SubComment comment) async {
    try {
      await likeBikaComment(comment.uid);
      if (!mounted) return;
      setState(
        () => _subLikeOverrides[comment.uid] = !_subIsLiked(
          comment.uid,
          comment.isLiked,
        ),
      );
    } catch (e) {
      showErrorToast(e.toString());
    }
  }

  Future<void> _toggleExpanded(Comment comment) async {
    if (!_expanded.contains(comment.uid)) {
      setState(() => _expanded.add(comment.uid));
      _replyTarget = comment.uid;
      await _loadSubComments(comment.uid);
    } else {
      setState(() {
        _expanded.remove(comment.uid);
        if (_replyTarget == comment.uid) _replyTarget = '';
      });
    }
  }

  Future<void> _loadSubComments(String uid) async {
    setState(() {
      _subLoading.add(uid);
      _subFailed.remove(uid);
    });
    try {
      final resp = await fetchBikaSubComments(
        SubCommentsPayload(id: uid, page: 1),
      );
      if (!mounted) return;
      setState(() {
        _subComments[uid] = List.from(resp.comments.docs);
        _subLoading.remove(uid);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _subFailed.add(uid);
        _subLoading.remove(uid);
      });
      showErrorToast(e.toString());
    }
  }

  Future<void> _sendReply(String uid) async {
    final content = _replyController.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await sendBikaReply(SendCommentPayload(id: uid, content: content));
      _replyController.clear();
      await _loadSubComments(uid);
    } catch (e) {
      showErrorToast(e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendComment() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await sendBikaComment(
        SendCommentPayload(id: widget.comicId, content: content),
      );
      _inputController.clear();
      showSuccessToast(t.bika.commentSent);
      await _refresh();
    } catch (e) {
      showErrorToast(e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso)?.toLocal();
    if (date == null) return iso;
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: t.bika.comments,
        navigationIcon: MiuixIconButton(
          onPressed: () => context.maybePop(),
          child: const Icon(Icons.arrow_back),
        ),
      ),
      content: (padding) => Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: padding,
          child: Column(
            children: [
              Expanded(child: _buildBody(context)),
              _buildInputBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              t.bika.networkError,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            MiuixButton(onPressed: _load, child: Text(t.bika.retry)),
          ],
        ),
      );
    }
    if (_comments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [BikaListEmptyView()],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: Stack(
        children: [
          ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            itemCount: _comments.length,
            itemBuilder: (context, index) {
              final comment = _comments[index];
              return _CommentItem(
                key: ValueKey(comment.uid),
                comment: comment,
                isLiked: _isLiked(comment.uid, comment.isLiked),
                likesCount: _likesCountOf(comment),
                expanded: _expanded.contains(comment.uid),
                subComments: _subComments[comment.uid] ?? const [],
                subLoading: _subLoading.contains(comment.uid),
                subFailed: _subFailed.contains(comment.uid),
                subIsLiked: _subIsLiked,
                subLikesCount: _subLikesCountOf,
                replyActive: _replyTarget == comment.uid,
                replyController: _replyController,
                replySending: _sending,
                onToggleLike: () => _toggleLike(comment),
                onToggleSubLike: _toggleSubLike,
                onToggleExpand: () => _toggleExpanded(comment),
                onActivateReply: () =>
                    setState(() => _replyTarget = comment.uid),
                onRetrySub: () => _loadSubComments(comment.uid),
                onSendReply: () => _sendReply(comment.uid),
                formatDate: _formatDate,
              );
            },
          ),
          if (_loadingMore)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: MiuixTextField(
              controller: _inputController,
              singleLine: true,
              label: t.bika.commentHint,
              useLabelAsPlaceholder: true,
              colors: dimmedHintFieldColors(context),
            ),
          ),
          const SizedBox(width: 8),
          MiuixIconButton(
            onPressed: _sending ? null : _sendComment,
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  const _CommentItem({
    super.key,
    required this.comment,
    required this.isLiked,
    required this.likesCount,
    required this.expanded,
    required this.subComments,
    required this.subLoading,
    required this.subFailed,
    required this.subIsLiked,
    required this.subLikesCount,
    required this.replyActive,
    required this.replyController,
    required this.replySending,
    required this.onToggleLike,
    required this.onToggleSubLike,
    required this.onToggleExpand,
    required this.onActivateReply,
    required this.onRetrySub,
    required this.onSendReply,
    required this.formatDate,
  });

  final Comment comment;
  final bool isLiked;
  final int likesCount;
  final bool expanded;
  final List<SubComment> subComments;
  final bool subLoading;
  final bool subFailed;
  final bool Function(String, bool) subIsLiked;
  final int Function(SubComment) subLikesCount;
  final bool replyActive;
  final TextEditingController replyController;
  final bool replySending;
  final VoidCallback onToggleLike;
  final void Function(SubComment) onToggleSubLike;
  final VoidCallback onToggleExpand;
  final VoidCallback onActivateReply;
  final VoidCallback onRetrySub;
  final VoidCallback onSendReply;
  final String Function(String) formatDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = comment.user;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                BikaAvatarImage(
                  image: user.avatar,
                  name: user.name,
                  radius: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: theme.textTheme.titleSmall),
                      Text(
                        '${user.title} · Lv.${user.level}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatDate(comment.created_at),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(comment.content, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: onToggleLike,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                          size: 16,
                          color: isLiked
                              ? accentBlue
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$likesCount',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isLiked
                                ? accentBlue
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (comment.commentsCount > 0)
                  TextButton.icon(
                    onPressed: onToggleExpand,
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                    ),
                    label: Text(
                      '${t.bika.subComments} ${comment.commentsCount}',
                    ),
                  ),
              ],
            ),
            if (expanded) ...[
              const Divider(height: 1),
              const SizedBox(height: 8),
              _buildSubComments(theme),
              const SizedBox(height: 8),
              _buildReplyRow(context, theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubComments(ThemeData theme) {
    if (subLoading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (subFailed) {
      return Row(
        children: [
          Text(
            t.bika.networkError,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const Spacer(),
          TextButton(onPressed: onRetrySub, child: Text(t.bika.retry)),
        ],
      );
    }
    if (subComments.isEmpty) {
      return Text(
        t.bika.empty,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      children: [
        for (final sub in subComments)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BikaAvatarImage(
                  image: sub.user.avatar,
                  name: sub.user.name,
                  radius: 12,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              sub.user.name,
                              style: theme.textTheme.labelMedium,
                            ),
                          ),
                          Text(
                            formatDate(sub.created_at),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Text(sub.content, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 2),
                      _SubLikeButton(
                        liked: subIsLiked(sub.uid, sub.isLiked),
                        count: subLikesCount(sub),
                        onTap: () => onToggleSubLike(sub),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildReplyRow(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: replyActive
              ? MiuixTextField(
                  controller: replyController,
                  singleLine: true,
                  label: t.bika.reply,
                  useLabelAsPlaceholder: true,
                  colors: dimmedHintFieldColors(context),
                )
              : GestureDetector(
                  onTap: onActivateReply,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      t.bika.reply,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 8),
        MiuixIconButton(
          onPressed: replySending ? null : onSendReply,
          child: const Icon(Icons.send, size: 18),
        ),
      ],
    );
  }
}

class _SubLikeButton extends StatelessWidget {
  const _SubLikeButton({
    required this.liked,
    required this.count,
    required this.onTap,
  });

  final bool liked;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = liked ? accentBlue : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Icon(
              liked ? Icons.thumb_up : Icons.thumb_up_outlined,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
