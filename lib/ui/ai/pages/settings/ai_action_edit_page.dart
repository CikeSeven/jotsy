// 写作指令编辑页。
//
// - 内置指令：名称与图标固定，只能改写提示词；与默认相同时不存（删除
//   改写），“恢复默认”把输入框填回默认提示词；
// - 自建指令（[actionId] 为 null 时新建）：名称、图标、提示词与结果用法。
// 提示词里可插入变量（`AiPromptVariable`），插在光标处。保存才写入；有改动
// 时返回先确认。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../settings/widgets/settings_card_group.dart';
import '../../../settings/widgets/settings_option_tiles.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../../models/ai_built_ins.dart';
import '../../models/ai_ids.dart';
import '../../models/ai_preference_parts.dart';
import '../../models/ai_preferences.dart';
import '../../models/ai_prompt_variables.dart';
import '../../providers/ai_providers.dart';
import '../../viewmodels/ai_labels.dart';
import '../../widgets/ai_dialogs.dart';
import '../../widgets/ai_page_scaffold.dart';

class AiActionEditPage extends ConsumerStatefulWidget {
  const AiActionEditPage({super.key, this.actionId});

  /// 要编辑的指令 id；null 为新建自建指令。
  final String? actionId;

  @override
  ConsumerState<AiActionEditPage> createState() => _AiActionEditPageState();
}

class _AiActionEditPageState extends ConsumerState<AiActionEditPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _emoji = TextEditingController(text: '✨');
  final TextEditingController _prompt = TextEditingController();
  AiActionOutput _output = AiActionOutput.replace;
  AiWritingAction? _builtIn;
  String _initial = '';
  bool _ready = false;
  bool _saved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final l10n = context.l10n;
    final prefs = ref.read(aiPreferencesProvider);
    final id = widget.actionId;
    if (id != null) {
      _builtIn = AiWritingAction.fromId(id);
      final builtIn = _builtIn;
      if (builtIn != null) {
        _name.text = builtIn.label(l10n);
        _emoji.text = builtIn.emoji;
        _prompt.text = prefs.actionPrompts[id] ?? builtIn.defaultPrompt(l10n);
        _output = builtIn.output;
      } else if (prefs.customAction(id) case final custom?) {
        _name.text = custom.name;
        _emoji.text = custom.emoji;
        _prompt.text = custom.prompt;
        _output = custom.output;
      }
    }
    _initial = _snapshot;
  }

  @override
  void dispose() {
    _name.dispose();
    _emoji.dispose();
    _prompt.dispose();
    super.dispose();
  }

  String get _snapshot =>
      '${_name.text}\u0000${_emoji.text}\u0000${_prompt.text}\u0000${_output.name}';

  bool get _canSave =>
      _prompt.text.trim().isNotEmpty &&
      (_builtIn != null || _name.text.trim().isNotEmpty);

  Future<bool> _confirmLeave() async {
    if (_saved || _snapshot == _initial) return true;
    final l10n = context.l10n;
    return confirmAiAction(
      context,
      title: l10n.aiProviderDiscardTitle,
      action: l10n.aiProviderDiscard,
      destructive: true,
    );
  }

  void _insertVariable(AiPromptVariable variable) {
    final token = variable.token(zh: context.l10n.isZh);
    final value = _prompt.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final text = value.text.replaceRange(selection.start, selection.end, token);
    _prompt.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: selection.start + token.length,
      ),
    );
    setState(() {});
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final l10n = context.l10n;
    final prompt = _prompt.text.trim();
    final builtIn = _builtIn;
    if (builtIn != null) {
      final isDefault = prompt == builtIn.defaultPrompt(l10n).trim();
      await updateAiPreferences(ref, (AiPreferences p) {
        final prompts = {...p.actionPrompts};
        isDefault ? prompts.remove(builtIn.id) : prompts[builtIn.id] = prompt;
        return p.copyWith(actionPrompts: prompts);
      });
    } else {
      final emoji = _emoji.text.trim();
      final action = AiCustomAction(
        id: widget.actionId ?? newAiLocalId('action'),
        name: _name.text.trim(),
        emoji: emoji.isEmpty ? '✨' : emoji,
        prompt: prompt,
        output: _output,
      );
      await updateAiPreferences(ref, (AiPreferences p) {
        final next = [...p.customActions];
        final index = next.indexWhere((item) => item.id == action.id);
        if (index < 0) {
          if (next.length >= AiPreferences.maxCustomActions) return p;
          next.add(action);
        } else {
          next[index] = action;
        }
        return p.copyWith(customActions: next);
      });
    }
    _saved = true;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final builtIn = _builtIn;
    final editable = builtIn == null;
    return AiPageScaffold(
      title: widget.actionId == null
          ? l10n.aiActionEditTitleNew
          : l10n.aiActionEditTitle,
      onWillPopGuard: _confirmLeave,
      actions: <Widget>[
        TextButton(
          onPressed: _canSave ? _save : null,
          child: Text(l10n.commonSave),
        ),
        const SizedBox(width: 8),
      ],
      children: <Widget>[
        SettingsCardGroup(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      SizedBox(
                        width: 88,
                        child: TextField(
                          controller: _emoji,
                          enabled: editable,
                          textAlign: TextAlign.center,
                          maxLength: 8,
                          decoration: InputDecoration(
                            labelText: l10n.aiActionEmoji,
                            counterText: '',
                          ),
                          contextMenuBuilder: appTextContextMenuBuilder,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _name,
                          enabled: editable,
                          maxLength: AiCustomAction.maxNameLength,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: l10n.aiActionName,
                            counterText: '',
                          ),
                          contextMenuBuilder: appTextContextMenuBuilder,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _prompt,
                    minLines: 5,
                    maxLines: 14,
                    maxLength: AiCustomAction.maxPromptLength,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l10n.aiActionPrompt,
                      hintText: l10n.aiActionPromptHint,
                      alignLabelWithHint: true,
                    ),
                    contextMenuBuilder: appTextContextMenuBuilder,
                  ),
                  if (builtIn != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () => setState(
                          () => _prompt.text = builtIn.defaultPrompt(l10n),
                        ),
                        icon: const FaIcon(
                          FontAwesomeIcons.arrowRotateLeft,
                          size: 12,
                        ),
                        label: Text(l10n.aiCommonRestoreDefault),
                      ),
                    ),
                  if (editable) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      l10n.aiActionVariables,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final variable in AiPromptVariable.values)
                          ActionChip(
                            label: Text(variable.label(l10n)),
                            onPressed: () => _insertVariable(variable),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.aiActionVariablesHelp,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (editable)
              SettingsChoiceTile(
                title: l10n.aiActionOutput,
                child: ExpressiveButtonGroup<AiActionOutput>(
                  minSegmentWidth: 88,
                  segments: <ButtonSegment<AiActionOutput>>[
                    for (final output in AiActionOutput.values)
                      ButtonSegment(
                        value: output,
                        label: Text(aiOutputLabel(l10n, output)),
                      ),
                  ],
                  selected: {_output},
                  onSelectionChanged: (Set<AiActionOutput> value) =>
                      setState(() => _output = value.single),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
