// 设置 → AI 助手 → 模型分配：默认模型、快速模型与按功能指定的模型。
//
// 写入经 `updateAiLocalConfig`（只存本机）。选“跟随默认 / 跟随快速模型”
// 即删除该任务的单独指定；解析规则见 `AiLocalConfig.resolveTask`。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/services/ai/ai_provider_config.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../settings/widgets/settings_card_group.dart';
import '../../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../providers/ai_providers.dart';
import '../../viewmodels/ai_labels.dart';
import '../../widgets/ai_page_scaffold.dart';

class AiModelRoutingPage extends ConsumerWidget {
  const AiModelRoutingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final config = ref.watch(aiLocalConfigProvider);
    final first = config.firstUsable;

    String describe(AiModelRef? ref, {required String fallback}) {
      final resolved = config.resolveRef(ref);
      return resolved == null ? fallback : aiModelDisplay(resolved);
    }

    Future<void> pick({
      required String title,
      required AiModelRef? current,
      required String followLabel,
      required AiLocalConfig Function(AiLocalConfig c, AiModelRef? ref) apply,
    }) async {
      final result = await _showModelPicker(
        context,
        title: title,
        models: config.usableModels,
        current: config.resolveRef(current)?.ref,
        followLabel: followLabel,
      );
      if (result == null) return;
      await updateAiLocalConfig(ref, (c) => apply(c, result.ref));
    }

    return AiPageScaffold(
      title: l10n.aiRoutingTitle,
      children: <Widget>[
        SettingsCardGroup(
          children: <Widget>[
            _RoutingTile(
              title: l10n.aiRoutingDefault,
              explanation: l10n.aiRoutingDefaultSubtitle,
              value: describe(
                config.defaultModel,
                fallback: first == null
                    ? l10n.aiRoutingNone
                    : l10n.aiRoutingFirstUsable(aiModelDisplay(first)),
              ),
              onTap: () => pick(
                title: l10n.aiRoutingDefault,
                current: config.defaultModel,
                followLabel: first == null
                    ? l10n.aiRoutingNone
                    : l10n.aiRoutingFirstUsable(aiModelDisplay(first)),
                apply: (c, value) => c.copyWith(defaultModel: value),
              ),
            ),
            _RoutingTile(
              title: l10n.aiRoutingFast,
              explanation: l10n.aiRoutingFastSubtitle,
              value: describe(
                config.fastModel,
                fallback: l10n.aiRoutingFollowDefault,
              ),
              onTap: () => pick(
                title: l10n.aiRoutingFast,
                current: config.fastModel,
                followLabel: l10n.aiRoutingFollowDefault,
                apply: (c, value) => c.copyWith(fastModel: value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCardGroup(
          title: l10n.aiRoutingTasksGroup,
          children: <Widget>[
            for (final task in AiTaskKind.values)
              _RoutingTile(
                title: aiTaskLabel(l10n, task),
                explanation: task == AiTaskKind.utility
                    ? l10n.aiTaskUtilitySubtitle
                    : null,
                value: describe(
                  config.taskModels[task],
                  fallback: task.prefersFastModel && config.fastModel != null
                      ? l10n.aiRoutingFollowFast
                      : l10n.aiRoutingFollowDefault,
                ),
                onTap: () => pick(
                  title: aiTaskLabel(l10n, task),
                  current: config.taskModels[task],
                  followLabel: task.prefersFastModel
                      ? l10n.aiRoutingFollowFast
                      : l10n.aiRoutingFollowDefault,
                  apply: (c, value) {
                    final next = {...c.taskModels};
                    if (value == null) {
                      next.remove(task);
                    } else {
                      next[task] = value;
                    }
                    return c.copyWith(taskModels: next);
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RoutingTile extends StatelessWidget {
  const _RoutingTile({
    required this.title,
    required this.value,
    required this.onTap,
    this.explanation,
  });

  final String title;
  final String value;
  final String? explanation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      titleAlignment: ListTileTitleAlignment.center,
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.primary),
          ),
          if (explanation != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(explanation!),
            ),
        ],
      ),
      trailing: FaIcon(
        FontAwesomeIcons.angleRight,
        size: 14,
        color: colors.onSurfaceVariant.withValues(alpha: 0.6),
      ),
      onTap: onTap,
    );
  }
}

/// 模型选择面板的结果：选中的模型，或“跟随”（ref 为 null）。
class _PickResult {
  const _PickResult(this.ref);

  final AiModelRef? ref;
}

Future<_PickResult?> _showModelPicker(
  BuildContext context, {
  required String title,
  required List<AiResolvedModel> models,
  required AiModelRef? current,
  required String followLabel,
}) {
  return showAppModalBottomSheet<_PickResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (BuildContext sheetContext) {
      final theme = Theme.of(sheetContext);
      final colors = theme.colorScheme;
      Widget check(bool selected) => selected
          ? FaIcon(FontAwesomeIcons.check, size: 14, color: colors.primary)
          : const SizedBox(width: 14);
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: Text(followLabel),
              trailing: check(current == null),
              onTap: () =>
                  Navigator.of(sheetContext).pop(const _PickResult(null)),
            ),
            for (final model in models)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text(model.model.label),
                subtitle: Text(model.provider.name),
                trailing: check(model.ref == current),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PickResult(model.ref)),
              ),
          ],
        ),
      );
    },
  );
}
