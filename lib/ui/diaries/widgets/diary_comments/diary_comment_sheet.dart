import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/expressive_motion.dart';
import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../../widgets/expressive_state_blend.dart';

/// 写留言面板的结果：去掉首尾空白的文字与可选心情。
@immutable
class DiaryCommentDraft {
  const DiaryCommentDraft({required this.content, this.mood});

  final String content;
  final String? mood;
}

/// 打开写留言 / 编辑留言面板；取消返回 null。
///
/// [title] 由调用方给出（新写时带“写下后 N 天”，编辑时为“编辑留言”）；
/// [moodOptions] 是用户的日记心情选项（与写日记时同一组）；[initial] 为要
/// 编辑的留言，内容与心情原样带入，没有改动时“保存”不可点。
Future<DiaryCommentDraft?> showDiaryCommentSheet(
  BuildContext context, {
  required String title,
  required List<String> moodOptions,
  DiaryCommentRow? initial,
}) {
  return showAppModalBottomSheet<DiaryCommentDraft>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxWidth: 640,
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => DiaryCommentSheet(
      title: title,
      moodOptions: moodOptions,
      initial: initial,
    ),
  );
}

/// 写留言面板：标题、心情一行（可不选）、多行输入框与“取消 / 保存”。
///
/// 输入框用普通文字键盘、自动获得焦点；面板自己按键盘高度垫底
/// （`showAppModalBottomSheet` 不处理键盘）。字数上限
/// [kDiaryCommentMaxLength]，接近上限时才显示计数。
class DiaryCommentSheet extends StatefulWidget {
  const DiaryCommentSheet({
    super.key,
    required this.title,
    required this.moodOptions,
    this.initial,
  });

  final String title;
  final List<String> moodOptions;
  final DiaryCommentRow? initial;

  @override
  State<DiaryCommentSheet> createState() => _DiaryCommentSheetState();
}

class _DiaryCommentSheetState extends State<DiaryCommentSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial?.content ?? '',
  )..addListener(_handleTextChanged);
  late String? _mood = widget.initial?.mood;

  /// 计数在剩下不到一成时才出现，平时不分散注意力。
  static const int _counterFrom = kDiaryCommentMaxLength * 9 ~/ 10;

  @override
  void dispose() {
    _text
      ..removeListener(_handleTextChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTextChanged() => setState(() {});

  bool get _canSave {
    final content = _text.text.trim();
    if (content.isEmpty) return false;
    final initial = widget.initial;
    return initial == null ||
        content != initial.content ||
        _mood != initial.mood;
  }

  void _save() {
    if (!_canSave) return;
    Navigator.of(
      context,
    ).pop(DiaryCommentDraft(content: _text.text.trim(), mood: _mood));
  }

  /// 心情选项里没有、但这条留言原来记着的心情（用户后来改了心情选项）也
  /// 列出来，编辑时不会悄悄丢掉。
  List<String> get _moods {
    final initial = widget.initial?.mood;
    return <String>[
      ...widget.moodOptions,
      if (initial != null && !widget.moodOptions.contains(initial)) initial,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: l10n.diaryCommentMoodLabel),
                  TextSpan(
                    text: ' · ${l10n.diaryCommentMoodOptional}',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final mood in _moods)
                  _MoodChoice(
                    mood: mood,
                    selected: mood == _mood,
                    // 再点一次已选的心情即取消：心情可以不选。
                    onTap: () =>
                        setState(() => _mood = mood == _mood ? null : mood),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _text,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              maxLength: kDiaryCommentMaxLength,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              buildCounter:
                  (
                    BuildContext context, {
                    required int currentLength,
                    required bool isFocused,
                    required int? maxLength,
                  }) => currentLength < _counterFrom
                  ? null
                  : Text('$currentLength/$maxLength'),
              decoration: InputDecoration(hintText: l10n.diaryCommentHint),
            ),
            const SizedBox(height: AppSpacing.m),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                  ),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: AppSpacing.s),
                FilledButton(
                  onPressed: _canSave ? _save : null,
                  child: Text(l10n.commonSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 一个可选的心情：选中时为主色容器底 + 主色描边的圆，选中态经
/// [ExpressiveStateBlend] 补间。未选中的底色与描边按 [AppGlassField] 跟随
/// “控件”材质（经典时透明底 + outlineVariant 细描边），选中色不变。
class _MoodChoice extends StatelessWidget {
  const _MoodChoice({
    required this.mood,
    required this.selected,
    required this.onTap,
  });

  final String mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glassField = AppGlassField.of(context);
    final restingFill =
        glassField?.fill ?? scheme.primaryContainer.withValues(alpha: 0);
    final restingSide =
        glassField?.border ?? BorderSide(color: scheme.outlineVariant);
    final selectedSide = BorderSide(color: scheme.primary, width: 1.5);
    return Semantics(
      button: true,
      selected: selected,
      label: mood,
      excludeSemantics: true,
      child: ExpressiveStateBlend(
        active: selected,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Text(
                mood,
                style: const TextStyle(fontSize: 20, height: 1),
              ),
            ),
          ),
        ),
        builder: (BuildContext context, double t, Widget? child) => Material(
          color: Color.lerp(restingFill, scheme.primaryContainer, t),
          shape: CircleBorder(
            side: BorderSide.lerp(restingSide, selectedSide, t),
          ),
          child: child,
        ),
      ),
    );
  }
}
