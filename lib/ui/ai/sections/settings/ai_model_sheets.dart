import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/services/ai/ai_models.dart';
import '../../../../core/services/ai/ai_provider_config.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../settings/widgets/settings_option_tiles.dart';
import '../../../widgets/app_modal/app_dialog.dart';
import '../../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../widgets/ai_tap_outside_unfocus.dart';

/// 从拉取到的模型列表里勾选要用的模型（只负责挑选）。已添加的模型不再列出。
Future<List<AiModelConfig>?> showAiModelPickerSheet(
  BuildContext context, {
  required List<AiRemoteModel> remote,
  required Set<String> existing,
}) {
  return showAppModalBottomSheet<List<AiModelConfig>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (BuildContext sheetContext) => _ModelPicker(
      remote: [
        for (final model in remote)
          if (!existing.contains(model.id)) model,
      ],
    ),
  );
}

class _ModelPicker extends StatefulWidget {
  const _ModelPicker({required this.remote});

  final List<AiRemoteModel> remote;

  @override
  State<_ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends State<_ModelPicker> {
  final Set<String> _selected = <String>{};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final visible = [
      for (final model in widget.remote)
        if (query.isEmpty ||
            model.id.toLowerCase().contains(query) ||
            (model.displayName?.toLowerCase().contains(query) ?? false))
          model,
    ];
    final height = MediaQuery.sizeOf(context).height * 0.8;
    return AiTapOutsideUnfocus(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(
                  l10n.aiModelPickerTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: l10n.aiModelPickerSearch,
                    prefixIcon: const SizedBox(
                      width: 44,
                      child: Center(
                        child: FaIcon(
                          FontAwesomeIcons.magnifyingGlass,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                  onChanged: (String value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: widget.remote.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            l10n.aiModelPickerEmpty,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (BuildContext context, int index) {
                          final model = visible[index];
                          final name = model.displayName;
                          return CheckboxListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                            ),
                            value: _selected.contains(model.id),
                            title: Text(model.id),
                            subtitle: name == null || name == model.id
                                ? null
                                : Text(name),
                            onChanged: (bool? value) => setState(() {
                              value == true
                                  ? _selected.add(model.id)
                                  : _selected.remove(model.id);
                            }),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop([
                          for (final model in widget.remote)
                            if (_selected.contains(model.id))
                              AiModelConfig(
                                id: model.id,
                                name: model.displayName == model.id
                                    ? null
                                    : model.displayName,
                                vision: model.supportsVision,
                                contextWindow: model.contextWindow,
                              ),
                        ]),
                  child: Text(l10n.aiModelPickerAdd(_selected.length)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 手动输入一个模型名。
Future<String?> showAiAddModelDialog(BuildContext context) {
  final controller = TextEditingController();
  return showAppDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) {
      final l10n = dialogContext.l10n;
      final colors = Theme.of(dialogContext).colorScheme;
      void submit() {
        final value = controller.text.trim();
        if (value.isNotEmpty) Navigator.of(dialogContext).pop(value);
      }

      return AlertDialog(
        title: Text(l10n.aiProviderAddModel),
        content: TextField(
          controller: controller,
          autofocus: true,
          autocorrect: false,
          decoration: InputDecoration(hintText: l10n.aiProviderModelIdHint),
          onSubmitted: (_) => submit(),
        ),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurfaceVariant,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(onPressed: submit, child: Text(l10n.commonConfirm)),
        ],
      );
    },
  ).whenComplete(controller.dispose);
}

/// 模型设置面板的结果：改过的模型，或移除。
sealed class AiModelSheetResult {
  const AiModelSheetResult();
}

class AiModelSheetUpdated extends AiModelSheetResult {
  const AiModelSheetUpdated(this.model);

  final AiModelConfig model;
}

class AiModelSheetRemoved extends AiModelSheetResult {
  const AiModelSheetRemoved();
}

/// 一个模型的设置：显示名、看图、思考过程、最多输出与上下文长度。
Future<AiModelSheetResult?> showAiModelSettingsSheet(
  BuildContext context,
  AiModelConfig model,
) {
  return showAppModalBottomSheet<AiModelSheetResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (BuildContext sheetContext) => _ModelSettings(model: model),
  );
}

class _ModelSettings extends StatefulWidget {
  const _ModelSettings({required this.model});

  final AiModelConfig model;

  @override
  State<_ModelSettings> createState() => _ModelSettingsState();
}

class _ModelSettingsState extends State<_ModelSettings> {
  late final TextEditingController _name = TextEditingController(
    text: widget.model.name ?? '',
  );
  late final TextEditingController _maxOutput = TextEditingController(
    text: widget.model.maxOutputTokens?.toString() ?? '',
  );
  late final TextEditingController _context = TextEditingController(
    text: widget.model.contextWindow?.toString() ?? '',
  );
  late bool _vision = widget.model.supportsVision;
  late bool _reasoning = widget.model.reasoning;

  @override
  void dispose() {
    _name.dispose();
    _maxOutput.dispose();
    _context.dispose();
    super.dispose();
  }

  AiModelConfig _result() {
    int? number(TextEditingController controller) {
      final value = int.tryParse(controller.text.trim());
      return value != null && value > 0 ? value : null;
    }

    final name = _name.text.trim();
    return widget.model.copyWith(
      name: name.isEmpty ? null : name,
      // 默认就是支持图片：打开时不写死（null），只记关掉的。
      vision: _vision ? null : false,
      maxOutputTokens: number(_maxOutput),
      contextWindow: number(_context),
      reasoning: _reasoning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final digits = <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly];
    return AiTapOutsideUnfocus(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                child: Text(
                  l10n.aiModelEditTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: SelectableText(
                  widget.model.id,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: l10n.aiModelDisplayName,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SettingsSwitchTile(
                title: l10n.aiModelVisionToggle,
                value: _vision,
                onChanged: (bool value) => setState(() => _vision = value),
              ),
              SettingsSwitchTile(
                title: l10n.aiModelReasoningToggle,
                subtitle: l10n.aiModelReasoningSubtitle,
                value: _reasoning,
                onChanged: (bool value) => setState(() => _reasoning = value),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _maxOutput,
                        keyboardType: TextInputType.number,
                        inputFormatters: digits,
                        decoration: InputDecoration(
                          labelText: l10n.aiModelMaxOutput,
                          hintText: l10n.aiModelAuto,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _context,
                        keyboardType: TextInputType.number,
                        inputFormatters: digits,
                        decoration: InputDecoration(
                          labelText: l10n.aiModelContext,
                          hintText: l10n.aiModelAuto,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: <Widget>[
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: colors.error,
                      ),
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(const AiModelSheetRemoved()),
                      child: Text(l10n.aiModelRemove),
                    ),
                    const Spacer(),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: colors.onSurfaceVariant,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.commonCancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(AiModelSheetUpdated(_result())),
                      child: Text(l10n.commonSave),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
