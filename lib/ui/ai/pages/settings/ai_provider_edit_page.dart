// AI 服务商编辑页（新建或编辑）。
//
// 输入：新建时的预设（地址、协议、推荐模型），或已有的服务商配置。
// 输出 / 副作用：点“保存”后经 `AiProviderStore.saveProvider` 写入本机
// （不进备份、不同步）；删除经 `removeProvider`，并一并去掉指向它的路由。
// 拉取模型与测试连接用表单里**当前**填的内容（还没保存也能试），由
// `AiProviderEditController` 持有取消令牌，离开页面即取消。
// 有未保存的修改时返回先确认。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../core/services/ai/ai_models.dart';
import '../../../../core/services/ai/ai_provider_config.dart';
import '../../../../core/services/ai/ai_provider_presets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../../settings/widgets/cloud_backup_config_field.dart';
import '../../../settings/widgets/external_link.dart';
import '../../../settings/widgets/settings_card_group.dart';
import '../../../settings/widgets/settings_option_tiles.dart';
import '../../../settings/widgets/settings_reveal.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../../controllers/ai_provider_edit_controller.dart';
import '../../providers/ai_providers.dart';
import '../../sections/settings/ai_model_sheets.dart';
import '../../viewmodels/ai_labels.dart';
import '../../widgets/ai_dialogs.dart';
import '../../widgets/ai_error_view.dart';
import '../../widgets/ai_page_scaffold.dart';

class AiProviderEditPage extends ConsumerStatefulWidget {
  const AiProviderEditPage.create(AiProviderPreset this.preset, {super.key})
    : provider = null;

  const AiProviderEditPage.edit(AiProviderConfig this.provider, {super.key})
    : preset = null;

  /// 新建时选的预设；编辑时为 null，由服务商的 presetId 找回（见 `_preset`）。
  final AiProviderPreset? preset;
  final AiProviderConfig? provider;

  @override
  ConsumerState<AiProviderEditPage> createState() => _AiProviderEditPageState();
}

class _AiProviderEditPageState extends ConsumerState<AiProviderEditPage> {
  late final AiProviderEditController _controller;
  late final AiProviderPreset? _preset =
      widget.preset ?? aiProviderPresetById(widget.provider?.presetId);
  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  late final TextEditingController _proxy;
  late final TextEditingController _headers;
  late final TextEditingController _extraBody;
  bool _advanced = false;
  AiProviderFormError? _formError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.provider;
    final initial =
        existing ?? _preset!.create(id: newAiProviderId(), name: '');
    _controller = AiProviderEditController(
      initial: initial,
      isNew: existing == null,
      preset: _preset,
    )..addListener(_onChanged);
    _name = TextEditingController(text: initial.name);
    _baseUrl = TextEditingController(text: initial.baseUrl);
    _apiKey = TextEditingController(text: initial.apiKey);
    _proxy = TextEditingController(text: initial.proxy ?? '');
    _headers = TextEditingController(text: formatAiHeaders(initial.headers));
    _extraBody = TextEditingController(text: initial.extraBody ?? '');
    _advanced =
        (initial.proxy?.isNotEmpty ?? false) ||
        initial.headers.isNotEmpty ||
        (initial.extraBody?.isNotEmpty ?? false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 新建时以本地化的预设名作为默认名称（只在第一次、名称为空时）。
    final preset = _preset;
    if (_controller.isNew && _name.text.isEmpty && preset != null) {
      _name.text = aiPresetLabel(context.l10n, preset);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    for (final controller in [
      _name,
      _baseUrl,
      _apiKey,
      _proxy,
      _headers,
      _extraBody,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  AiProviderFormText get _text => AiProviderFormText(
    name: _name.text,
    baseUrl: _baseUrl.text,
    apiKey: _apiKey.text,
    proxy: _proxy.text,
    headers: _headers.text,
    extraBody: _extraBody.text,
  );

  AiProviderConfig get _config => _controller.build(_text);

  bool get _dirty {
    if (_controller.isNew) return true;
    return _config != widget.provider;
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty || _saving) return true;
    final l10n = context.l10n;
    return confirmAiAction(
      context,
      title: l10n.aiProviderDiscardTitle,
      action: l10n.aiProviderDiscard,
      destructive: true,
    );
  }

  bool _validate() {
    final error = AiProviderEditController.validate(_text);
    setState(() => _formError = error);
    return error == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    final store = await ref.read(aiProviderStoreProvider.future);
    await _controller.save(store, _config);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final provider = widget.provider;
    if (provider == null) return;
    final confirmed = await confirmAiAction(
      context,
      title: l10n.aiProviderDeleteTitle(provider.name),
      content: l10n.aiProviderDeleteBody,
      action: l10n.commonDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    final store = await ref.read(aiProviderStoreProvider.future);
    await store.removeProvider(provider.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _fetchModels() async {
    if (AiProviderEditController.validate(_text) ==
        AiProviderFormError.baseUrl) {
      setState(() => _formError = AiProviderFormError.baseUrl);
      return;
    }
    final service = await ref.read(aiServiceProvider.future);
    final remote = await _controller.fetchModels(service, _config);
    if (remote == null || !mounted) return;
    final picked = await showAiModelPickerSheet(
      context,
      remote: remote,
      existing: {for (final model in _controller.models) model.id},
    );
    if (picked != null) _controller.addModels(picked);
  }

  Future<void> _addModel() async {
    final id = await showAiAddModelDialog(context);
    if (id != null) _controller.addModels([AiModelConfig(id: id)]);
  }

  Future<void> _editModel(AiModelConfig model) async {
    final result = await showAiModelSettingsSheet(context, model);
    switch (result) {
      case AiModelSheetUpdated(:final model):
        _controller.replaceModel(model.id, model);
      case AiModelSheetRemoved():
        _controller.removeModel(model.id);
      case null:
        break;
    }
  }

  Future<void> _test() async {
    if (!_validate()) return;
    final l10n = context.l10n;
    if (_controller.models.isEmpty) {
      setState(() {});
      await confirmAiAction(
        context,
        title: l10n.aiProviderNeedModel,
        action: l10n.commonConfirm,
      );
      return;
    }
    final service = await ref.read(aiServiceProvider.future);
    await _controller.test(service, _config, l10n.aiStatusTestOk);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final controller = _controller;
    final preset = _preset;
    final local = preset?.group == AiPresetGroup.local;
    final keyUrl = preset?.keyUrl;
    final tonal = AppGlassField.tonalButtonStyle(context);

    String? fieldError(AiProviderFormError field) =>
        _formError == field ? _formErrorText(l10n, field) : null;

    return AiPageScaffold(
      title: controller.isNew
          ? l10n.aiProviderEditTitleNew
          : l10n.aiProviderEditTitle,
      onWillPopGuard: _confirmLeave,
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.commonSave),
        ),
        const SizedBox(width: 8),
      ],
      children: <Widget>[
        SettingsCardGroup(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  CloudBackupConfigField(
                    controller: _name,
                    icon: FontAwesomeIcons.tag,
                    labelText: l10n.aiProviderName,
                  ),
                  if (fieldError(AiProviderFormError.name) case final text?)
                    _FieldError(text),
                  const SizedBox(height: 12),
                  CloudBackupConfigField(
                    controller: _baseUrl,
                    icon: FontAwesomeIcons.link,
                    labelText: l10n.aiProviderBaseUrl,
                    hintText: l10n.aiProviderBaseUrlHint,
                    keyboardType: TextInputType.url,
                  ),
                  if (fieldError(AiProviderFormError.baseUrl) case final text?)
                    _FieldError(text),
                  const SizedBox(height: 12),
                  CloudBackupConfigField(
                    controller: _apiKey,
                    icon: FontAwesomeIcons.key,
                    labelText: local || preset?.needsKey == false
                        ? l10n.aiProviderApiKeyOptional
                        : l10n.aiProviderApiKey,
                    secret: true,
                  ),
                  if (keyUrl != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () => openExternalLink(context, keyUrl),
                        icon: const FaIcon(
                          FontAwesomeIcons.arrowUpRightFromSquare,
                          size: 12,
                        ),
                        label: Text(l10n.aiProviderGetKey),
                      ),
                    ),
                  if (local)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l10n.aiProviderLocalHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SettingsChoiceTile(
              title: l10n.aiProviderProtocol,
              child: ExpressiveButtonGroup<AiProtocol>(
                minSegmentWidth: 112,
                segments: [
                  for (final protocol in AiProtocol.values)
                    ButtonSegment<AiProtocol>(
                      value: protocol,
                      label: Text(aiProtocolLabel(l10n, protocol)),
                    ),
                ],
                selected: {controller.protocol},
                onSelectionChanged: (Set<AiProtocol> value) =>
                    controller.setProtocol(value.single),
              ),
            ),
            SettingsSwitchTile(
              title: l10n.aiProviderEnabled,
              value: controller.enabled,
              onChanged: controller.setEnabled,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCardGroup(
          title: l10n.aiProviderModels,
          children: <Widget>[
            if (controller.models.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l10n.aiProviderModelsEmpty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            for (final model in controller.models)
              ListTile(
                key: ValueKey<String>(model.id),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                titleAlignment: ListTileTitleAlignment.center,
                title: Text(
                  model.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: model.name == null
                    ? null
                    : Text(
                        model.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (model.supportsVision) AiBadge(l10n.aiModelVision),
                    if (model.reasoning) ...<Widget>[
                      const SizedBox(width: 6),
                      AiBadge(l10n.aiModelReasoning),
                    ],
                    const SizedBox(width: 8),
                    FaIcon(
                      FontAwesomeIcons.sliders,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
                onTap: () => _editModel(model),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.tonalIcon(
                    style: tonal,
                    onPressed: controller.fetching ? null : _fetchModels,
                    icon: const FaIcon(
                      FontAwesomeIcons.cloudArrowDown,
                      size: 14,
                    ),
                    label: Text(
                      controller.fetching
                          ? l10n.commonLoading
                          : l10n.aiProviderFetchModels,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addModel,
                    icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
                    label: Text(l10n.aiProviderAddModel),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCardGroup(
          children: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: Text(l10n.aiProviderAdvanced),
                  trailing: AnimatedRotation(
                    turns: _advanced ? 0.5 : 0,
                    duration: ExpressiveMotion.duration(
                      context,
                      ExpressiveMotion.medium,
                    ),
                    curve: ExpressiveMotion.spatial,
                    child: const FaIcon(FontAwesomeIcons.angleDown, size: 14),
                  ),
                  onTap: () => setState(() => _advanced = !_advanced),
                ),
                SettingsReveal(
                  visible: _advanced,
                  child: _AdvancedSection(
                    controller: controller,
                    proxy: _proxy,
                    headers: _headers,
                    extraBody: _extraBody,
                    extraBodyError: fieldError(AiProviderFormError.extraBody),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FilledButton.tonalIcon(
                style: tonal,
                onPressed: controller.testing ? null : _test,
                icon: const FaIcon(FontAwesomeIcons.plugCircleCheck, size: 14),
                label: Text(
                  controller.testing ? l10n.aiStatusTesting : l10n.aiStatusTest,
                ),
              ),
              if (controller.testResult case final result?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    result,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (controller.lastError case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: AiErrorView(error: error, showSettings: false),
                ),
              if (!controller.isNew) ...<Widget>[
                const SizedBox(height: 24),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: colors.error),
                  onPressed: _saving ? null : _delete,
                  icon: const FaIcon(FontAwesomeIcons.trashCan, size: 14),
                  label: Text(l10n.aiProviderDelete),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _formErrorText(AppLocalizations l10n, AiProviderFormError e) =>
      switch (e) {
        AiProviderFormError.name => l10n.aiProviderNameRequired,
        AiProviderFormError.baseUrl => l10n.aiProviderUrlInvalid,
        AiProviderFormError.extraBody => l10n.aiProviderExtraBodyInvalid,
      };
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 12),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}

class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection({
    required this.controller,
    required this.proxy,
    required this.headers,
    required this.extraBody,
    required this.extraBodyError,
  });

  final AiProviderEditController controller;
  final TextEditingController proxy;
  final TextEditingController headers;
  final TextEditingController extraBody;
  final String? extraBodyError;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final monospace = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
    );
    final timeoutIndex = AiProviderEditController.timeoutChoices.indexOf(
      controller.firstByteTimeoutSeconds,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              CloudBackupConfigField(
                controller: proxy,
                icon: FontAwesomeIcons.route,
                labelText: l10n.aiProviderProxy,
                hintText: l10n.aiProviderProxyHint,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: headers,
                minLines: 2,
                maxLines: 5,
                autocorrect: false,
                style: monospace,
                decoration: InputDecoration(
                  labelText: l10n.aiProviderHeaders,
                  hintText: l10n.aiProviderHeadersHint,
                  alignLabelWithHint: true,
                ),
                contextMenuBuilder: appTextContextMenuBuilder,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: extraBody,
                minLines: 2,
                maxLines: 6,
                autocorrect: false,
                style: monospace,
                decoration: InputDecoration(
                  labelText: l10n.aiProviderExtraBody,
                  helperText: l10n.aiProviderExtraBodyHint,
                  helperMaxLines: 2,
                  errorText: extraBodyError,
                  alignLabelWithHint: true,
                ),
                contextMenuBuilder: appTextContextMenuBuilder,
              ),
            ],
          ),
        ),
        SettingsSwitchTile(
          title: l10n.aiProviderStream,
          subtitle: l10n.aiProviderStreamSubtitle,
          value: controller.stream,
          onChanged: controller.setStream,
        ),
        if (controller.protocol == AiProtocol.openAi)
          SettingsSwitchTile(
            title: l10n.aiProviderIncludeUsage,
            subtitle: l10n.aiProviderIncludeUsageSubtitle,
            value: controller.includeUsage,
            onChanged: controller.setIncludeUsage,
          ),
        SettingsSwitchTile(
          title: l10n.aiProviderSendTemperature,
          subtitle: l10n.aiProviderSendTemperatureSubtitle,
          value: controller.sendTemperature,
          onChanged: controller.setSendTemperature,
        ),
        SettingsSliderTile(
          title: l10n.aiProviderTimeout,
          value: (timeoutIndex < 0 ? 2 : timeoutIndex).toDouble(),
          min: 0,
          max: (AiProviderEditController.timeoutChoices.length - 1).toDouble(),
          divisions: AiProviderEditController.timeoutChoices.length - 1,
          valueLabel: (double value) => l10n.aiSeconds(
            AiProviderEditController.timeoutChoices[value.round()],
          ),
          onChanged: (double value) => controller.setTimeout(
            AiProviderEditController.timeoutChoices[value.round()],
          ),
          onChangeEnd: null,
        ),
        SettingsSliderTile(
          title: l10n.aiProviderRetries,
          value: controller.retries.toDouble(),
          min: 0,
          max: AiProviderConfig.maxRetries.toDouble(),
          divisions: AiProviderConfig.maxRetries,
          valueLabel: (double value) => l10n.aiTimes(value.round()),
          onChanged: (double value) => controller.setRetries(value.round()),
          onChangeEnd: null,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
