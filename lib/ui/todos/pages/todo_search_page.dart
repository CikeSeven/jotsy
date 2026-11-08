import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/form_width.dart';
import '../../widgets/search_pill_field.dart';
import '../controllers/todo_actions.dart';
import '../controllers/todo_debounced_writer.dart';
import '../controllers/todo_navigation.dart';
import '../providers/todo_providers.dart';
import '../widgets/todo_tile.dart';

/// 搜索待办：每个词都要出现在标题、备注或某个步骤里（与日记搜索同一拆词
/// 口径），含已完成的，未完成的在前。结果实时随库变化（勾选、删除后立即
/// 更新）。
class TodoSearchPage extends ConsumerStatefulWidget {
  const TodoSearchPage({super.key});

  @override
  ConsumerState<TodoSearchPage> createState() => _TodoSearchPageState();
}

class _TodoSearchPageState extends ConsumerState<TodoSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _keyword = '';
  late final TodoDebouncedWriter<String> _debounce =
      TodoDebouncedWriter<String>(
        delay: TodoDebouncedWriter.searchDelay,
        onFire: (String value) {
          if (mounted) setState(() => _keyword = value.trim());
        },
      );

  @override
  void dispose() {
    _debounce.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) => _debounce.schedule(value);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final lists = ref.watch(todoListsProvider).value ?? const <TodoListRow>[];
    final listsById = <String, TodoListRow>{
      for (final list in lists) list.listId: list,
    };
    final results = _keyword.isEmpty
        ? null
        : ref.watch(todoSearchProvider(_keyword)).value;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

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
            title: SearchPillField(
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              hintText: l10n.todoSearchHint,
              // 与日记搜索页同一底色与描边；玻璃材质由输入框自己处理。
              fill: scheme.brightness == Brightness.light
                  ? ExpressiveSurfaces.cardColor(scheme)
                  : scheme.surfaceContainerHigh,
              idleOutline: ExpressiveSurfaces.cardBorderColor(scheme),
              onChanged: _onChanged,
              onClear: () {
                _controller.clear();
                _onChanged('');
              },
            ),
          ),
          body: results == null
              ? const SizedBox.shrink()
              : results.isEmpty
              ? EmptyHint(
                  icon: FontAwesomeIcons.magnifyingGlass,
                  message: l10n.todoEmptySearch,
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
                      itemCount: results.length,
                      itemBuilder: (BuildContext context, int index) {
                        final row = results[index];
                        final listId = row.listId;
                        return Padding(
                          key: ValueKey<String>(row.todoId),
                          padding: const EdgeInsets.only(bottom: AppSpacing.s),
                          child: TodoTile(
                            row: row,
                            today: today,
                            list: listId == null ? null : listsById[listId],
                            onToggle: () => unawaited(
                              toggleTodoDone(
                                context,
                                ref.read(appDatabaseProvider),
                                row,
                              ),
                            ),
                            onTap: () =>
                                unawaited(openTodoDetail(context, row.todoId)),
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
