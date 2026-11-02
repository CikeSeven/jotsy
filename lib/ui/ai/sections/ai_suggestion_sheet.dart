import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../viewmodels/ai_json_output.dart';

/// 用户在建议面板里勾选要应用的部分。
class AiSuggestionChoice {
  const AiSuggestionChoice({
    this.title,
    this.tags = const <String>[],
    this.newTags = const <String>[],
    this.mood,
  });

  final String? title;
  final List<String> tags;
  final List<String> newTags;
  final String? mood;

  bool get isEmpty =>
      title == null && tags.isEmpty && newTags.isEmpty && mood == null;
}

/// 智能填写的建议面板（只负责挑选）：标题、已有标签、新标签与心情各自可
/// 取消；已经选上的标签不再列出。点“应用”返回选择，关掉为 null。
Future<AiSuggestionChoice?> showAiSuggestionSheet(
  BuildContext context, {
  required AiSuggestion suggestion,
  required Set<String> selectedTags,
  bool includeTitle = true,
}) {
  return showAppModalBottomSheet<AiSuggestionChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (BuildContext sheetContext) => _SuggestionSheet(
      suggestion: suggestion,
      selectedTags: selectedTags,
      includeTitle: includeTitle,
    ),
  );
}

class _SuggestionSheet extends StatefulWidget {
  const _SuggestionSheet({
    required this.suggestion,
    required this.selectedTags,
    required this.includeTitle,
  });

  final AiSuggestion suggestion;
  final Set<String> selectedTags;
  final bool includeTitle;

  @override
  State<_SuggestionSheet> createState() => _SuggestionSheetState();
}

class _SuggestionSheetState extends State<_SuggestionSheet> {
  late bool _title = widget.includeTitle && widget.suggestion.title != null;
  late final Set<String> _tags = {
    for (final tag in widget.suggestion.tags)
      if (!widget.selectedTags.contains(tag)) tag,
  };
  final Set<String> _newTags = <String>{};
  late bool _mood = widget.suggestion.mood != null;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final suggestion = widget.suggestion;
    final tags = [
      for (final tag in suggestion.tags)
        if (!widget.selectedTags.contains(tag)) tag,
    ];
    final label = theme.textTheme.labelLarge?.copyWith(
      color: colors.primary,
      fontWeight: FontWeight.w700,
    );
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                FaIcon(
                  FontAwesomeIcons.wandMagicSparkles,
                  size: 16,
                  color: colors.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.aiSuggestTagsHeader,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (widget.includeTitle && suggestion.title != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(l10n.aiPromptFieldTitle, style: label),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _title,
                title: Text(suggestion.title!),
                onChanged: (bool? value) =>
                    setState(() => _title = value ?? false),
              ),
            ],
            if (tags.isNotEmpty || suggestion.newTags.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(l10n.aiPromptFieldTags, style: label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final tag in tags)
                    FilterChip(
                      label: Text('#$tag'),
                      selected: _tags.contains(tag),
                      onSelected: (bool selected) => setState(
                        () => selected ? _tags.add(tag) : _tags.remove(tag),
                      ),
                    ),
                  for (final tag in suggestion.newTags)
                    FilterChip(
                      avatar: const FaIcon(FontAwesomeIcons.plus, size: 12),
                      label: Text(l10n.aiSuggestNewTag(tag)),
                      selected: _newTags.contains(tag),
                      onSelected: (bool selected) => setState(
                        () =>
                            selected ? _newTags.add(tag) : _newTags.remove(tag),
                      ),
                    ),
                ],
              ),
            ],
            if (suggestion.mood != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(l10n.aiPromptFieldMood, style: label),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _mood,
                title: Text(
                  suggestion.mood!,
                  style: const TextStyle(fontSize: 22),
                ),
                onChanged: (bool? value) =>
                    setState(() => _mood = value ?? false),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colors.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    AiSuggestionChoice(
                      title: _title ? suggestion.title : null,
                      tags: [
                        for (final tag in tags)
                          if (_tags.contains(tag)) tag,
                      ],
                      newTags: [
                        for (final tag in suggestion.newTags)
                          if (_newTags.contains(tag)) tag,
                      ],
                      mood: _mood ? suggestion.mood : null,
                    ),
                  ),
                  child: Text(l10n.commonConfirm),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
