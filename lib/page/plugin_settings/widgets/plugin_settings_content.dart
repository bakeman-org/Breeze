import 'package:flutter_miuix/miuix.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/plugin_settings/cubit/plugin_settings_cubit.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_sections.dart';
import 'package:zephyr/page/setting/common/plugin_user_info_card.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/widgets/miuix_setting_helpers.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/widgets/fluent_dropdown.dart';
import 'package:zephyr/widgets/multi_choice_list_dialog.dart';

class PluginSettingsContent extends StatefulWidget {
  const PluginSettingsContent({
    super.key,
    required this.from,
    required this.pluginRuntimeName,
    required this.state,
    required this.debugEnabled,
    required this.debugUrl,
    required this.deleted,
    required this.pluginVersion,
    required this.colorScheme,
    required this.onUpdateDebugConfig,
    required this.onConfirmDeletePlugin,
    required this.onUpdatePlugin,
    required this.onCommitField,
    required this.onRunAction,
    required this.onLogin,
  });

  final String from;
  final String pluginRuntimeName;
  final PluginSettingsState state;
  final bool debugEnabled;
  final String debugUrl;
  final bool deleted;
  final String pluginVersion;
  final ColorScheme colorScheme;
  final Future<void> Function({required bool enabled, required String url})
  onUpdateDebugConfig;
  final Future<void> Function() onConfirmDeletePlugin;
  final Future<void> Function() onUpdatePlugin;
  final Future<void> Function(Map<String, dynamic> field, dynamic value)
  onCommitField;
  final Future<void> Function(Map<String, dynamic> action) onRunAction;

  /// 未登录时点击「登录」按钮的回调：由父页面负责跳转登录页，
  /// 并在登录流程返回后重新加载插件设置。
  final Future<void> Function() onLogin;

  @override
  State<PluginSettingsContent> createState() => _PluginSettingsContentState();
}

class _PluginSettingsContentState extends State<PluginSettingsContent> {
  /// 字段 key → [TextEditingController] 的持有表。
  ///
  /// 由本 State 统一持有 controller，好处：
  /// - 按钮组能直接清空 / 读取文本，不需要 GlobalKey 去访问子 State；
  /// - controller 的生命周期与页面一致，跨 rebuild 稳定，光标不丢；
  /// - 输入框仅负责展示与键盘交互，不管理值本身。
  final _textControllers = <String, TextEditingController>{};

  /// 获取（必要时创建）某个字段的 controller。首次创建时用当前
  /// cubit 值作为初始文本。
  TextEditingController _controllerFor(String key) {
    return _textControllers.putIfAbsent(
      key,
      () => TextEditingController(
        text: widget.state.values[key]?.toString() ?? '',
      ),
    );
  }

  /// 是否已登录：以 `getUserInfoBundle` 是否成功返回内容为准。
  ///
  /// - `canShowUserInfo == true` 时：`userInfo` 非空视为已登录；
  /// - `canShowUserInfo == false` 时：插件本身不上报用户信息，
  ///   视为「已登录」以保留原来的清除 / 提交按钮组。
  bool get _isLoggedIn {
    if (!widget.state.canShowUserInfo) {
      return true;
    }
    return widget.state.userInfo.isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant PluginSettingsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 插件返回的 values 更新（例如刚登录成功）时，把新值写回对应 controller。
    // 这样从 LoginPage 返回、reload 后账号密码输入框会自动回填。
    for (final entry in widget.state.values.entries) {
      final controller = _textControllers[entry.key];
      if (controller == null) continue;
      final next = entry.value?.toString() ?? '';
      if (controller.text != next) {
        controller.text = next;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    _textControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // 插件自身设置优先，宿主管理项沉底
        ..._buildBodySections(context),
        _buildManagementSection(context),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  插件管理区（版本 / 更新 / 调试 / 删除）
  // ─────────────────────────────────────────────
  Widget _buildManagementSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: PluginSettingsSectionCard(
        title: t.plugin.management,
        colorScheme: widget.colorScheme,
        children: _buildManagementRows(context),
      ),
    );
  }

  List<Widget> _buildManagementRows(BuildContext context) {
    return [
      _buildVersionRow(),
      _buildUpdatePluginRow(),
      _buildDebugModeRow(),
      if (widget.debugEnabled) _buildDebugUrlRow(context),
      _buildDeletePluginRow(),
    ];
  }

  Widget _buildVersionRow() {
    final version = widget.pluginVersion.trim().isEmpty
        ? '-'
        : widget.pluginVersion.trim();
    return PluginSettingsFieldRow(
      title: t.plugin.version,
      subtitle: t.plugin.currentVersion(version: version),
      trailing: const Icon(Icons.info_outline, size: 18),
      onTap: null,
    );
  }

  Widget _buildUpdatePluginRow() {
    return PluginSettingsFieldRow(
      title: t.plugin.update,
      subtitle: t.plugin.updateSubtitle,
      trailing: const Icon(Icons.system_update_alt, size: 18),
      onTap: widget.deleted ? null : widget.onUpdatePlugin,
    );
  }

  Widget _buildDebugModeRow() {
    return PluginSettingsFieldRow(
      title: t.plugin.debugMode,
      subtitle: widget.debugEnabled ? t.common.enabled : t.common.disabled,
      trailing: Switch(
        value: widget.debugEnabled,
        thumbIcon: kSettingSwitchThumbIcon,
        onChanged: widget.deleted
            ? null
            : (next) => widget.onUpdateDebugConfig(
                enabled: next,
                url: widget.debugUrl,
              ),
      ),
      onTap: widget.deleted
          ? null
          : () => widget.onUpdateDebugConfig(
              enabled: !widget.debugEnabled,
              url: widget.debugUrl,
            ),
    );
  }

  /// 调试地址仍走弹窗：它是宿主侧配置项、不属于插件 section，
  /// 与「用户名 / 密码」的内联交互保持分离。
  Widget _buildDebugUrlRow(BuildContext context) {
    return PluginSettingsFieldRow(
      title: t.plugin.debugAddress,
      subtitle: widget.debugUrl.isNotEmpty
          ? widget.debugUrl
          : t.settings.notSet,
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: widget.deleted
          ? null
          : () async {
              final next = await _showInputDialog(
                context,
                title: t.plugin.debugAddress,
                initialValue: widget.debugUrl,
                obscure: false,
              );
              if (next == null) return;
              await widget.onUpdateDebugConfig(
                enabled: widget.debugEnabled,
                url: next.trim(),
              );
            },
    );
  }

  Widget _buildDeletePluginRow() {
    return PluginSettingsFieldRow(
      title: t.plugin.deletePlugin,
      subtitle: t.plugin.deletePluginSubtitle,
      trailing: Icon(
        Icons.delete_outline,
        size: 18,
        color: widget.deleted
            ? widget.colorScheme.outline
            : widget.colorScheme.error,
      ),
      onTap: widget.deleted ? null : widget.onConfirmDeletePlugin,
    );
  }

  // ─────────────────────────────────────────────
  //  插件自定义 section（插件返回的 fields）
  // ─────────────────────────────────────────────
  List<Widget> _buildBodySections(BuildContext context) {
    if (widget.state.loading) {
      return [_buildLoadingSection()];
    }
    if (widget.state.error.isNotEmpty) {
      return [_buildErrorSection(context)];
    }

    final sections = <Widget>[];
    final userInfoSection = _buildUserInfoSection(context);
    if (userInfoSection != null) {
      sections.add(userInfoSection);
    }
    sections.addAll(_buildSettingSections(context));
    final actionsSection = _buildActionsSection(context);
    if (actionsSection != null) {
      sections.add(actionsSection);
    }
    return sections;
  }

  Widget _buildLoadingSection() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: PluginSettingsSectionCard(
        title: t.plugin.pluginSettings,
        colorScheme: widget.colorScheme,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.state.error),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () =>
                      context.read<PluginSettingsCubit>().load(widget.from),
                  child: Text(t.common.retry),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildUserInfoSection(BuildContext context) {
    if (!widget.state.canShowUserInfo) {
      return null;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PluginSettingsSectionCard(
        title:
            widget.state.userInfo['title']?.toString() ??
            t.plugin.userInfoTitle,
        colorScheme: widget.colorScheme,
        children: _buildUserInfoChildren(context),
      ),
    );
  }

  List<Widget> _buildUserInfoChildren(BuildContext context) {
    if (widget.state.loadingUserInfo) {
      return const [
        Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (widget.state.userInfoError.isNotEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(child: Text(widget.state.userInfoError)),
              OutlinedButton(
                onPressed: () => context
                    .read<PluginSettingsCubit>()
                    .loadUserInfo(widget.from),
                child: Text(t.common.retry),
              ),
            ],
          ),
        ),
      ];
    }
    if (widget.state.userInfo.isNotEmpty) {
      return [_buildUserInfoCard()];
    }
    return [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(t.plugin.noUserInfo),
      ),
    ];
  }

  Widget _buildUserInfoCard() {
    return PluginUserInfoCard(
      from: widget.from,
      avatarUrl:
          asJsonMap(widget.state.userInfo['avatar'])['url']?.toString() ?? '',
      avatarPath:
          asJsonMap(widget.state.userInfo['avatar'])['path']?.toString() ?? '',
      lines: asJsonList(
        widget.state.userInfo['lines'],
      ).map((item) => item?.toString() ?? '').toList(),
    );
  }

  List<Widget> _buildSettingSections(BuildContext context) {
    return widget.state.sections.map((section) {
      final fields = asJsonList(
        section['fields'],
      ).map((item) => asJsonMap(item)).toList();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: PluginSettingsSectionCard(
          title: section['title']?.toString() ?? '',
          colorScheme: widget.colorScheme,
          children: _buildSectionChildren(context, fields),
        ),
      );
    }).toList();
  }

  /// 把 section 内的字段按类型分组渲染：
  /// - 连续的 text / password 字段合并进同一张 [GroupCard]；
  /// - 卡片底部追加按钮组，按登录态切换显示：
  ///   - 已登录：只显示「登出」；
  ///   - 未登录：只显示「登录」；
  /// - 其它类型（switch / select / multiChoice）保持原来的行组件。
  ///
  /// 按钮行为（全部由本 State 直接实现，不依赖子组件 State）：
  /// - **登录**：调 [PluginSettingsContent.onLogin]，由父页面跳转登录页；
  /// - **登出**：优先调用插件声明的 `clearPluginSession` action；
  ///   找不到该 action 时退化为「清空本地输入」。
  List<Widget> _buildSectionChildren(
    BuildContext context,
    List<Map<String, dynamic>> fields,
  ) {
    final result = <Widget>[];
    // 当前累积的 text / password 字段（含 label / key / kind）。
    final pendingFields = <Map<String, dynamic>>[];

    /// 把当前累积的文本字段连同按钮组收进一张卡片，然后清空暂存区。
    void flushTexts() {
      if (pendingFields.isEmpty) {
        return;
      }
      final snapshot = List<Map<String, dynamic>>.from(pendingFields);
      result.add(
        GroupCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < snapshot.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _buildInlineTextField(snapshot[i]),
                  ],
                  const SizedBox(height: 16),
                  // ─────────────────────────────
                  //  按钮组：按登录态切换
                  // ─────────────────────────────
                  // - 已登录：只保留「登出」——账号已写入，不需要再清除 / 提交；
                  // - 未登录：只显示「登录」——跳转登录页，回来后父页面 reload。
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        if (_isLoggedIn)
                          PluginSettingsActionButton(
                            label: '登出',
                            icon: Icons.logout,
                            variant: PluginSettingsActionButtonVariant.error,
                            onPressed: _logout,
                          )
                        else
                          PluginSettingsActionButton(
                            label: '登录',
                            icon: Icons.login,
                            variant: PluginSettingsActionButtonVariant.primary,
                            onPressed: () => widget.onLogin(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      pendingFields.clear();
    }

    for (final field in fields) {
      final kind = field['kind']?.toString() ?? 'text';
      if (kind == 'text' || kind == 'password') {
        pendingFields.add(field);
      } else {
        flushTexts();
        result.add(_buildField(context, field));
      }
    }
    flushTexts();
    return result;
  }

  /// 构造单个内联文本输入框。controller 由本 State 持有，
  /// 输入框只负责键盘交互与视觉。
  Widget _buildInlineTextField(Map<String, dynamic> field) {
    final key = field['key']?.toString() ?? '';
    final label = field['label']?.toString() ?? key;
    final kind = field['kind']?.toString() ?? 'text';
    return PluginSettingsInlineTextField(
      controller: _controllerFor(key),
      field: field,
      label: label,
      kind: kind,
      onCommit: widget.onCommitField,
    );
  }

  /// 「登出」按钮的实现：优先走插件声明的 `clearPluginSession` action；
  /// 找不到该 action 时退化为「清空本地输入」。
  ///
  /// 说明：`clearPluginSession` 在 `PluginSettingsPage._runAction` 里会
  /// 顺带导航到登录页，并在返回后 reload 设置页，因此插件侧只要声明了
  /// 这个 action，宿主就能给出完整的登出体验。
  Future<void> _logout() async {
    final clearAction = _findActionByFnPath('clearPluginSession');
    if (clearAction != null) {
      await widget.onRunAction(clearAction);
      return;
    }
    // 兜底：插件没有登出 action，就把账号相关字段清空。
    // 不再逐个字段提交空值 —— 账号通常由插件内部的 session 管理，
    // 强行写空可能引起副作用；清空本地即可。
    for (final c in _textControllers.values) {
      c.clear();
    }
    if (mounted) setState(() {});
  }

  Map<String, dynamic>? _findActionByFnPath(String fnPath) {
    for (final action in widget.state.actions) {
      if (action['fnPath']?.toString() == fnPath) {
        return action;
      }
    }
    return null;
  }

  Widget? _buildActionsSection(BuildContext context) {
    if (widget.state.actions.isEmpty) {
      return null;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: PluginSettingsSectionCard(
        title: t.plugin.operations,
        colorScheme: widget.colorScheme,
        children: widget.state.actions
            .map((action) => _buildAction(context, action))
            .toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  字段分发：非文本类型（text / password 已在内联卡片处理）
  // ─────────────────────────────────────────────
  Widget _buildField(BuildContext context, Map<String, dynamic> field) {
    final key = field['key']?.toString() ?? '';
    final kind = field['kind']?.toString() ?? 'text';
    final label = field['label']?.toString() ?? key;
    final value = widget.state.values[key];

    if (kind == 'switch') {
      return _buildSwitchField(field, label, value);
    }
    if (kind == 'select' || kind == 'choice') {
      return _buildSelectField(context, field, label, value);
    }
    if (kind == 'multiChoice') {
      return _buildMultiChoiceField(context, field, label, value);
    }
    return _buildTextFieldRow(context, field, label, value, kind);
  }

  Widget _buildSwitchField(
    Map<String, dynamic> field,
    String label,
    dynamic value,
  ) {
    final current = value == true;
    return PluginSettingsFieldRow(
      title: label,
      subtitle: current ? t.common.enabled : t.common.disabled,
      trailing: Switch(
        value: current,
        thumbIcon: kSettingSwitchThumbIcon,
        onChanged: (next) => widget.onCommitField(field, next),
      ),
      onTap: () => widget.onCommitField(field, !current),
    );
  }

  Widget _buildSelectField(
    BuildContext context,
    Map<String, dynamic> field,
    String label,
    dynamic value,
  ) {
    final options = _normalizeOptions(field['options']);
    final selectedLabel = options
        .firstWhere(
          (item) => item.value.toString() == value?.toString(),
          orElse: () => PluginSettingsOptionPair(
            label: value?.toString() ?? '',
            value: value,
          ),
        )
        .label;
    final items = <dynamic, String>{
      for (final option in options) option.value: option.label,
    };

    return PluginSettingsFieldRow(
      title: label,
      subtitle: '',
      trailing: FluentDropdown<dynamic>(
        value: value,
        displayValue: selectedLabel,
        items: items,
        onChanged: widget.deleted
            ? null
            : (picked) async {
                if (picked == null || picked.toString() == value?.toString()) {
                  return;
                }
                await widget.onCommitField(field, picked);
              },
      ),
      onTap: null,
    );
  }

  Widget _buildMultiChoiceField(
    BuildContext context,
    Map<String, dynamic> field,
    String label,
    dynamic value,
  ) {
    final options = _normalizeOptions(field['options']);
    final current = _asStringList(value);
    return PluginSettingsFieldRow(
      title: label,
      subtitle: current.isEmpty
          ? t.search.notSelected
          : t.search.selectedCount(count: current.length),
      trailing: const Icon(Icons.tune, size: 18),
      onTap: () async {
        final picked = await showMultiChoiceListDialog(
          context,
          title: label,
          options: options
              .map(
                (item) => MultiChoiceDialogOption(
                  label: item.label,
                  value: item.value.toString(),
                ),
              )
              .toList(),
          initialSelected: current,
          confirmText: t.common.save,
        );
        if (picked == null) return;
        await widget.onCommitField(field, picked.toList());
      },
    );
  }

  /// 未知类型 / 兜底文本行（点击弹对话框），一般不会被触发。
  Widget _buildTextFieldRow(
    BuildContext context,
    Map<String, dynamic> field,
    String label,
    dynamic value,
    String kind,
  ) {
    final text = value?.toString() ?? '';
    return PluginSettingsFieldRow(
      title: label,
      subtitle: _buildTextFieldDisplay(kind, text),
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: () async {
        final next = await _showInputDialog(
          context,
          title: label,
          initialValue: text,
          obscure: kind == 'password',
        );
        if (next == null) return;
        await widget.onCommitField(field, next);
      },
    );
  }

  String _buildTextFieldDisplay(String kind, String text) {
    if (kind == 'password' && text.isNotEmpty) {
      return '*' * text.length.clamp(6, 24);
    }
    return text;
  }

  Widget _buildAction(BuildContext context, Map<String, dynamic> action) {
    final title = action['title']?.toString() ?? t.plugin.unnamedAction;
    final fnPath = action['fnPath']?.toString() ?? '';
    return PluginSettingsFieldRow(
      title: title,
      subtitle: fnPath,
      trailing: const Icon(Icons.play_arrow, size: 18),
      onTap: fnPath.isEmpty ? null : () => widget.onRunAction(action),
    );
  }

  List<PluginSettingsOptionPair> _normalizeOptions(dynamic raw) {
    return asJsonList(raw).map((item) {
      if (item is Map) {
        final map = asJsonMap(item);
        return PluginSettingsOptionPair(
          label: map['label']?.toString() ?? map['value']?.toString() ?? '',
          value: map['value'],
        );
      }
      return PluginSettingsOptionPair(label: item.toString(), value: item);
    }).toList();
  }

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is Map) {
      return value.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  /// 弹出统一风格的输入对话框，内部使用 [MiuixTextField]。
  Future<String?> _showInputDialog(
    BuildContext context, {
    required String title,
    required String initialValue,
    required bool obscure,
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 320,
          child: Material(
            type: MaterialType.transparency,
            child: MiuixTextField(
              controller: controller,
              label: title,
              obscureText: obscure,
              leadingIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: MiuixIcon(
                  vector: MiuixIcons.extended.byName(
                    obscure ? 'lock' : 'edit',
                  )!,
                  size: 22,
                ),
              ),
              onChanged: (_) {},
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(t.common.save),
          ),
        ],
      ),
    );
  }
}
