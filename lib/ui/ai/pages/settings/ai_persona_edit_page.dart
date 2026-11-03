import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../settings/widgets/settings_card_group.dart';
import '../../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../../models/ai_built_ins.dart';
import '../../models/ai_ids.dart';
import '../../models/ai_preference_parts.dart';
import '../../models/ai_preferences.dart';
import '../../providers/ai_providers.dart';
import '../../widgets/ai_dialogs.dart';
import '../../widgets/ai_page_scaffold.dart';

/// 新建 / 编辑一个“我的人设”。[copyOf] 给出时以内置人设为底新建一份。
/// 保存才写入；有改动时返回先确认。
class AiPersonaEditPage extends ConsumerStatefulWidget {
  const AiPersonaEditPage({super.key, this.persona, this.copyOf});

  final AiPersona? persona;
  final AiPersonaInfo? copyOf;

  @override
  ConsumerState<AiPersonaEditPage> createState() => _AiPersonaEditPageState();
}

class _AiPersonaEditPageState extends ConsumerState<AiPersonaEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _emoji;
  late final TextEditingController _prompt;
  late final String _initial;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final persona = widget.persona;
    final copy = widget.copyOf;
    _name = TextEditingController(text: persona?.name ?? '');
    _emoji = TextEditingController(text: persona?.emoji ?? copy?.emoji ?? '🙂');
    _prompt = TextEditingController(
      text: persona?.prompt ?? copy?.prompt ?? '',
    );
    _initial = _snapshot;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final copy = widget.copyOf;
    if (copy != null && _name.text.isEmpty) {
      _name.text = context.l10n.aiPersonaCopySuffix(copy.name);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _emoji.dispose();
    _prompt.dispose();
    super.dispose();
  }

  String get _snapshot =>
      '${_name.text}\u0000${_emoji.text}\u0000${_prompt.text}';

  bool get _canSave =>
      _name.text.trim().isNotEmpty && _prompt.text.trim().isNotEmpty;

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

  Future<void> _save() async {
    if (!_canSave) return;
    final emoji = _emoji.text.trim();
    final persona = AiPersona(
      id: widget.persona?.id ?? newAiLocalId('persona'),
      name: _name.text.trim(),
      emoji: emoji.isEmpty ? '🙂' : emoji,
      prompt: _prompt.text.trim(),
    );
    await updateAiPreferences(ref, (AiPreferences p) {
      final index = p.personas.indexWhere((item) => item.id == persona.id);
      final next = [...p.personas];
      if (index < 0) {
        if (next.length >= AiPreferences.maxPersonas) return p;
        next.add(persona);
      } else {
        next[index] = persona;
      }
      return p.copyWith(personas: next);
    });
    _saved = true;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AiPageScaffold(
      title: widget.persona == null
          ? l10n.aiPersonaEditTitleNew
          : l10n.aiPersonaEditTitle,
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
                          textAlign: TextAlign.center,
                          maxLength: 8,
                          decoration: InputDecoration(
                            labelText: l10n.aiPersonaEmoji,
                            counterText: '',
                          ),
                          contextMenuBuilder: appTextContextMenuBuilder,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _name,
                          maxLength: AiPersona.maxNameLength,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: l10n.aiPersonaName,
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
                    minLines: 6,
                    maxLines: 16,
                    maxLength: AiPersona.maxPromptLength,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l10n.aiPersonaPrompt,
                      hintText: l10n.aiPersonaPromptHint,
                      alignLabelWithHint: true,
                    ),
                    contextMenuBuilder: appTextContextMenuBuilder,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
