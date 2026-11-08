// “模型与思考”面板（输入栏的模型胶囊打开，DESIGN §5.29）：
//
// - 上段“思考强度”：五段 `ExpressiveButtonGroup`（自动 / 关 / 低 / 中 /
//   高），下面一行灰字解释所选的一档；所选模型在设置里关了“请求思考”时
//   整组禁用并说明原因。点一档立即生效（面板不关，接着可以换模型）。
// - 下段“模型”：首行“跟随默认（某模型）”，其余为可用模型（模型名 + 服务
//   商），当前的行尾打勾；点一行立即生效并关闭面板。
//
// 改动经 [onChanged] 交给对话页（写进这段对话；还没有对话时第一次发送时
// 一并写入）。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/services/ai/ai_models.dart';
import '../../../../core/services/ai/ai_provider_config.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../models/ai_conversation_options.dart';
import '../../viewmodels/ai_labels.dart';

/// 面板里思考强度的一档（自动没有对应的 [AiThinkingLevel]）。
enum _Level { auto, off, low, medium, high }

_Level _levelOf(AiThinkingLevel? level) => switch (level) {
  null => _Level.auto,
  AiThinkingLevel.off => _Level.off,
  AiThinkingLevel.low => _Level.low,
  AiThinkingLevel.medium => _Level.medium,
  AiThinkingLevel.high => _Level.high,
};

AiThinkingLevel? _thinkingOf(_Level level) => switch (level) {
  _Level.auto => null,
  _Level.off => AiThinkingLevel.off,
  _Level.low => AiThinkingLevel.low,
  _Level.medium => AiThinkingLevel.medium,
  _Level.high => AiThinkingLevel.high,
};

Future<void> showAiChatModelSheet(
  BuildContext context, {
  required List<AiResolvedModel> models,
  required AiResolvedModel? defaultModel,
  required AiConversationOptions options,
  required ValueChanged<AiConversationOptions> onChanged,
}) {
  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (BuildContext sheetContext) => _ModelSheet(
      models: models,
      defaultModel: defaultModel,
      initial: options,
      onChanged: onChanged,
    ),
  );
}

class _ModelSheet extends StatefulWidget {
  const _ModelSheet({
    required this.models,
    required this.defaultModel,
    required this.initial,
    required this.onChanged,
  });

  final List<AiResolvedModel> models;
  final AiResolvedModel? defaultModel;
  final AiConversationOptions initial;
  final ValueChanged<AiConversationOptions> onChanged;

  @override
  State<_ModelSheet> createState() => _ModelSheetState();
}

class _ModelSheetState extends State<_ModelSheet> {
  late AiConversationOptions _options = widget.initial;

  void _apply(AiConversationOptions value) {
    setState(() => _options = value);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final current = _options.model;
    AiResolvedModel? effective = widget.defaultModel;
    for (final model in widget.models) {
      if (model.ref == current) effective = model;
    }
    final canThink = effective?.model.reasoning ?? true;
    final level = _levelOf(_options.thinking);
    final hint = !canThink
        ? l10n.aiThinkingDisabled
        : switch (level) {
            _Level.auto => l10n.aiThinkingAutoHint,
            _Level.off => l10n.aiThinkingOffHint,
            _Level.low => l10n.aiThinkingLowHint,
            _Level.medium => l10n.aiThinkingMediumHint,
            _Level.high => l10n.aiThinkingHighHint,
          };
    final section = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: colors.onSurfaceVariant,
    );
    Widget check(bool selected) => selected
        ? FaIcon(FontAwesomeIcons.check, size: 14, color: colors.primary)
        : const SizedBox(width: 14);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Text(
              l10n.aiChatModelSheetTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Text(l10n.aiChatThinking, style: section),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ExpressiveButtonGroup<_Level>(
              minSegmentWidth: 56,
              segments: <ButtonSegment<_Level>>[
                for (final value in _Level.values)
                  ButtonSegment<_Level>(
                    value: value,
                    label: Text(
                      aiThinkingLevelLabel(l10n, _thinkingOf(value)),
                      maxLines: 1,
                    ),
                    enabled: canThink,
                  ),
              ],
              selected: <_Level>{level},
              onSelectionChanged: canThink
                  ? (Set<_Level> picked) => _apply(
                      _options.withThinking(_thinkingOf(picked.single)),
                    )
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
            child: Text(
              hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Text(l10n.aiChatModel, style: section),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            title: Text(
              l10n.aiChatModelDefault(
                widget.defaultModel == null
                    ? '—'
                    : aiModelDisplay(widget.defaultModel!),
              ),
            ),
            trailing: check(current == null),
            onTap: () {
              _apply(_options.withModel(null));
              Navigator.of(context).pop();
            },
          ),
          for (final model in widget.models)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: Text(model.model.label),
              subtitle: Text(model.provider.name),
              trailing: check(model.ref == current),
              onTap: () {
                _apply(_options.withModel(model.ref));
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}
