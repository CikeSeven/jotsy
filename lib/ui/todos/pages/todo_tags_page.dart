import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../../widgets/form_width.dart';
import '../controllers/todo_tag_actions.dart';
import '../providers/todo_providers.dart';
import '../widgets/todo_view_hero.dart';

/// 待办标签管理：每个标签一张行卡（`tertiaryContainer` 方块 + 名称 + “N 条
/// 未完成 · 共 M 条”），点行或“⋯”改名（改成已有的名字即合并），“⋯”里
/// 还有删除（从所有待办上去掉、待办保留）。都可撤销。
///
/// 标签按名称排序、不能拖动（没有标签顺序，与日记标签无关）；没有标签时
/// 是空状态。
class TodoTagsPage extends ConsumerWidget {
  const TodoTagsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tags = ref.watch(todoTagsProvider).value;
    return AppPageBackground(
      area: AppBackgroundArea.other,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          appBar: AppTopBar(
            contentMaxWidth: FormWidth.maxWidth,
            leading: IconButton(
              tooltip: l10n.commonBack,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
            title: Text(l10n.todoTagsManageTitle),
          ),
          body: tags == null
              ? const DelayedLoadingIndicator()
              : tags.isEmpty
              ? EmptyHint(
                  icon: FontAwesomeIcons.tag,
                  message: l10n.todoTagsManageEmpty,
                  detail: l10n.todoTagsEmptyHint,
                )
              : LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final side = FormWidth.gutter(constraints.maxWidth);
                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        side,
                        AppSpacing.s,
                        side,
                        AppSpacing.xxxl,
                      ),
                      itemCount: tags.length,
                      itemBuilder: (BuildContext context, int index) {
                        final tag = tags[index];
                        return Padding(
                          key: ValueKey<String>(TodoTags.keyOf(tag.name)),
                          padding: const EdgeInsets.only(bottom: AppSpacing.s),
                          child: AppCardSurface(
                            shadow: false,
                            child: ListTile(
                              leading: TodoIconBlock(
                                icon: FontAwesomeIcons.tag,
                                background: scheme.tertiaryContainer,
                                foreground: scheme.onTertiaryContainer,
                                size: 36,
                              ),
                              title: Text(
                                tag.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                l10n.todoTagUsage(
                                  tag.openCount,
                                  tag.totalCount,
                                ),
                              ),
                              onTap: () => unawaited(
                                renameTodoTagFlow(context, ref, tag.name),
                              ),
                              trailing: ExpressiveMenuButton(
                                tooltip: l10n.todoMore,
                                icon: const FaIcon(
                                  FontAwesomeIcons.ellipsisVertical,
                                  size: 16,
                                ),
                                items: <Widget>[
                                  ExpressiveMenuItem(
                                    leadingIcon: const FaIcon(
                                      FontAwesomeIcons.pen,
                                    ),
                                    onPressed: () => unawaited(
                                      renameTodoTagFlow(context, ref, tag.name),
                                    ),
                                    child: Text(l10n.todoTagRename),
                                  ),
                                  ExpressiveMenuItem(
                                    leadingIcon: const FaIcon(
                                      FontAwesomeIcons.trashCan,
                                    ),
                                    destructive: true,
                                    onPressed: () => unawaited(
                                      deleteTodoTagFlow(context, ref, tag),
                                    ),
                                    child: Text(l10n.commonDelete),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }
}
