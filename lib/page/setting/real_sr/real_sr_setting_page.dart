import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/real_sr/service/android_ncnn_model_config.dart';
import 'package:zephyr/page/setting/real_sr/service/desktop_ncnn_model_config.dart';
import 'package:zephyr/page/setting/real_sr/service/real_sr_settings.dart';
import 'package:zephyr/page/setting/real_sr/service/real_sr_super_resolution.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/coreml_model_config.dart';
import 'package:zephyr/page/setting/widgets/miuix_setting_helpers.dart';
import 'package:zephyr/widgets/toast.dart';

final Map<int, String> _concurrencyLabels = {
  1: '1',
  2: '2',
  4: '4',
  6: '6',
  8: '8',
  0: t.realSr.unlimited,
};

const Map<int, String> _tileSizeLabels = {
  0: '0',
  128: '128',
  256: '256',
  512: '512',
  1024: '1024',
};

final List<int> _concurrencyOptions = _concurrencyLabels.keys.toList()..sort();
final List<int> _tileSizeOptions = _tileSizeLabels.keys.toList()..sort();

@RoutePage()
class RealSrSettingPage extends StatefulWidget {
  const RealSrSettingPage({super.key});

  @override
  State<RealSrSettingPage> createState() => _RealSrSettingPageState();
}

class _RealSrSettingPageState extends State<RealSrSettingPage> {
  bool _loading = true;
  bool _autoUpscale = false;
  RealSrResolutionThreshold _resolutionThreshold =
      RealSrResolutionThreshold.p720;
  int _concurrency = 2;
  int _tileSize = 0;
  AndroidNcnnMode _desktopNcnnMode = DesktopNcnnModelConfig.defaultMode;
  AndroidNcnnNoise _desktopNcnnNoise = DesktopNcnnModelConfig.defaultNoise;
  CoreMLModelFamily _coreMLFamily = CoreMLModelConfig.defaultFamily;
  CoreMLModelVariant _coreMLVariant = CoreMLModelConfig.defaultVariant;
  bool _isAvailable = false;
  bool _downloading = false;
  bool _importing = false;
  double _downloadProgress = 0;

  bool get _usesCoreML => Platform.isIOS || Platform.isMacOS;

  List<RealSrResolutionThreshold> get _availableThresholds {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return RealSrResolutionThreshold.values;
    }
    return const [
      RealSrResolutionThreshold.p540,
      RealSrResolutionThreshold.p720,
      RealSrResolutionThreshold.p1080,
    ];
  }

  RealSrResolutionThreshold get _effectiveThreshold {
    if (_availableThresholds.contains(_resolutionThreshold)) {
      return _resolutionThreshold;
    }
    return RealSrResolutionThreshold.p1080;
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final family = await RealSrSettings.loadCoreMLFamily();
    final variant = await RealSrSettings.loadCoreMLVariant(family);
    final results = await Future.wait([
      RealSrSettings.loadAutoUpscale(),
      RealSrSettings.loadResolutionThreshold(),
      RealSrSettings.loadConcurrency(),
      RealSrSettings.loadTileSize(),
      RealSrSettings.loadDesktopNcnnMode(),
      RealSrSettings.loadDesktopNcnnNoise(),
      RealSrSuperResolution.isAvailable,
    ]);

    if (!mounted) return;
    setState(() {
      _autoUpscale = results[0] as bool;
      _resolutionThreshold = results[1] as RealSrResolutionThreshold;
      _concurrency = results[2] as int;
      _tileSize = results[3] as int;
      _desktopNcnnMode = results[4] as AndroidNcnnMode;
      _desktopNcnnNoise = results[5] as AndroidNcnnNoise;
      _isAvailable = results[6] as bool;
      _coreMLFamily = family;
      _coreMLVariant = variant;
      _loading = false;
    });
  }

  Future<void> _setAutoUpscale(bool value) async {
    await RealSrSettings.saveAutoUpscale(value);
    setState(() => _autoUpscale = value);
  }

  Future<void> _setResolutionThreshold(RealSrResolutionThreshold value) async {
    await RealSrSettings.saveResolutionThreshold(value);
    setState(() => _resolutionThreshold = value);
  }

  Future<void> _setConcurrency(int value) async {
    await RealSrSettings.saveConcurrency(value);
    setState(() => _concurrency = value);
  }

  Future<void> _setTileSize(int value) async {
    await RealSrSettings.saveTileSize(value);
    setState(() => _tileSize = value);
  }

  Future<void> _setDesktopNcnnMode(AndroidNcnnMode value) async {
    await RealSrSettings.saveDesktopNcnnMode(value);
    setState(() => _desktopNcnnMode = value);
  }

  Future<void> _setDesktopNcnnNoise(AndroidNcnnNoise value) async {
    await RealSrSettings.saveDesktopNcnnNoise(value);
    setState(() => _desktopNcnnNoise = value);
  }

  Future<void> _setCoreMLFamily(CoreMLModelFamily value) async {
    final newVariant = value.variants.first;
    await Future.wait([
      RealSrSettings.saveCoreMLFamily(value),
      RealSrSettings.saveCoreMLVariant(newVariant),
    ]);
    setState(() {
      _coreMLFamily = value;
      _coreMLVariant = newVariant;
    });
  }

  Future<void> _setCoreMLVariant(CoreMLModelVariant value) async {
    await RealSrSettings.saveCoreMLVariant(value);
    setState(() => _coreMLVariant = value);
  }

  Future<void> _refreshAvailability() async {
    final available = await RealSrSuperResolution.isAvailable;
    if (mounted) setState(() => _isAvailable = available);
  }

  Future<void> _downloadModel() async {
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });

    try {
      await RealSrSuperResolution.downloadModel(
        force: _isAvailable,
        onProgress: (received, total) {
          if (!mounted || total <= 0) return;
          setState(() => _downloadProgress = received / total);
        },
      );
    } catch (e, s) {
      logger.e('模型下载失败', error: e, stackTrace: s);
      showErrorToast('${t.realSr.modelDownloadFailed}: $e');
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
        await _refreshAvailability();
      }
    }
  }

  Future<void> _deleteModel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.realSr.deleteModel),
        content: Text(t.realSr.deleteModelConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.common.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await RealSrSuperResolution.deleteModel();
      showSuccessToast(t.realSr.modelDeleted);
    } catch (e, s) {
      logger.e('模型删除失败', error: e, stackTrace: s);
      showErrorToast('${t.realSr.modelDeleteFailed}: $e');
    } finally {
      if (mounted) await _refreshAvailability();
    }
  }

  Future<void> _openManualDownloadUrl() async {
    final url = RealSrSuperResolution.manualDownloadUrl;
    if (url == null) {
      showErrorToast(t.realSr.manualDownloadUnsupported);
      return;
    }
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      showErrorToast(t.realSr.openDownloadUrlFailed);
    }
  }

  Future<void> _importModel() async {
    // iOS 没有系统声明的 7z UTI，使用通用数据类型后由导入逻辑校验 7z 魔数。
    final typeGroup = Platform.isIOS
        ? const XTypeGroup(label: '7z')
        : const XTypeGroup(label: '7z', extensions: ['7z']);
    final XFile? file;
    try {
      file = await openFile(acceptedTypeGroups: [typeGroup]);
    } catch (e) {
      showErrorToast('${t.realSr.modelImportFailed}: $e');
      return;
    }
    if (file == null) return;

    setState(() => _importing = true);
    try {
      await RealSrSuperResolution.importModelArchive(file.path);
      if (mounted) showSuccessToast(t.realSr.modelImportSuccess);
    } catch (e, s) {
      logger.e('模型导入失败', error: e, stackTrace: s);
      if (mounted) {
        showErrorToast('${t.realSr.modelImportFailed}: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
        await _refreshAvailability();
      }
    }
  }

  String get _coreMLBlockInfo {
    final blockSize = _coreMLVariant.config['blockSize'] as int? ?? 0;
    final shrinkSize = _coreMLVariant.config['shrinkSize'] as int? ?? 0;
    final contentSize = CoreMLModelConfig.contentBlockSize(_coreMLVariant);
    return t.realSr.blockInfoFormat(
      contentSize: contentSize,
      blockSize: blockSize,
      shrinkSize: shrinkSize,
    );
  }

  List<Widget> _buildModelItems() {
    if (_usesCoreML) {
      final families = CoreMLModelConfig.families;
      final variants = _coreMLFamily.variants;
      return [
        MiuixOverlayDropdownPreference(
          title: t.realSr.model,
          summary: t.realSr.modelSubtitle,
          items: [for (final family in families) family.localizedLabel],
          selectedIndex: families.indexOf(_coreMLFamily),
          onSelectedIndexChange: (index) =>
              _setCoreMLFamily(families[index]),
          startAction: MiuixSettingHelpers.icon(
            fallback: Icons.speed_outlined,
            name: 'speed',
          ),
          insideMargin: MiuixSettingHelpers.itemMargin,
        ),
        MiuixOverlayDropdownPreference(
          title: t.realSr.noiseLevel,
          summary: t.realSr.noiseLevelSubtitle,
          items: [
            for (final variant in variants) variant.localizedDisplayName,
          ],
          selectedIndex: variants.indexOf(_coreMLVariant),
          onSelectedIndexChange: (index) =>
              _setCoreMLVariant(variants[index]),
          startAction: MiuixSettingHelpers.icon(
            fallback: Icons.healing_outlined,
            name: 'healing',
          ),
          insideMargin: MiuixSettingHelpers.itemMargin,
        ),
        MiuixBasicComponent(
          title: t.realSr.blockInfo,
          summary: _coreMLBlockInfo,
          startAction: MiuixSettingHelpers.icon(
            fallback: Icons.grid_view_outlined,
            name: 'grid_view',
          ),
          endActions: [
            Tooltip(
              triggerMode: TooltipTriggerMode.tap,
              showDuration: const Duration(seconds: 5),
              message: t.realSr.blockInfoTooltip,
              child: const Icon(Icons.help_outline),
            ),
          ],
          insideMargin: MiuixSettingHelpers.itemMargin,
        ),
      ];
    }

    if (Platform.isAndroid) {
      return [
        MiuixBasicComponent(
          title: t.realSr.androidSuperResolution,
          summary: t.realSr.androidSuperResolutionSubtitle,
          startAction: MiuixSettingHelpers.icon(
            fallback: Icons.info_outline,
            name: 'info',
          ),
          insideMargin: MiuixSettingHelpers.itemMargin,
        ),
      ];
    }

    final modes = AndroidNcnnMode.values;
    final noises = AndroidNcnnNoise.values;
    return [
      MiuixOverlayDropdownPreference(
        title: t.realSr.desktopStrategy,
        summary: t.realSr.desktopStrategySubtitle,
        items: [for (final mode in modes) mode.label],
        selectedIndex: modes.indexOf(_desktopNcnnMode),
        onSelectedIndexChange: (index) => _setDesktopNcnnMode(modes[index]),
        startAction: MiuixSettingHelpers.icon(
          fallback: Icons.speed_outlined,
          name: 'speed',
        ),
        insideMargin: MiuixSettingHelpers.itemMargin,
      ),
      MiuixOverlayDropdownPreference(
        title: t.realSr.desktopNoiseLevel,
        summary: t.realSr.desktopNoiseLevelSubtitle,
        items: [for (final noise in noises) noise.label],
        selectedIndex: noises.indexOf(_desktopNcnnNoise),
        onSelectedIndexChange: (index) => _setDesktopNcnnNoise(noises[index]),
        startAction: MiuixSettingHelpers.icon(
          fallback: Icons.healing_outlined,
          name: 'healing',
        ),
        insideMargin: MiuixSettingHelpers.itemMargin,
      ),
    ];
  }

  Widget _buildModelManagementTile() {
    if (_downloading) {
      return MiuixBasicComponent(
        title: t.realSr.downloadingModel,
        startAction: MiuixSettingHelpers.icon(
          fallback: Icons.downloading_outlined,
          name: 'download',
        ),
        bottomAction: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _downloadProgress),
            const SizedBox(height: 4),
            Text('${(_downloadProgress * 100).toStringAsFixed(1)}%'),
          ],
        ),
        insideMargin: MiuixSettingHelpers.itemMargin,
      );
    }

    if (_isAvailable) {
      return MiuixBasicComponent(
        title: t.realSr.modelReady,
        startAction: Icon(
          Icons.check_circle,
          color: Theme.of(context).colorScheme.primary,
        ),
        endActions: [
          Tooltip(
            message: t.realSr.redownload,
            child: MiuixIconButton(
              onPressed: _downloadModel,
              child: const Icon(Icons.refresh),
            ),
          ),
          Tooltip(
            message: t.realSr.deleteModel,
            child: MiuixIconButton(
              onPressed: _deleteModel,
              child: const Icon(Icons.delete_outline),
            ),
          ),
        ],
        insideMargin: MiuixSettingHelpers.itemMargin,
      );
    }

    return MiuixBasicComponent(
      title: t.realSr.modelNotDownloaded,
      summary: t.realSr.modelNotDownloadedSubtitle,
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.warning_amber_rounded,
        name: 'warning',
      ),
      endActions: [
        MiuixButton(
          onPressed: _downloadModel,
          child: Text(t.realSr.downloadModel),
        ),
      ],
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }

  Widget _buildManualDownloadTile() {
    final url = RealSrSuperResolution.manualDownloadUrl;
    if (url == null) {
      return MiuixBasicComponent(
        title: t.realSr.manualDownload,
        summary: t.realSr.manualDownloadUnsupported,
        startAction: MiuixSettingHelpers.icon(
          fallback: Icons.open_in_browser_outlined,
          name: 'open_in_browser',
        ),
        insideMargin: MiuixSettingHelpers.itemMargin,
      );
    }
    return MiuixBasicComponent(
      title: t.realSr.manualDownload,
      summary: url,
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.open_in_browser_outlined,
        name: 'open_in_browser',
      ),
      endActions: [
        MiuixButton(
          onPressed: _openManualDownloadUrl,
          child: Text(t.realSr.openDownloadUrl),
        ),
      ],
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }

  Widget _buildImportModelTile() {
    return MiuixBasicComponent(
      title: t.realSr.importModel,
      summary: t.realSr.importModelSubtitle,
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.file_open_outlined,
        name: 'file_open',
      ),
      endActions: [
        if (_importing)
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          MiuixButton(
            onPressed: _importModel,
            child: Text(t.realSr.importModelAction),
          ),
      ],
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingPageShell(
      title: t.realSr.title,
      child: _loading
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : ListView(
              children: [
                settingSectionTitle(context, t.realSr.autoUpscaleSection),
                GroupCard(
                  children: [
                    MiuixSwitchPreference(
                      title: t.realSr.autoUpscale,
                      summary: !_isAvailable
                          ? t.realSr.autoUpscaleSubtitleUnavailable
                          : t.realSr.autoUpscaleSubtitleAvailable,
                      value: _autoUpscale,
                      onChanged: _setAutoUpscale,
                      startAction: MiuixSettingHelpers.icon(
                        fallback: Icons.auto_fix_high_outlined,
                        name: 'auto_fix_high',
                      ),
                      insideMargin: MiuixSettingHelpers.itemMargin,
                    ),
                  ],
                ),

                settingSectionTitle(context, t.realSr.conditionSection),
                GroupCard(
                  children: [
                    MiuixOverlayDropdownPreference(
                      title: t.realSr.resolutionThreshold,
                      summary: t.realSr.resolutionThresholdSubtitle,
                      items: [
                        for (final threshold in _availableThresholds)
                          threshold.label,
                      ],
                      selectedIndex:
                          _availableThresholds.indexOf(_effectiveThreshold),
                      onSelectedIndexChange: (index) =>
                          _setResolutionThreshold(_availableThresholds[index]),
                      startAction: MiuixSettingHelpers.icon(
                        fallback: Icons.hd_outlined,
                        name: 'hd',
                      ),
                      insideMargin: MiuixSettingHelpers.itemMargin,
                    ),
                  ],
                ),

                settingSectionTitle(context, t.realSr.performanceSection),
                GroupCard(
                  children: [
                    Builder(
                      builder: (context) {
                        final effective = _concurrencyOptions.contains(
                          _concurrency,
                        )
                            ? _concurrency
                            : RealSrSettings.defaultConcurrency;
                        return MiuixOverlayDropdownPreference(
                          title: t.realSr.concurrency,
                          summary: t.realSr.concurrencySubtitle,
                          items: [
                            for (final option in _concurrencyOptions)
                              _concurrencyLabels[option]!,
                          ],
                          selectedIndex:
                              _concurrencyOptions.indexOf(effective),
                          onSelectedIndexChange: (index) =>
                              _setConcurrency(_concurrencyOptions[index]),
                          startAction: MiuixSettingHelpers.icon(
                            fallback: Icons.speed_outlined,
                            name: 'speed',
                          ),
                          insideMargin: MiuixSettingHelpers.itemMargin,
                        );
                      },
                    ),
                    if (!_usesCoreML)
                      Builder(
                        builder: (context) {
                          final effective = _tileSizeOptions.contains(
                            _tileSize,
                          )
                              ? _tileSize
                              : 0;
                          return MiuixOverlayDropdownPreference(
                            title: t.realSr.tileSize,
                            summary: t.realSr.tileSizeSubtitle,
                            items: [
                              for (final option in _tileSizeOptions)
                                _tileSizeLabels[option]!,
                            ],
                            selectedIndex: _tileSizeOptions.indexOf(effective),
                            onSelectedIndexChange: (index) =>
                                _setTileSize(_tileSizeOptions[index]),
                            startAction: MiuixSettingHelpers.icon(
                              fallback: Icons.grid_on_outlined,
                              name: 'grid_on',
                            ),
                            insideMargin: MiuixSettingHelpers.itemMargin,
                          );
                        },
                      ),
                  ],
                ),

                settingSectionTitle(context, t.realSr.modelSection),
                GroupCard(children: _buildModelItems()),

                settingSectionTitle(context, t.realSr.modelManagementSection),
                GroupCard(
                  children: [
                    _buildModelManagementTile(),
                    _buildManualDownloadTile(),
                    _buildImportModelTile(),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
