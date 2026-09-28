// lib/page/changelog/widgets/releases_tab.dart
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/http/wind_http.dart';
import 'package:zephyr/network/utils/github_proxy.dart';
import 'package:zephyr/page/changelog/widgets/release_card.dart';
import 'package:zephyr/service/update/json/github_release_json.dart';
import 'package:zephyr/util/error_filter.dart';

const _proxyReleasesApiUrl =
    '$breezeGithubApi/repos/bakeman-org/breeze/releases';
const _githubReleasesApiUrl =
    'https://api.github.com/repos/bakeman-org/breeze/releases';

class ReleasesTab extends StatefulWidget {
  const ReleasesTab({super.key});

  @override
  State<ReleasesTab> createState() => _ReleasesTabState();
}

class _ReleasesTabState extends State<ReleasesTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  List<GithubReleaseJson> _releases = [];
  bool _isLoading = true;
  String? _errorMsg;

  int _page = 1;
  static const int _perPage = 20;
  bool _hasMore = true;
  bool _isFetching = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _fetchReleases(refresh: true);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        !_hasMore ||
        _isFetching ||
        _scrollController.position.pixels <
            _scrollController.position.maxScrollExtent - 400) {
      return;
    }
    _fetchReleases();
  }

  Future<void> _fetchReleases({bool refresh = false}) async {
    if (_isFetching) return;
    _isFetching = true;
    if (!refresh && mounted) setState(() {});

    try {
      final requestPage = refresh ? 1 : _page;

      List<GithubReleaseJson>? newData;
      for (final url in [_proxyReleasesApiUrl, _githubReleasesApiUrl]) {
        try {
          final response = await fetch(
            url,
            query: {'page': requestPage, 'per_page': _perPage},
            headers: {'Accept': 'application/vnd.github.v3+json'},
          );

          if (response.ok) {
            newData = githubReleaseJsonFromJson(response.text);
            break;
          }
        } catch (_) {
          // 尝试下一个地址。
        }
      }

      final releases = newData;
      if (releases != null) {
        if (mounted) {
          setState(() {
            if (refresh) {
              _releases = releases;
              _errorMsg = null;
            } else {
              _releases.addAll(releases);
            }
            _page = requestPage + 1;
            _hasMore = releases.length >= _perPage;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('所有更新日志请求地址均失败');
      }
    } catch (e) {
      if (mounted) {
        if (_releases.isEmpty && refresh) {
          setState(() {
            _isLoading = false;
            _errorMsg = normalizeSearchErrorMessage(e);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.changelog.loadFailedWithError(error: e))),
          );
        }
      }
    } finally {
      _isFetching = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.changelog.cannotOpenLink(url: urlString))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Center(
        child: LoadingAnimationWidget.staggeredDotsWave(
          color: colorScheme.primary,
          size: 50,
        ),
      );
    }

    if (_errorMsg != null && _releases.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              t.changelog.checkNetwork,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            MiuixButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMsg = null;
                });
                _fetchReleases(refresh: true);
              },
              child: Text(t.changelog.retry),
            ),
          ],
        ),
      );
    }

    if (_releases.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _fetchReleases(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.8,
              child: Center(child: Text(t.changelog.empty)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchReleases(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _releases.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _releases.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final release = _releases[index];
          return Container(
            key: ValueKey(release.id),
            child: ReleaseCard(release: release, onLinkTap: _launchUrl)
                .animate()
                .fade(duration: 400.ms)
                .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
          );
        },
      ),
    );
  }
}
