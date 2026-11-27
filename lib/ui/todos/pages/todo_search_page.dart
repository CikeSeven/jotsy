import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
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
import '../sections/todo_search_filter_bar.dart';
import '../viewmodels/todo_search_filter.dart';
import '../widgets/todo_tile.dart';

/// 搜索待办：每个词都要出现在标题、备注或某个步骤里（与日记搜索同一拆词
/// 口径），含已完成的，未完成的在前；命中的词在标题与备注里高亮。结果实时
/// 随库变化（勾选、删除后立即更新）。
///
/// 搜索框下是一排筛选（[TodoSearchFilterBar]）：有关键词时筛搜索结果；没有
/// 关键词但选了筛选时，直接按筛选列出全部未完成的与最近完成的（如“高优先级
/// 的未完成”），不必先想一个词。
class TodoSearchPage extends ConsumerStatefulWidget {
  const TodoSearchPage({super.key});

  @override
  ConsumerState<TodoSearchPage> createState() => _TodoSearchPageState();
}

class _TodoSearchPageState extends ConsumerState<TodoSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _keyword = '';
  TodoSearchFilter _filter = const TodoSearchFilter();
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

  /// 要列出的待办；null 为还没有可搜的（无关键词也无筛选）或数据未到。
  List<TodoRow>? _results() {
    if (_keyword.isNotEmpty) {
      final rows = ref.watch(todoSearchProvider(_keyword)).value;
      return rows == null ? null : _filter.apply(rows);
    }
    if (_filter.isEmpty) return null;
    // 只看某一状态时不必订阅另一边。
    final status = _filter.status;
    final open = status == TodoSearchStatus.done
        ? const <TodoRow>[]
        : ref.watch(openTodosProvider).value;
    final done = status == TodoSearchStatus.open
        ? const <TodoRow>[]
        : ref.watch(completedTodosProvider).value;
    if (open == null || done == null) return null;
    return _filter.apply(<TodoRow>[...open, ...done]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final lists = ref.watch(todoListsProvider).value ?? const <TodoListRow>[];
    final listsById = <String, TodoListRow>{
      for (final list in lists) list.listId: list,
    };
    final results = _results();
    final terms = splitSearchTerms(_keyword);
    final today = ref.watch(todoTodayProvider);

    Widget resultsView(double side) {
      if (results == null) return const SizedBox.shrink(key: ValueKey('idle'));
      if (results.isEmpty) {
        return EmptyHint(
          key: const ValueKey('empty'),
          icon: FontAwesomeIcons.magnifyingGlass,
          message: l10n.todoEmptySearch,
        );
      }
      return ListView.builder(
        key: const ValueKey('results'),
        padding: EdgeInsets.fromLTRB(side, AppSpacing.s, side, AppSpacing.xxxl),
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
              highlights: terms,
              onToggle: () => unawaited(
                toggleTodoDone(context, ref.read(appDatabaseProvider), row),
              ),
              onTap: () => unawaited(openTodoDetail(context, row.todoId)),
            ),
          );
        },
      );
    }

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
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final side = FormWidth.gutter(constraints.maxWidth);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s),
                    child: TodoSearchFilterBar(
                      filter: _filter,
                      padding: EdgeInsets.symmetric(horizontal: side),
                      onChanged: (TodoSearchFilter next) =>
                          setState(() => _filter = next),
                    ),
                  ),
                  // 空闲 / 无结果 / 有结果之间交叉淡入（行不是玻璃）；结果
                  // 之间的变化（筛掉、勾选）就地更新，不重演。
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: ExpressiveMotion.duration(
                        context,
                        ExpressiveMotion.medium,
                      ),
                      switchInCurve: ExpressiveMotion.effects,
                      switchOutCurve: ExpressiveMotion.exit,
                      child: resultsView(side),
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
