import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../diaries/widgets/tag_filter_chip.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../widgets/expressive_button_group.dart';
import '../../widgets/expressive_choice_tile.dart';
import '../viewmodels/notebook_rule_labels.dart';
import 'notebook_rule_date_editor.dart';

/// 智能日记本规则的面板：“添加条件”的类型选择，以及各类型的编辑面板。
///
/// 每个编辑面板只维护自己的草稿，点“完成”时返回新规则，关闭面板返回
/// null（不改动）。草稿不完整（没选标签、没填文字）时“完成”不可用，不会
/// 产生编译为“不匹配”的空规则。

Future<T?> _showRuleSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showAppModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: builder,
  );
}

/// “添加条件”：列出规则类型，每项一行说明；点一项返回该类型。
Future<NotebookRuleType?> showNotebookRuleTypeSheet(BuildContext context) {
  return _showRuleSheet<NotebookRuleType>(context, (BuildContext sheetContext) {
    final l10n = sheetContext.l10n;
    final scheme = Theme.of(sheetContext).colorScheme;
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: AppSpacing.l + MediaQuery.paddingOf(sheetContext).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SheetTitle(l10n.notebookRuleAdd),
          for (final type in NotebookRuleType.values)
            ListTile(
              titleAlignment: ListTileTitleAlignment.center,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
              ),
              leading: FaIcon(
                notebookRuleTypeIcon(type),
                size: 18,
                color: scheme.primary,
              ),
              title: Text(notebookRuleTypeLabel(l10n, type)),
              subtitle: Text(notebookRuleTypeHint(l10n, type)),
              onTap: () => Navigator.of(sheetContext).pop(type),
            ),
        ],
      ),
    );
  });
}

/// 编辑 [type] 类型的规则；[initial] 为正在编辑的规则（新增时为 null）。
/// 返回编辑后的规则，关闭面板返回 null。
Future<NotebookRule?> showNotebookRuleEditorSheet(
  BuildContext context, {
  required NotebookRuleType type,
  NotebookRule? initial,
}) {
  return _showRuleSheet<NotebookRule>(
    context,
    (BuildContext _) => switch (type) {
      NotebookRuleType.tags => _TagsRuleEditor(
        initial: initial is NotebookTagsRule ? initial : null,
      ),
      NotebookRuleType.mood => _MoodRuleEditor(
        initial: initial is NotebookMoodRule ? initial : null,
      ),
      NotebookRuleType.weather => _TextRuleEditor(
        field: NotebookTextField.weather,
        initial: initial is NotebookTextRule ? initial : null,
      ),
      NotebookRuleType.location => _TextRuleEditor(
        field: NotebookTextField.location,
        initial: initial is NotebookTextRule ? initial : null,
      ),
      NotebookRuleType.keyword => _TextRuleEditor(
        field: NotebookTextField.keyword,
        initial: initial is NotebookTextRule ? initial : null,
      ),
      NotebookRuleType.date => NotebookDateRuleEditor(
        initial: initial is NotebookDateRule ? initial : null,
      ),
      NotebookRuleType.media => _MediaRuleEditor(
        initial: initial is NotebookMediaRule ? initial : null,
      ),
      NotebookRuleType.flag => _FlagRuleEditor(
        initial: initial is NotebookFlagRule ? initial : null,
      ),
    },
  );
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.s,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// 编辑面板的骨架：标题行（右侧“完成”）+ 内容；随键盘上移，内容过高时滚动。
/// [result] 为 null 时“完成”不可用。
class NotebookRuleSheetFrame extends StatelessWidget {
  const NotebookRuleSheetFrame({
    super.key,
    required this.title,
    required this.result,
    required this.children,
  });

  final String title;
  final NotebookRule? result;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final result = this.result;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: AppSpacing.xs,
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: result == null
                      ? null
                      : () => Navigator.of(context).pop(result),
                  child: Text(l10n.notebookRuleDone),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// 标签：所有标签以 `#` 胶囊多选，上方选择“含任一 / 全部都含 / 都不含”。
/// 规则里已有、但标签已被删除或改名的名称也列出来（选中态），可以取消。
class _TagsRuleEditor extends ConsumerStatefulWidget {
  const _TagsRuleEditor({this.initial});

  final NotebookTagsRule? initial;

  @override
  ConsumerState<_TagsRuleEditor> createState() => _TagsRuleEditorState();
}

class _TagsRuleEditorState extends ConsumerState<_TagsRuleEditor> {
  late NotebookTagMatch _mode = widget.initial?.mode ?? NotebookTagMatch.any;
  late final List<String> _selected = <String>[...?widget.initial?.names];

  void _toggle(String name) => setState(() {
    if (!_selected.remove(name)) _selected.add(name);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tags = ref.watch(tagListProvider).value ?? const <Tag>[];
    final known = <String>{for (final tag in tags) tag.name};
    final missing = _selected.where((name) => !known.contains(name)).toList();
    return NotebookRuleSheetFrame(
      title: l10n.notebookRuleTypeTags,
      result: _selected.isEmpty
          ? null
          : NotebookTagsRule(mode: _mode, names: _selected),
      children: <Widget>[
        ExpressiveButtonGroup<NotebookTagMatch>(
          minSegmentWidth: 88,
          segments: <ButtonSegment<NotebookTagMatch>>[
            for (final mode in NotebookTagMatch.values)
              ButtonSegment<NotebookTagMatch>(
                value: mode,
                label: Text(notebookTagMatchLabel(l10n, mode)),
              ),
          ],
          selected: <NotebookTagMatch>{_mode},
          onSelectionChanged: (value) => setState(() => _mode = value.single),
        ),
        const SizedBox(height: AppSpacing.l),
        if (tags.isEmpty && missing.isEmpty)
          Text(
            l10n.notebookRuleNoTags,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: <Widget>[
              for (final tag in tags)
                notebookRuleTagChip(
                  theme,
                  name: tag.name,
                  color: Color(tag.color),
                  selected: _selected.contains(tag.name),
                  onTap: () => _toggle(tag.name),
                ),
              for (final name in missing)
                notebookRuleTagChip(
                  theme,
                  name: name,
                  color: theme.colorScheme.outline,
                  selected: true,
                  onTap: () => _toggle(name),
                ),
            ],
          ),
      ],
    );
  }
}

/// 规则面板里的 `#` 标签胶囊：标签色浅底 + 标签色文字（DESIGN.md §5.2），
/// 选中时加深底色并描边，配色与日历筛选面板的标签胶囊一致。
Widget notebookRuleTagChip(
  ThemeData theme, {
  required String name,
  required Color color,
  required bool selected,
  required VoidCallback onTap,
}) {
  final scheme = theme.colorScheme;
  final isLight = theme.brightness == Brightness.light;
  final readable =
      isLight && ThemeData.estimateBrightnessForColor(color) == Brightness.dark
      ? color
      : scheme.onSurface;
  return TagFilterChip(
    label: '# $name',
    selected: selected,
    selectedColor: color.withValues(alpha: isLight ? 0.22 : 0.36),
    selectedForegroundColor: readable,
    selectedBorderColor: color,
    unselectedColor: color.withValues(alpha: isLight ? 0.12 : 0.16),
    unselectedForegroundColor: readable,
    unselectedBorderColor: color.withValues(alpha: isLight ? 0.22 : 0.32),
    radius: 12,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    animateBorder: true,
    onTap: onTap,
  );
}

/// 心情胶囊（与日历筛选面板一致）；月份胶囊也用它。
Widget notebookRuleOptionChip(
  ColorScheme scheme, {
  required String label,
  required bool selected,
  required VoidCallback onTap,
}) {
  final isLight = scheme.brightness == Brightness.light;
  return TagFilterChip(
    label: label,
    selected: selected,
    selectedColor: scheme.primary.withValues(alpha: isLight ? 0.16 : 0.28),
    selectedForegroundColor: scheme.onSurface,
    selectedBorderColor: scheme.primary,
    unselectedColor: scheme.surfaceContainerHigh,
    unselectedForegroundColor: scheme.onSurface,
    radius: 12,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    animateBorder: true,
    onTap: onTap,
  );
}

/// 心情：本机心情选项（与发布面板同一来源）多选；规则里已有、但已不在选项
/// 里的心情也列出来。
class _MoodRuleEditor extends ConsumerStatefulWidget {
  const _MoodRuleEditor({this.initial});

  final NotebookMoodRule? initial;

  @override
  ConsumerState<_MoodRuleEditor> createState() => _MoodRuleEditorState();
}

class _MoodRuleEditorState extends ConsumerState<_MoodRuleEditor> {
  late final List<String> _selected = <String>[...?widget.initial?.emojis];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final options = ref.watch(moodOptionsProvider).value ?? const <String>[];
    final moods = <String>[
      ...options,
      ..._selected.where((mood) => !options.contains(mood)),
    ];
    return NotebookRuleSheetFrame(
      title: l10n.notebookRuleTypeMood,
      result: _selected.isEmpty ? null : NotebookMoodRule(emojis: _selected),
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: <Widget>[
            for (final mood in moods)
              notebookRuleOptionChip(
                scheme,
                label: mood,
                selected: _selected.contains(mood),
                onTap: () => setState(() {
                  if (!_selected.remove(mood)) _selected.add(mood);
                }),
              ),
          ],
        ),
      ],
    );
  }
}

/// 天气 / 地点 / 关键词：一个输入框，回车即完成。
class _TextRuleEditor extends StatefulWidget {
  const _TextRuleEditor({required this.field, this.initial});

  final NotebookTextField field;
  final NotebookTextRule? initial;

  @override
  State<_TextRuleEditor> createState() => _TextRuleEditorState();
}

class _TextRuleEditorState extends State<_TextRuleEditor> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial?.field == widget.field ? widget.initial?.text : '',
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  NotebookRule? get _result => _text.text.trim().isEmpty
      ? null
      : NotebookTextRule(field: widget.field, text: _text.text);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (title, hint) = switch (widget.field) {
      NotebookTextField.weather => (
        l10n.notebookRuleTypeWeather,
        l10n.notebookRuleWeatherHint,
      ),
      NotebookTextField.location => (
        l10n.notebookRuleTypeLocation,
        l10n.notebookRuleLocationHint,
      ),
      NotebookTextField.keyword => (
        l10n.notebookRuleTypeKeyword,
        l10n.notebookRuleKeywordHint,
      ),
    };
    return NotebookRuleSheetFrame(
      title: title,
      result: _result,
      children: <Widget>[
        TextField(
          controller: _text,
          autofocus: true,
          maxLength: 40,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (_) {
            final result = _result;
            if (result != null) Navigator.of(context).pop(result);
          },
        ),
      ],
    );
  }
}

/// 图片与附件：四选一。
class _MediaRuleEditor extends StatefulWidget {
  const _MediaRuleEditor({this.initial});

  final NotebookMediaRule? initial;

  @override
  State<_MediaRuleEditor> createState() => _MediaRuleEditorState();
}

class _MediaRuleEditorState extends State<_MediaRuleEditor> {
  late NotebookMediaKind _kind =
      widget.initial?.kind ?? NotebookMediaKind.image;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return NotebookRuleSheetFrame(
      title: l10n.notebookRuleTypeMedia,
      result: NotebookMediaRule(_kind),
      children: <Widget>[
        for (final kind in NotebookMediaKind.values)
          ExpressiveChoiceTile(
            label: notebookMediaKindLabel(l10n, kind),
            selected: _kind == kind,
            onTap: () => setState(() => _kind = kind),
          ),
      ],
    );
  }
}

/// 封面与置顶：二选一。
class _FlagRuleEditor extends StatefulWidget {
  const _FlagRuleEditor({this.initial});

  final NotebookFlagRule? initial;

  @override
  State<_FlagRuleEditor> createState() => _FlagRuleEditorState();
}

class _FlagRuleEditorState extends State<_FlagRuleEditor> {
  late NotebookFlagKind _kind =
      widget.initial?.kind ?? NotebookFlagKind.hasCover;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return NotebookRuleSheetFrame(
      title: l10n.notebookRuleTypeFlag,
      result: NotebookFlagRule(_kind),
      children: <Widget>[
        for (final kind in NotebookFlagKind.values)
          ExpressiveChoiceTile(
            label: notebookFlagKindLabel(l10n, kind),
            selected: _kind == kind,
            onTap: () => setState(() => _kind = kind),
          ),
      ],
    );
  }
}
