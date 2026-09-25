import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/util/get_path.dart';
import 'package:zephyr/util/manage_cache.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/toast.dart';

import 'package:zephyr/page/setting/widgets/miuix_setting_helpers.dart';

const Map<int, String> _cacheLimitLabels = {
  536870912: '512 MB',
  1073741824: '1 GB',
  2147483648: '2 GB',
  4294967296: '4 GB',
  8589934592: '8 GB',
  17179869184: '16 GB',
};

final List<int> _cacheLimitOptions = _cacheLimitLabels.keys.toList()..sort();

@RoutePage()
class CacheSettingPage extends StatefulWidget {
  const CacheSettingPage({super.key});

  @override
  State<CacheSettingPage> createState() => _CacheSettingPageState();
}

class _CacheSettingPageState extends State<CacheSettingPage> {
  int? _cacheSizeBytes;
  bool _calculating = false;

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    if (_calculating) return;
    setState(() => _calculating = true);

    try {
      final cachePath = await getCachePath();
      final directory = Directory(cachePath);
      if (!await directory.exists()) {
        if (!mounted) return;
        setState(() {
          _cacheSizeBytes = 0;
          _calculating = false;
        });
        return;
      }

      int totalSize = 0;
      final entities = directory.listSync(recursive: true);
      for (final entity in entities) {
        final isSentry = entity.path
            .split(Platform.pathSeparator)
            .contains('sentry');
        if (entity is File && !isSentry) {
          try {
            totalSize += await entity.length();
          } on FileSystemException {
            continue;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _cacheSizeBytes = totalSize;
        _calculating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cacheSizeBytes = null;
        _calculating = false;
      });
    }
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return t.cache.calculateFailed;
    if (bytes == 0) return '0 B';

    const gb = 1 << 30;
    const mb = 1 << 20;
    const kb = 1 << 10;

    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(2)} GB';
    } else if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    } else if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(1)} KB';
    } else {
      return '$bytes B';
    }
  }

  Future<void> _handleClearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.cache.clearCache),
        content: Text(t.cache.clearCacheConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.common.ok),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final cachePath = await getCachePath();
      await clearCache(cachePath);
      showSuccessToast(t.cache.cleared);
      _calculateCacheSize();
    } catch (_) {
      showSuccessToast(t.cache.clearFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<GlobalSettingCubit>();
    final state = cubit.state;

    return MiuixScaffold(
      topBar: MiuixSmallTopAppBar(
        title: t.cache.title,
        navigationIcon: MiuixIconButton(
          onPressed: () => context.maybePop(),
          child: const Icon(Icons.arrow_back),
        ),
      ),
      content: (padding) => Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: padding,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 768),
              child: ListView(
                children: [
                  MiuixSmallTitle(t.cache.currentCache),
                  GroupCard(
                    children: [
                      MiuixBasicComponent(
                        title: t.cache.cacheSize,
                        summary: _calculating
                            ? t.cache.calculating
                            : _formatSize(_cacheSizeBytes),
                        startAction: MiuixSettingHelpers.icon(
                          fallback: Icons.storage_outlined,
                          name: 'storage',
                        ),
                        endActions: [
                          if (_calculating)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Tooltip(
                              message: t.cache.recalculate,
                              child: MiuixIconButton(
                                minWidth: 32,
                                minHeight: 32,
                                onPressed: _calculateCacheSize,
                                child: const Icon(Icons.refresh, size: 20),
                              ),
                            ),
                        ],
                        insideMargin: MiuixSettingHelpers.itemMargin,
                      ),
                      MiuixBasicComponent(
                        title: t.cache.manualClear,
                        summary: t.cache.manualClearSubtitle,
                        startAction: MiuixSettingHelpers.icon(
                          fallback: Icons.cleaning_services_outlined,
                          name: 'cleaning_services',
                        ),
                        endActions: [
                          MiuixButton(
                            onPressed: _handleClearCache,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.delete_outline, size: 18),
                                const SizedBox(width: 8),
                                Text(t.cache.clear),
                              ],
                            ),
                          ),
                        ],
                        insideMargin: MiuixSettingHelpers.itemMargin,
                      ),
                    ],
                  ),
                  MiuixSmallTitle(t.cache.cacheLimit),
                  GroupCard(
                    children: [
                      MiuixOverlayDropdownPreference(
                        title: t.cache.sizeLimit,
                        summary: t.cache.sizeLimitSubtitle,
                        items: [
                          for (final option in _cacheLimitOptions)
                            _cacheLimitLabels[option]!,
                        ],
                        selectedIndex: _cacheLimitOptions.indexOf(
                          _cacheLimitOptions.contains(
                                state.cacheSetting.cacheSizeLimit,
                              )
                              ? state.cacheSetting.cacheSizeLimit
                              : 1073741824,
                        ),
                        onSelectedIndexChange: (index) {
                          cubit.updateCacheSetting(
                            (current) => current.copyWith(
                              cacheSizeLimit: _cacheLimitOptions[index],
                            ),
                          );
                        },
                        startAction: MiuixSettingHelpers.icon(
                          fallback: Icons.data_thresholding_outlined,
                          name: 'data_thresholding',
                        ),
                        insideMargin: MiuixSettingHelpers.itemMargin,
                      ),
                    ],
                  ),
                  MiuixSmallTitle(t.cache.autoClean),
                  GroupCard(
                    children: [
                      MiuixSwitchPreference(
                        title: t.cache.autoClean,
                        summary: t.cache.autoCleanSubtitle,
                        value: state.cacheSetting.autoCleanCache,
                        onChanged: (bool value) {
                          cubit.updateCacheSetting(
                            (current) => current.copyWith(autoCleanCache: value),
                          );
                        },
                        startAction: MiuixSettingHelpers.icon(
                          fallback: Icons.auto_delete_outlined,
                          name: 'auto_delete',
                        ),
                        insideMargin: MiuixSettingHelpers.itemMargin,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
