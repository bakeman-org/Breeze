import 'package:auto_route/auto_route.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/global/widgets.dart';
import 'package:zephyr/page/setting/widgets/miuix_setting_helpers.dart';
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class SyncSettingPage extends StatefulWidget {
  const SyncSettingPage({super.key});

  @override
  State<SyncSettingPage> createState() => _SyncSettingPageState();
}

class _SyncSettingPageState extends State<SyncSettingPage> {
  bool _uploading = false;
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<GlobalSettingCubit>();
    final state = cubit.state;
    final configuredSync = isSyncServiceConfigured(state);

    return SettingPageShell(
      title: t.settings.sync,
      child: ListView(
        children: [
          settingSectionTitle(context, t.settings.sync),
          GroupCard(
            children: [
              _syncServiceType(state, cubit),
              webdavSync(context, state.syncSetting.syncServiceType),
              if (configuredSync) _autoSync(state, cubit),
              if (configuredSync && state.syncSetting.autoSync)
                _syncNotify(state, cubit),
              if (configuredSync) _syncSettings(state, cubit),
              if (configuredSync) _syncPlugins(state, cubit),
            ],
          ),
          if (configuredSync) ...[
            settingSectionTitle(context, t.settings.manualSyncSection),
            GroupCard(
              children: [
                _buildManualSyncTile(
                  fallback: Icons.upload_outlined,
                  name: 'upload',
                  title: t.settings.uploadToCloud,
                  subtitle: t.settings.uploadToCloudSubtitle,
                  actionLabel: t.settings.manualUpload,
                  busy: _uploading,
                  onPressed: _manualUpload,
                ),
                _buildManualSyncTile(
                  fallback: Icons.download_outlined,
                  name: 'download',
                  title: t.settings.downloadFromCloud,
                  subtitle: t.settings.downloadFromCloudSubtitle,
                  actionLabel: t.settings.manualDownload,
                  busy: _downloading,
                  onPressed: _manualDownload,
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _manualUpload() async {
    final cubit = context.read<GlobalSettingCubit>();
    setState(() => _uploading = true);
    try {
      await manualUploadToCloud(
        state: cubit.state,
        globalSettingCubit: cubit,
        comicFollowCubit: context.read<ComicFollowCubit>(),
      );
      if (mounted) showSuccessToast(t.settings.manualUploadSuccess);
    } catch (e, s) {
      logger.e('手动上传失败', error: e, stackTrace: s);
      if (mounted) {
        showErrorToast('${t.settings.manualSyncFailed}: $e');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _manualDownload() async {
    final cubit = context.read<GlobalSettingCubit>();
    setState(() => _downloading = true);
    try {
      await manualDownloadFromCloud(
        state: cubit.state,
        globalSettingCubit: cubit,
        comicFollowCubit: context.read<ComicFollowCubit>(),
      );
      if (mounted) showSuccessToast(t.settings.manualDownloadSuccess);
    } catch (e, s) {
      logger.e('手动下载失败', error: e, stackTrace: s);
      if (mounted) {
        showErrorToast('${t.settings.manualSyncFailed}: $e');
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Widget _buildManualSyncTile({
    required IconData fallback,
    required String name,
    required String title,
    required String subtitle,
    required String actionLabel,
    required bool busy,
    required VoidCallback onPressed,
  }) {
    return MiuixBasicComponent(
      title: title,
      summary: subtitle,
      startAction: MiuixSettingHelpers.icon(fallback: fallback, name: name),
      endActions: [
        if (busy)
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          MiuixButton(onPressed: onPressed, child: Text(actionLabel)),
      ],
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }

  Widget _syncServiceType(GlobalSettingState state, GlobalSettingCubit cubit) {
    final syncServiceItems = <SyncServiceType, String>{
      SyncServiceType.none: t.settings.syncServiceNone,
      SyncServiceType.webdav: t.settings.syncServiceWebdav,
      SyncServiceType.s3: t.settings.syncServiceS3,
    };
    final modes = syncServiceItems.keys.toList();

    return MiuixOverlayDropdownPreference(
      title: t.settings.syncService,
      summary: t.settings.syncServiceSubtitle,
      items: [for (final mode in modes) syncServiceItems[mode]!],
      selectedIndex: modes.indexOf(state.syncSetting.syncServiceType),
      onSelectedIndexChange: (index) {
        final value = modes[index];
        if (value == state.syncSetting.syncServiceType) return;
        cubit.updateSyncSetting(
          (current) => current.copyWith(
            syncServiceType: value,
            syncSettings: value == SyncServiceType.none
                ? false
                : current.syncSettings,
          ),
        );
      },
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.storage_outlined,
        name: 'storage',
      ),
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }

  Widget _autoSync(GlobalSettingState state, GlobalSettingCubit cubit) {
    return MiuixSwitchPreference(
      title: t.settings.autoSync,
      summary: t.settings.autoSyncSubtitle,
      value: state.syncSetting.autoSync,
      onChanged: (bool value) {
        cubit.updateSyncSetting((current) => current.copyWith(autoSync: value));
        if (value) {
          eventBus.fire(NoticeSync());
        }
      },
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.cloud_sync_outlined,
        name: 'cloud',
      ),
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }

  Widget _syncNotify(GlobalSettingState state, GlobalSettingCubit cubit) {
    return MiuixSwitchPreference(
      title: t.settings.syncNotify,
      summary: t.settings.syncNotifySubtitle,
      value: state.syncSetting.syncNotify,
      onChanged: (bool value) {
        cubit.updateSyncSetting(
          (current) => current.copyWith(syncNotify: value),
        );
      },
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.notifications_active_outlined,
        name: 'notifications',
      ),
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }

  Widget _syncSettings(GlobalSettingState state, GlobalSettingCubit cubit) {
    return MiuixSwitchPreference(
      title: t.settings.syncSettings,
      summary: t.settings.syncSettingsSubtitle,
      value: state.syncSetting.syncSettings,
      onChanged: (bool value) {
        cubit.updateSyncSetting(
          (current) => current.copyWith(syncSettings: value),
        );
      },
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.tune_outlined,
        name: 'tune',
      ),
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }

  Widget _syncPlugins(GlobalSettingState state, GlobalSettingCubit cubit) {
    return MiuixSwitchPreference(
      title: t.settings.syncPlugins,
      summary: t.settings.syncPluginsSubtitle,
      value: state.syncSetting.syncPlugins,
      onChanged: (bool value) {
        cubit.updateSyncSetting(
          (current) => current.copyWith(syncPlugins: value),
        );
      },
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.extension_outlined,
        name: 'extension',
      ),
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }
}
