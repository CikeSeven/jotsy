import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/editing_session_registry.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../../widgets/expressive_reorder_proxy.dart';
import '../../widgets/form_width.dart';
import '../../widgets/reorder_handle.dart';
import '../controllers/todo_list_actions.dart';
import '../providers/todo_providers.dart';
import '../viewmodels/todo_list_style.dart';

/// 清单管理：拖动排序、改名 / 颜色 / 图标、删除（连同其中的待办，可撤销），
/// 右上角“+”新建。
///
/// 拖动从拿起到新顺序写完是局域网同步的阻塞者（[ReorderEditingGuard]）。
/// 拖动只改被拖的那一行（取两邻居的中点，见 `moveTodoList`）。
class TodoListsPage extends ConsumerStatefulWidget {
  const TodoListsPage({super.key});

  @override
  ConsumerState<TodoListsPage> createState() => _TodoListsPageState();
}

class _TodoListsPageState extends ConsumerState<TodoListsPage> {
  final ReorderEditingGuard _drag = ReorderEditingGuard('todo-lists-manage');

  @override
  void dispose() {
    _drag.end();
    super.dispose();
  }

  void _reorder(List<TodoListRow> lists, int oldIndex, int newIndex) {
    final moved = lists[oldIndex];
    final order = List<TodoListRow>.of(lists)..removeAt(oldIndex);
    order.insert(newIndex, moved);
    final above = newIndex > 0 ? order[newIndex - 1].listId : null;
    final below = newIndex < order.length - 1
        ? order[newIndex + 1].listId
        : null;
    unawaited(
      _drag.holdUntil(
        ref
            .read(appDatabaseProvider)
            .moveTodoList(moved.listId, aboveId: above, belowId: below),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final lists = ref.watch(todoListsProvider).value;
    final counts =
        ref.watch(todoOpenCountsByListProvider).value ?? const <String?, int>{};
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
            title: Text(l10n.todoListsSection),
            actions: <Widget>[
              IconButton(
                tooltip: l10n.todoListNew,
                onPressed: () => unawaited(createTodoListFlow(context, ref)),
                icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
              ),
            ],
          ),
          body: lists == null
              ? const DelayedLoadingIndicator()
              : lists.isEmpty
              ? EmptyHint(
                  icon: FontAwesomeIcons.listCheck,
                  message: l10n.todoListEmptyManage,
                )
              : LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final side = FormWidth.gutter(constraints.maxWidth);
                    return CustomScrollView(
                      slivers: <Widget>[
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            side,
                            AppSpacing.s,
                            side,
                            AppSpacing.xxxl,
                          ),
                          sliver: SliverReorderableList(
                            itemCount: lists.length,
                            proxyDecorator: cardRowReorderProxyDecorator,
                            onReorderStart: (int index) {
                              _drag.start(index);
                              unawaited(HapticFeedback.mediumImpact());
                            },
                            onReorderEnd: _drag.dropped,
                            onReorderItem: (int oldIndex, int newIndex) =>
                                _reorder(lists, oldIndex, newIndex),
                            itemBuilder: (BuildContext context, int index) {
                              final list = lists[index];
                              final accent = TodoListStyle.accentOf(
                                list.colorKey,
                                scheme,
                              );
                              return Padding(
                                key: ValueKey<String>(list.listId),
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.s,
                                ),
                                child: AppCardSurface(
                                  shadow: false,
                                  child: ListTile(
                                    titleAlignment:
                                        ListTileTitleAlignment.center,
                                    contentPadding:
                                        const EdgeInsetsDirectional.only(
                                          end: AppSpacing.xs,
                                        ),
                                    leading: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        ReorderHandle(index: index),
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: accent.container,
                                          child: FaIcon(
                                            TodoListStyle.iconOfRow(list),
                                            size: 15,
                                            color: accent.onContainer,
                                          ),
                                        ),
                                      ],
                                    ),
                                    title: Text(
                                      list.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: (counts[list.listId] ?? 0) == 0
                                        ? null
                                        : Text('${counts[list.listId]}'),
                                    onTap: () => unawaited(
                                      editTodoListFlow(context, ref, list),
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
                                            editTodoListFlow(
                                              context,
                                              ref,
                                              list,
                                            ),
                                          ),
                                          child: Text(l10n.todoListEdit),
                                        ),
                                        ExpressiveMenuItem(
                                          leadingIcon: const FaIcon(
                                            FontAwesomeIcons.trashCan,
                                          ),
                                          destructive: true,
                                          onPressed: () => unawaited(
                                            deleteTodoListFlow(
                                              context,
                                              ref,
                                              list,
                                            ),
                                          ),
                                          child: Text(l10n.todoListDelete),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}
