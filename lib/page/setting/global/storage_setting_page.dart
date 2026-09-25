import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/widgets/miuix_setting_helpers.dart';
import 'package:zephyr/util/get_path.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class StorageSettingPage extends StatefulWidget {
  const StorageSettingPage({super.key});

  @override
  State<StorageSettingPage> createState() => _StorageSettingPageState();
}

class _StorageSettingPageState extends State<StorageSettingPage> {
  int? _cacheSizeBytes;
  bool _cacheCalculating = false;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    if (_cacheCalculating) return;
    setState(() => _cacheCalculating = true);

    try {
      final cachePath = await getCachePath();
      final directory = Directory(cachePath);
      if (!await directory.exists()) {
        if (!mounted) return;
        setState(() {
          _cacheSizeBytes = 0;
          _cacheCalculating = false;
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
        _cacheCalculating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cacheSizeBytes = null;
        _cacheCalculating = false;
      });
    }
  }

  String _formatCacheSize(int? bytes) {
    if (bytes == null) return '';
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

  Widget _customExportPath(GlobalSettingState state, GlobalSettingCubit cubit) {
    final exportPath = state.customExportPath.trim();
    return MiuixArrowPreference(
      title: t.settings.customExportPath,
      summary: exportPath.isEmpty ? t.settings.notSet : exportPath,
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.folder_outlined,
        name: 'folder',
      ),
      endActions: [
        if (exportPath.isNotEmpty)
          MiuixIconButton(
            onPressed: () {
              cubit.updateState(
                (current) => current.copyWith(customExportPath: ''),
              );
              showSuccessToast(t.common.settingSaved);
            },
            child: const Icon(Icons.clear, size: 20),
          ),
      ],
      insideMargin: MiuixSettingHelpers.itemMargin,
      onClick: () async {
        final selected = await getDirectoryPath();
        if (selected != null && selected.trim().isNotEmpty) {
          cubit.updateState(
            (current) => current.copyWith(customExportPath: selected),
          );
          showSuccessToast(t.common.settingSaved);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<GlobalSettingCubit>();
    final state = cubit.state;
    final sizeText = _cacheCalculating
        ? t.settings.calculatingCache
        : _formatCacheSize(_cacheSizeBytes);

    return SettingPageShell(
      title: t.settings.storage,
      child: ListView(
        children: [
          settingSectionTitle(context, t.settings.storage),
          GroupCard(
            children: [
              MiuixArrowPreference(
                title: t.settings.cache,
                summary: sizeText.isEmpty ? t.settings.cache : sizeText,
                startAction: MiuixSettingHelpers.icon(
                  fallback: Icons.cleaning_services_outlined,
                  name: 'cleaning_services',
                ),
                insideMargin: MiuixSettingHelpers.itemMargin,
                onClick: () async {
                  await context.pushRoute(const CacheSettingRoute());
                  if (mounted) await _loadCacheSize();
                },
              ),
              MiuixArrowPreference(
                title: t.settings.dataBackup,
                summary: t.settings.dataBackupSubtitle,
                startAction: MiuixSettingHelpers.icon(
                  fallback: Icons.import_export_outlined,
                  name: 'import_export',
                ),
                insideMargin: MiuixSettingHelpers.itemMargin,
                onClick: () => context.pushRoute(const DataBackupRoute()),
              ),
              if (!Platform.isIOS) _customExportPath(state, cubit),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
