import 'package:flutter/material.dart';
import 'dart:async';
import '../../diaries/widgets/diary_editor/diary_editor.dart';
import '../../diaries/controllers/diary_editor_insert.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../diaries/providers/diary_saved_colors_provider.dart';
import '../../diaries/providers/diary_typography_provider.dart';
import '../../diaries/widgets/diary_floating_toolbar_surface.dart';
import '../../diaries/widgets/diary_mobile_toolbar.dart';
import '../controllers/diary_template_editor_controller.dart';
import '../widgets/diary_template_variable_bar.dart';

/// 模板编辑页的“内容”标签：标题格式、插入变量条与正文。
///
/// 正文是独立的 AppFlowy 编辑器（自带滚动），不走日记编辑页的光标跟随机制；
/// 键盘弹起且正文有焦点时（打开“始终显示工具栏”后一直），底部显示与日记
/// 编辑页同一套悬浮工具栏，但去掉图片、视频、附件、录音与插入时间——模板
/// 里不能有媒体，时间应当用变量。
///
/// 变量插到最后一个获得焦点的输入框（标题或正文）的光标处；变量面板会抢走
/// 焦点，插入后把焦点还回去。
class DiaryTemplateEditorContentTab extends ConsumerStatefulWidget {
  const DiaryTemplateEditorContentTab({
    super.key,
    required this.controller,
    required this.keyboardVisible,
  });

  final DiaryTemplateEditorController controller;

  /// 软键盘是否弹起。由页面在 Scaffold 之上读取：Scaffold 会把键盘高度从
  /// body 的 MediaQuery 里扣掉，这里读不到。
  final bool keyboardVisible;

  /// 模板正文工具栏里不出现的工具。
  static const Set<DiaryToolbarItem> excludedToolbarItems = <DiaryToolbarItem>{
    DiaryToolbarItem.image,
    DiaryToolbarItem.video,
    DiaryToolbarItem.attachment,
    DiaryToolbarItem.recording,
    DiaryToolbarItem.currentTime,
  };

  @override
  ConsumerState<DiaryTemplateEditorContentTab> createState() =>
      _DiaryTemplateEditorContentTabState();
}

class _DiaryTemplateEditorContentTabState
    extends ConsumerState<DiaryTemplateEditorContentTab> {
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _bodyFocus = FocusNode();
  // 包住悬浮工具栏，自身不可获得焦点：颜色面板的颜色代码输入框拿到焦点时
  // 正文失焦，工具栏仍须留着，否则输入框随之卸载。
  final FocusNode _toolbarFocus = FocusNode(
    debugLabel: 'template-floating-toolbar',
    canRequestFocus: false,
    skipTraversal: true,
  );
  bool _lastFocusedBody = true;

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(_trackFocus);
    _bodyFocus.addListener(_trackFocus);
    _toolbarFocus.addListener(_trackFocus);
  }

  void _trackFocus() {
    if (_titleFocus.hasFocus) _lastFocusedBody = false;
    if (_bodyFocus.hasFocus) _lastFocusedBody = true;
    // 工具栏只在正文（或工具栏里的输入框）有焦点时出现。
    setState(() {});
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    _bodyFocus.dispose();
    _toolbarFocus.dispose();
    super.dispose();
  }

  void _insert(String token) {
    if (_lastFocusedBody) {
      unawaited(
        insertDiaryEditorText(widget.controller.body, token).then((_) {
          if (mounted) _bodyFocus.requestFocus();
        }),
      );
      return;
    }
    final title = widget.controller.titlePattern;
    final text = title.text;
    final selection = title.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    title.value = TextEditingValue(
      text: text.replaceRange(start, end, token),
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    _titleFocus.requestFocus();
  }

  List<DiaryToolbarItem> _toolbarOrder(SettingsService? settings) {
    final order = decodeDiaryToolbarOrder(settings?.diaryToolbarOrderRaw);
    final hidden = decodeDiaryToolbarHiddenItems(
      settings?.diaryToolbarHiddenItemsRaw,
    );
    return filterEnabledDiaryToolbarOrder(order, hidden)
        .where(
          (item) => !DiaryTemplateEditorContentTab.excludedToolbarItems
              .contains(item),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final appearance = ref.watch(diaryTextAppearanceProvider);
    final titleStyle = appearance.titleStyle(theme.textTheme.headlineSmall);
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    final order = _toolbarOrder(settings);
    // 焦点在工具栏内（颜色代码输入框）时不看键盘：交接焦点时输入法可能先收起
    // 再弹出，键盘短暂消失也不能卸载工具栏（与日记编辑页同一口径）。打开
    // “始终显示工具栏”后不看键盘与焦点，接实体键盘时也能排版。
    final alwaysVisible = settings?.isDiaryToolbarAlwaysVisible ?? false;
    final showToolbar =
        (alwaysVisible ||
            (widget.keyboardVisible && _bodyFocus.hasFocus) ||
            _toolbarFocus.hasFocus) &&
        order.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.m,
            AppSpacing.l,
            AppSpacing.s,
          ),
          child: TextField(
            controller: widget.controller.titlePattern,
            focusNode: _titleFocus,
            style: titleStyle,
            maxLength: 200,
            buildCounter:
                (
                  BuildContext context, {
                  required int currentLength,
                  required bool isFocused,
                  int? maxLength,
                }) => null,
            decoration: InputDecoration(
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
              hintText: l10n.diaryTemplateEditorTitleHint,
              hintStyle: titleStyle?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        DiaryTemplateVariableBar(onInsert: _insert),
        Expanded(
          // 边距交给编辑器本身：段落把手画在页面左边距里，边距包在外面
          // 时把手只能压在文字上。
          child: DiaryEditor(
            controller: widget.controller.body,
            appearance: appearance,
            focusNode: _bodyFocus,
            placeholder: l10n.diaryTemplateEditorBodyHint,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            header: const SizedBox(height: 12),
            footer: const SizedBox(height: 24),
          ),
        ),
        if (showToolbar)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              kDiaryFloatingToolbarInset,
              0,
              kDiaryFloatingToolbarInset,
              AppSpacing.s,
            ),
            child: DiaryFloatingToolbarSurface(
              child: Focus(
                focusNode: _toolbarFocus,
                child: DiaryFloatingToolbar(
                  controller: widget.controller.body,
                  order: order,
                  maxPanelExtent: MediaQuery.sizeOf(context).height / 3,
                  savedColors: ref.watch(diarySavedColorsProvider),
                  onEditSavedColors: ref
                      .read(diarySavedColorsProvider.notifier)
                      .edit,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
