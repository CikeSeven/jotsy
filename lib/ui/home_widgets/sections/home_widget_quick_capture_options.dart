import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/services/home_widgets/home_widget_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/providers/app_features_provider.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_option_tiles.dart';
import '../../widgets/expressive_reorder_proxy.dart';
import '../../widgets/reorder_handle.dart';
import '../viewmodels/home_widget_native_config.dart';
import '../widgets/home_widget_kind_labels.dart';
import 'home_widget_notebook_choice.dart';

/// 快速记录的内容选项：动作（拖动排序、移除、从剩下的里添加，最多
/// [QuickCaptureContent.maxActions] 个，第一个最醒目），“写日记”写进哪个
/// 日记本，以及是否显示文字、日期与问候。
///
/// 功能关闭的动作（待办、日历）不出现在可添加的列表里；已经选上的仍列着
/// （重新开启功能即恢复），小组件上暂时不显示它（`homeWidgetNativeConfig`）。
class HomeWidgetQuickCaptureOptions extends ConsumerWidget {
  const HomeWidgetQuickCaptureOptions({
    super.key,
    required this.content,
    required this.onChanged,
  });

  final QuickCaptureContent content;
  final ValueChanged<QuickCaptureContent> onChanged;

  void _reorder(int oldIndex, int newIndex) {
    final actions = List<QuickCaptureAction>.of(content.actions);
    final moved = actions.removeAt(oldIndex);
    actions.insert(newIndex, moved);
    onChanged(content.copyWith(actions: actions));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final features = ref.watch(appFeaturesProvider);
    final actions = content.actions;
    final addable = <QuickCaptureAction>[
      for (final action in QuickCaptureAction.values)
        if (!actions.contains(action) &&
            quickCaptureActionAvailable(action, features))
          action,
    ];
    final canAdd = actions.length < QuickCaptureContent.maxActions;
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      buildDefaultDragHandles: false,
      proxyDecorator: expressiveReorderProxyDecorator,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
        child: Text(
          l10n.homeWidgetQuickActionsHint,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (canAdd && addable.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final action in addable)
                    ActionChip(
                      avatar: FaIcon(quickCaptureActionIcon(action), size: 14),
                      label: Text(quickCaptureActionName(l10n, action)),
                      tooltip: l10n.homeWidgetQuickAddAction,
                      onPressed: () => onChanged(
                        content.copyWith(
                          actions: <QuickCaptureAction>[...actions, action],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SettingsCardGroup(
            children: <Widget>[
              if (features.notebooks &&
                  actions.contains(QuickCaptureAction.write))
                HomeWidgetNotebookChoice(
                  notebookId: content.notebookId,
                  onChanged: (String? id) =>
                      onChanged(content.copyWith(notebookId: () => id)),
                ),
              SettingsSwitchTile(
                title: l10n.homeWidgetQuickShowLabels,
                value: content.showLabels,
                onChanged: (bool value) =>
                    onChanged(content.copyWith(showLabels: value)),
              ),
              SettingsSwitchTile(
                title: l10n.homeWidgetQuickShowGreeting,
                subtitle: l10n.homeWidgetQuickShowGreetingHint,
                value: content.showGreeting,
                onChanged: (bool value) =>
                    onChanged(content.copyWith(showGreeting: value)),
              ),
            ],
          ),
        ],
      ),
      itemCount: actions.length,
      onReorderStart: (_) => unawaited(HapticFeedback.mediumImpact()),
      onReorderItem: _reorder,
      itemBuilder: (BuildContext context, int index) {
        final action = actions[index];
        final label = quickCaptureActionName(l10n, action);
        final primary = index == 0;
        return Padding(
          key: ValueKey<QuickCaptureAction>(action),
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: ExpressiveSurfaces.cardColor(scheme),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: ExpressiveSurfaces.cardBorderSide(scheme),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsetsDirectional.only(
                start: 12,
                end: 4,
              ),
              leading: _ActionBadge(action: action, primary: primary),
              title: Text(label),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (actions.length > 1)
                    IconButton(
                      tooltip: l10n.homeWidgetQuickRemoveAction,
                      onPressed: () => onChanged(
                        content.copyWith(
                          actions: <QuickCaptureAction>[
                            for (final other in actions)
                              if (other != action) other,
                          ],
                        ),
                      ),
                      icon: const FaIcon(FontAwesomeIcons.xmark, size: 16),
                    ),
                  ReorderHandle(index: index),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 动作图标：第一个（主动作）是实心主色圆，其余为色调圆——与小组件上
/// 主次按钮的样子一致。
class _ActionBadge extends StatelessWidget {
  const _ActionBadge({required this.action, required this.primary});

  final QuickCaptureAction action;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primary ? scheme.primary : scheme.secondaryContainer,
      ),
      child: FaIcon(
        quickCaptureActionIcon(action),
        size: 15,
        color: primary ? scheme.onPrimary : scheme.onSecondaryContainer,
      ),
    );
  }
}
