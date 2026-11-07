// 设置 → AI 助手 → 写作指令：内置与自建的指令按用户顺序排列（整页可
// 拖动排序，顺序即编辑器 AI 面板里胶囊的顺序），可隐藏、改写内置提示词
// 或恢复默认、新建 / 编辑 / 删除（可撤销）自建指令。写入只经
// `updateAiPreferences`；排序写整份 `actionOrder`。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_card_surface.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../../app_surface/widgets/app_page_backdrop.dart';
import '../../../home/widgets/home_hint_visibility_scope.dart';
import '../../../widgets/expressive_menu/expressive_menu_button.dart';
import '../../../widgets/expressive_menu/expressive_menu_item.dart';
import '../../../widgets/expressive_reorder_proxy.dart';
import '../../../widgets/reorder_handle.dart';
import '../../models/ai_built_ins.dart';
import '../../models/ai_preferences.dart';
import '../../providers/ai_providers.dart';
import '../../widgets/ai_page_scaffold.dart';
import 'ai_action_edit_page.dart';

class AiActionsPage extends ConsumerWidget {
  const AiActionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final prefs = ref.watch(aiPreferencesProvider);
    final actions = aiWritingActions(l10n, l10n, prefs, includeHidden: true);
    final full = prefs.customActions.length >= AiPreferences.maxCustomActions;

    void open(AiActionInfo? action) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              AiActionEditPage(actionId: action?.id),
        ),
      );
    }

    Future<void> delete(AiActionInfo action) async {
      final before = ref.read(aiPreferencesProvider);
      await updateAiPreferences(
        ref,
        (p) => p.copyWith(
          customActions: [
            for (final item in p.customActions)
              if (item.id != action.id) item,
          ],
        ),
      );
      if (!context.mounted) return;
      await HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(
          persist: false,
          content: Text(l10n.aiCommonDeleted(action.label)),
          action: SnackBarAction(
            label: l10n.commonUndo,
            onPressed: () => updateAiPreferences(
              ref,
              (p) => p.copyWith(customActions: before.customActions),
            ),
          ),
        ),
      );
    }

    return AiPageScaffold(
      title: l10n.aiActionsTitle,
      bodyBuilder: (BuildContext context, EdgeInsets padding) {
        return ReorderableListView.builder(
          padding: padding + const EdgeInsets.symmetric(horizontal: 16),
          buildDefaultDragHandles: false,
          proxyDecorator: cardRowReorderProxyDecorator,
          itemCount: actions.length,
          // 手柄按住即拖，不经过长按，系统不会给触觉：拿起时补一次。
          onReorderStart: (_) => unawaited(HapticFeedback.mediumImpact()),
          onReorderItem: (int oldIndex, int newIndex) {
            final ids = [for (final action in actions) action.id];
            ids.insert(newIndex, ids.removeAt(oldIndex));
            updateAiPreferences(ref, (p) => p.copyWith(actionOrder: ids));
          },
          footer: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FilledButton.tonalIcon(
                  style: AppGlassField.tonalButtonStyle(context),
                  onPressed: full ? null : () => open(null),
                  icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
                  label: Text(
                    full
                        ? l10n.aiActionLimit(AiPreferences.maxCustomActions)
                        : l10n.aiActionAdd,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    l10n.aiActionsFooter,
                    style: AppPageBackdrop.onBackgroundTextStyle(
                      context,
                      theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          itemBuilder: (BuildContext context, int index) {
            final action = actions[index];
            final hidden = prefs.hiddenActions.contains(action.id);
            return Padding(
              key: ValueKey<String>(action.id),
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCardSurface(
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                child: _ActionTile(
                  index: index,
                  action: action,
                  hidden: hidden,
                  onTap: () => open(action),
                  menu: <Widget>[
                    ExpressiveMenuItem(
                      leadingIcon: const FaIcon(FontAwesomeIcons.pen),
                      onPressed: () => open(action),
                      child: Text(l10n.commonEdit),
                    ),
                    ExpressiveMenuItem(
                      leadingIcon: FaIcon(
                        hidden
                            ? FontAwesomeIcons.eye
                            : FontAwesomeIcons.eyeSlash,
                      ),
                      onPressed: () => updateAiPreferences(ref, (p) {
                        final next = {...p.hiddenActions};
                        hidden ? next.remove(action.id) : next.add(action.id);
                        return p.copyWith(hiddenActions: next);
                      }),
                      child: Text(
                        hidden ? l10n.aiCommonShow : l10n.aiCommonHide,
                      ),
                    ),
                    if (action.builtIn && action.customized)
                      ExpressiveMenuItem(
                        leadingIcon: const FaIcon(
                          FontAwesomeIcons.arrowRotateLeft,
                        ),
                        onPressed: () => updateAiPreferences(
                          ref,
                          (p) => p.copyWith(
                            actionPrompts: {...p.actionPrompts}
                              ..remove(action.id),
                          ),
                        ),
                        child: Text(l10n.aiCommonRestoreDefault),
                      ),
                    if (!action.builtIn)
                      ExpressiveMenuItem(
                        leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
                        destructive: true,
                        onPressed: () => delete(action),
                        child: Text(l10n.commonDelete),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.index,
    required this.action,
    required this.hidden,
    required this.onTap,
    required this.menu,
  });

  final int index;
  final AiActionInfo action;
  final bool hidden;
  final VoidCallback onTap;
  final List<Widget> menu;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(end: 4),
      titleAlignment: ListTileTitleAlignment.center,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ReorderHandle(index: index),
          Text(action.emoji, style: const TextStyle(fontSize: 20, height: 1)),
        ],
      ),
      title: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: hidden ? TextStyle(color: colors.onSurfaceVariant) : null,
            ),
          ),
          if (action.customized) ...<Widget>[
            const SizedBox(width: 8),
            AiBadge(l10n.aiActionCustomized),
          ],
          if (hidden) ...<Widget>[
            const SizedBox(width: 8),
            AiBadge(l10n.aiCommonHidden),
          ],
        ],
      ),
      subtitle: Text(
        action.prompt,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: ExpressiveMenuButton(
        tooltip: action.label,
        icon: FaIcon(
          FontAwesomeIcons.ellipsisVertical,
          size: 16,
          color: colors.onSurfaceVariant,
        ),
        items: menu,
      ),
      onTap: onTap,
    );
  }
}
