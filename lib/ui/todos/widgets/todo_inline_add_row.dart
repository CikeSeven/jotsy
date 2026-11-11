import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../providers/todo_providers.dart';
import '../viewmodels/todo_quick_parse.dart';
import 'todo_quick_add_sheet.dart' show TodoQuickAddPreset;
import 'todo_quick_input.dart';
import 'todo_bare_input.dart';

/// 列表末尾的内联新建：平时是一行虚化的“+ 添加待办”，点按变成输入框并
/// 聚焦；回车按 [preset]（当前视图的清单 / 今天 / 高优先级）与智能识别的
/// 结果写库，清空后保持焦点接着记；失去焦点且没有内容时收回占位行。
///
/// 状态：idle（占位行）↔ editing（输入框）。[onEditingChanged] 告诉页面
/// 是否在输入：页面据此给列表留出键盘高度（首页 Scaffold 不随键盘缩小），
/// 输入框聚焦后由 EditableText 自己滚到可见处。
///
/// 失焦：收起软键盘（返回键 / 手势，手机上键盘从有到无且输入框仍有焦点）
/// 或点在输入卡片之外时失焦；没有内容就收回占位行，有内容时留着输入卡片、
/// 描边退回不聚焦的样子。回车提交不让输入框失焦（`onEditingComplete` 置空
/// 操作），键盘不会先收起再弹出。键盘高度读窗口本身（`View.viewInsets`）：
/// 首页挂着 `KeyboardShield`，MediaQuery 里的键盘高度恒为打开首页时的值。
class TodoInlineAddRow extends ConsumerStatefulWidget {
  const TodoInlineAddRow({
    super.key,
    required this.preset,
    this.onEditingChanged,
  });

  final TodoQuickAddPreset preset;
  final ValueChanged<bool>? onEditingChanged;

  @override
  ConsumerState<TodoInlineAddRow> createState() => _TodoInlineAddRowState();
}

class _TodoInlineAddRowState extends ConsumerState<TodoInlineAddRow>
    with WidgetsBindingObserver {
  final TodoQuickInputController _controller = TodoQuickInputController();
  final FocusNode _focus = FocusNode();
  final Set<TodoQuickTokenKind> _ignored = <TodoQuickTokenKind>{};
  bool _editing = false;
  bool _saving = false;

  /// 聚焦期间软键盘是否出现过：只有“出现过又收起”才算用户收起了键盘，
  /// 刚聚焦、键盘还没升起来的那几帧不算。
  bool _keyboardSeen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focus.addListener(_onFocusChanged);
    _controller.addListener(_onTextChanged);
  }

  @override
  void didChangeMetrics() {
    if (!AppPlatform.isMobile || !_focus.hasFocus) {
      _keyboardSeen = false;
      return;
    }
    final keyboard = View.of(context).viewInsets.bottom;
    if (keyboard > 0) {
      _keyboardSeen = true;
    } else if (_keyboardSeen) {
      _keyboardSeen = false;
      _focus.unfocus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 卸载发生在一帧收尾、树已锁住时，父级在回调里 setState 会断言失败：
    // 挪到这一帧结束后再通知（父级自己判断 mounted）。
    final onEditingChanged = widget.onEditingChanged;
    if (_editing && onEditingChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => onEditingChanged(false),
      );
    }
    _focus.removeListener(_onFocusChanged);
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  TodoQuickParse _parse() => todoQuickParseOf(
    _controller.text,
    enabled: ref.read(todoSettingsProvider).smartParse,
    today: _today,
    lists: ref.read(todoListsProvider).value ?? const <TodoListRow>[],
    ignore: _ignored,
  );

  void _onTextChanged() {
    if (_controller.text.isEmpty) _ignored.clear();
    final parse = _parse();
    _controller.highlights = <TextRange>[
      for (final token in parse.tokens) token.range,
    ];
    setState(() {});
  }

  void _onFocusChanged() {
    if (!_focus.hasFocus) _keyboardSeen = false;
    if (!_focus.hasFocus && _controller.text.trim().isEmpty && !_saving) {
      _setEditing(false);
    } else {
      // 聚焦与否换描边颜色。
      setState(() {});
    }
  }

  void _setEditing(bool value) {
    if (_editing == value) return;
    setState(() => _editing = value);
    widget.onEditingChanged?.call(value);
    if (value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    final parse = _parse();
    final raw = _controller.text.trim();
    // 整段都被识别走了（如只写了“明天”）时，用原文当标题，不吞掉输入。
    final title = parse.title.isNotEmpty ? parse.title : raw;
    if (title.isEmpty) return;
    final preset = widget.preset;
    final date = parse.date ?? preset.dueDate;
    setState(() => _saving = true);
    try {
      await ref
          .read(appDatabaseProvider)
          .createTodo(
            TodoInput(
              title: title,
              listId: parse.listId ?? preset.listId,
              priority: parse.priority ?? preset.priority,
              dueDate: date,
              dueMinute: date == null ? null : parse.minute,
              linkedDiaryId: preset.linkedDiaryId,
            ),
          );
      _ignored.clear();
      _controller.clear();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(AppRadii.input);
    final parse = _editing ? _parse() : null;
    final lists = ref.watch(todoListsProvider).value ?? const <TodoListRow>[];
    // 订阅设置：关掉智能识别时高亮随之消失。
    ref.watch(todoSettingsProvider.select((s) => s.smartParse));

    final placeholder = InkWell(
      key: const ValueKey<String>('inline_add_idle'),
      borderRadius: radius,
      onTap: () => _setEditing(true),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: ExpressiveSurfaces.cardBorderColor(scheme),
            width: 0.8,
          ),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 16,
              child: FaIcon(
                FontAwesomeIcons.plus,
                size: 14,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.l),
            Expanded(
              child: Text(
                l10n.todoInlineAddHint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // 整张输入卡片算作输入框的点按区域：点发送键、识别结果的 × 不让
    // 输入框失焦（onTapOutside 只认卡片之外）。
    final field = TextFieldTapRegion(
      key: const ValueKey<String>('inline_add_editing'),
      child: Material(
        color: ExpressiveSurfaces.cardColor(scheme),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: _focus.hasFocus
              ? BorderSide(color: scheme.primary, width: 1.2)
              : BorderSide(
                  color: ExpressiveSurfaces.cardBorderColor(scheme),
                  width: 0.8,
                ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.xs,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  FaIcon(
                    FontAwesomeIcons.plus,
                    size: 14,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.l),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      maxLength: 500,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => unawaited(_submit()),
                      // 回车不失焦：提交后接着记下一条，键盘不收起再弹出。
                      onEditingComplete: () {},
                      onTapOutside: (_) => _focus.unfocus(),
                      contextMenuBuilder: appTextContextMenuBuilder,
                      style: theme.textTheme.bodyLarge,
                      decoration: todoBareInputDecoration(
                        hintText: l10n.todoQuickAddHint,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.todoQuickAddSubmit,
                    onPressed: _controller.text.trim().isEmpty || _saving
                        ? null
                        : () => unawaited(_submit()),
                    icon: FaIcon(
                      FontAwesomeIcons.arrowUp,
                      size: 15,
                      color: _controller.text.trim().isEmpty
                          ? scheme.onSurfaceVariant
                          : scheme.primary,
                    ),
                  ),
                ],
              ),
              if (parse != null && !parse.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 30,
                    bottom: AppSpacing.s,
                  ),
                  child: TodoParsedChips(
                    parse: parse,
                    today: _today,
                    lists: lists,
                    onDismiss: (TodoQuickTokenKind kind) {
                      _ignored.add(kind);
                      _onTextChanged();
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return AnimatedSwitcher(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      switchInCurve: ExpressiveMotion.effects,
      switchOutCurve: ExpressiveMotion.exit,
      child: _editing ? field : placeholder,
    );
  }
}
