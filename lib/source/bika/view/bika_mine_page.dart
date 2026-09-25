import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/source/bika/api/bika_api.dart';
import 'package:zephyr/source/bika/auth/bika_setting.dart';
import 'package:zephyr/source/bika/models/bika_models.dart';
import 'package:zephyr/source/bika/view/widgets/bika_avatar_image.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class BikaMinePage extends StatefulWidget {
  const BikaMinePage({super.key});

  @override
  State<BikaMinePage> createState() => _BikaMinePageState();
}

class _BikaMinePageState extends State<BikaMinePage> {
  bool _loggedIn = true;
  bool _loading = true;
  Object? _error;
  User? _user;
  bool _punching = false;

  @override
  void initState() {
    super.initState();
    _loggedIn = bikaNativeSetting.hasAuthorization;
    if (_loggedIn) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await fetchBikaUserProfile();
      if (!mounted) return;
      setState(() {
        _user = resp.user;
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

  Future<void> _goLogin() async {
    await context.pushRoute(const BikaLoginRoute());
    if (!mounted) return;
    final loggedIn = bikaNativeSetting.hasAuthorization;
    setState(() {
      _loggedIn = loggedIn;
      _user = null;
    });
    if (loggedIn) await _load();
  }

  Future<void> _punchIn() async {
    if (_punching) return;
    setState(() => _punching = true);
    try {
      await bikaPunchIn();
      if (!mounted) return;
      showSuccessToast(t.bika.punchInSuccess);
      await _load();
    } catch (e) {
      showErrorToast(e.toString());
    } finally {
      if (mounted) setState(() => _punching = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.bika.logout),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => dialogContext.pop(true),
            child: Text(t.common.ok),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    saveBikaNativeSetting(bikaNativeSetting.copyWith(authorization: ''));
    setState(() {
      _loggedIn = false;
      _user = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: t.bika.mine,
        navigationIcon: MiuixIconButton(
          onPressed: () => context.maybePop(),
          child: const Icon(Icons.arrow_back),
        ),
      ),
      content: (padding) => Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: padding,
          child: _loggedIn ? _buildBody(context) : _buildLoginRequired(),
        ),
      ),
    );
  }

  Widget _buildLoginRequired() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(t.bika.loginRequired, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          MiuixButton(onPressed: _goLogin, child: Text(t.bika.login)),
        ],
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
            Text(t.bika.networkError, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            MiuixButton(onPressed: _load, child: Text(t.bika.retry)),
          ],
        ),
      );
    }
    final user = _user;
    if (user == null) {
      return Center(child: Text(t.bika.notLoggedIn));
    }
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BikaAvatarImage(image: user.avatar, name: user.name, radius: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${user.title} · ${t.bika.level} ${user.level} · Exp ${user.exp}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (user.slogan.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.slogan,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (user.isPunched)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    t.bika.punchInDone,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MiuixButton(
          onPressed: _punching ? null : _punchIn,
          child: _punching
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(user.isPunched ? t.bika.punchInDone : t.bika.punchIn),
        ),
        const SizedBox(height: 16),
        _buildEntry(context, Icons.favorite_outline, t.bika.favourite, () {
          context.pushRoute(const BikaFavoritesRoute());
        }),
        _buildEntry(context, Icons.comment_outlined, t.bika.myComments, () {
          context.pushRoute(const BikaMyCommentsRoute());
        }),
        _buildEntry(context, Icons.settings_outlined, t.bika.settings, () {
          context.pushRoute(const BikaSettingsRoute());
        }),
        _buildEntry(context, Icons.logout, t.bika.logout, _logout),
      ],
    );
  }

  Widget _buildEntry(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
