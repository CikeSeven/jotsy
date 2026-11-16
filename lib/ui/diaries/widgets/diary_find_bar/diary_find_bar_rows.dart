import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/services/app_platform.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/desktop_horizontal_scroll.dart';
import '../../../widgets/search_pill_field.dart';
import '../../../widgets/width_layout_builder.dart';
import '../../controllers/diary_find_replace.dart';
import '../diary_search_chip.dart';

/// 查找框行尾的计数（[DiaryFindBar] 的一部分）：第几处 / 共几处（超过
/// 上限时总数带“+”），没有结果、正则写错时换成提示（写错为错误色）；
/// 查找框为空或查找已关（收起的过渡里）时不占地方。读屏时随变化播报。
class DiaryFindCount extends StatelessWidget {
  const DiaryFindCount({super.key, required this.find});

  final DiaryFindReplace find;

  @override
  Widget build(BuildContext context) {
    if (find.query.isEmpty || !find.isOpen) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final String label;
    var color = scheme.onSurfaceVariant;
    if (find.invalid) {
      label = l10n.diaryFindInvalidRegex;
      color = scheme.error;
    } else if (find.matches.isEmpty) {
      label = l10n.diaryFindNoResults;
    } else {
      label = l10n.diaryFindPosition(
        '${find.currentIndex + 1}',
        '${find.matches.length}${find.truncated ? '+' : ''}',
      );
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6),
      child: Semantics(
        liveRegion: true,
        // 长提示（俄语的“正则有误”）不挤掉输入框：最宽 [_maxWidth]，超出省略。
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Text(
            label,
            key: const ValueKey<String>('diary-find-count'),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }

  static const double _maxWidth = 96;
}

/// 查找选项一排胶囊（与搜索页的筛选胶囊同一外观，[DiarySearchChip]）：
/// 左侧是正则表达式、区分大小写、全词匹配三个开关（窄屏或长文案时横向
/// 滚动），[canReplace] 时右端固定一个展开 / 收起替换一行的“替换”——它是
/// 另一种模式，不能跟着开关一起被挤出卡片。
class DiaryFindOptionsRow extends StatelessWidget {
  const DiaryFindOptionsRow({
    super.key,
    required this.find,
    this.canReplace = true,
  });

  final DiaryFindReplace find;
  final bool canReplace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = find.query;
    final options = <Widget>[
      DiarySearchChip(
        key: const ValueKey<String>('diary-find-regex'),
        label: l10n.diaryFindOptionRegex,
        active: query.regex,
        leading: const FaIcon(FontAwesomeIcons.asterisk),
        onTap: () => find.setOptions(regex: !query.regex),
      ),
      DiarySearchChip(
        key: const ValueKey<String>('diary-find-case'),
        label: l10n.diaryFindOptionMatchCase,
        active: query.caseSensitive,
        leading: const FaIcon(FontAwesomeIcons.font),
        onTap: () => find.setOptions(caseSensitive: !query.caseSensitive),
      ),
      DiarySearchChip(
        key: const ValueKey<String>('diary-find-word'),
        label: l10n.diaryFindOptionWholeWord,
        active: query.wholeWord,
        leading: const FaIcon(FontAwesomeIcons.textWidth),
        onTap: () => find.setOptions(wholeWord: !query.wholeWord),
      ),
    ];
    return Row(
      children: <Widget>[
        Expanded(
          child: DesktopHorizontalScroll(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: Row(
                children: <Widget>[
                  for (var i = 0; i < options.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: 8),
                    options[i],
                  ],
                ],
              ),
            ),
          ),
        ),
        // 滚动区与固定的“替换”之间留一道空隙：被截断的胶囊不贴着它。
        const SizedBox(width: 8),
        if (canReplace)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: DiarySearchChip(
              key: const ValueKey<String>('diary-find-replace-toggle'),
              label: l10n.diaryFindOptionReplace,
              active: find.replaceVisible,
              leading: const FaIcon(FontAwesomeIcons.rightLeft),
              onTap: () => find.setReplaceVisible(!find.replaceVisible),
            ),
          )
        else
          const SizedBox(width: 4),
      ],
    );
  }
}

/// 替换一行：替换框（开着正则时提示 `$1` 引用分组）+ “替换”（换掉当前
/// 这一处并停到下一处）+ “全部替换”。没有匹配时两个按钮停用。桌面上在
/// 替换框里按 Enter 等于“替换”；手机的确认键只收起键盘（避免误换）。
class DiaryFindReplaceRow extends StatelessWidget {
  const DiaryFindReplaceRow({
    super.key,
    required this.find,
    required this.controller,
    required this.focusNode,
    required this.fill,
    required this.idleOutline,
    required this.onReplaceAll,
  });

  final DiaryFindReplace find;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color fill;
  final Color idleOutline;
  final VoidCallback onReplaceAll;

  /// 替换框与按钮同排时替换框至少要这么宽，否则按钮换到下一行。
  static const double _minInlineFieldWidth = 160;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = find.matches.isNotEmpty;
    final field = SearchPillField(
      key: const ValueKey<String>('diary-replace-field'),
      controller: controller,
      focusNode: focusNode,
      icon: FontAwesomeIcons.rightLeft,
      hintText: find.query.regex
          ? l10n.diaryReplaceHintRegex
          : l10n.diaryReplaceHint,
      fill: fill,
      idleOutline: idleOutline,
      textInputAction: TextInputAction.done,
      keepFocusOnSubmit: AppPlatform.isDesktop,
      onChanged: (value) => find.replacement = value,
      onSubmitted: AppPlatform.isDesktop ? (_) => find.replaceCurrent() : null,
      onClear: () {
        controller.clear();
        find.replacement = '';
        focusNode.requestFocus();
      },
    );
    final buttons = <Widget>[
      TextButton(
        key: const ValueKey<String>('diary-replace-one'),
        onPressed: enabled ? find.replaceCurrent : null,
        child: Text(l10n.diaryReplaceOne),
      ),
      TextButton(
        key: const ValueKey<String>('diary-replace-all'),
        onPressed: enabled ? onReplaceAll : null,
        child: Text(l10n.diaryReplaceAll),
      ),
    ];
    // 窄屏、长文案（俄语）或放大字号时两个按钮会把替换框挤得太窄：按钮
    // 估计的宽度放不下就换到替换框下面一行、靠右。
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 4, 0),
      child: WidthLayoutBuilder(
        builder: (BuildContext context, double width) {
          final buttonsWidth = _buttonsWidth(context, <String>[
            l10n.diaryReplaceOne,
            l10n.diaryReplaceAll,
          ]);
          if (width - buttonsWidth - 4 >= _minInlineFieldWidth) {
            return Row(
              children: <Widget>[
                Expanded(child: field),
                const SizedBox(width: 4),
                ...buttons,
              ],
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: field,
              ),
              const SizedBox(height: 4),
              Wrap(alignment: WrapAlignment.end, children: buttons),
            ],
          );
        },
      ),
    );
  }

  /// 文字按钮的估计宽度：文字宽加主题按钮的左右内边距（12 + 12），且不
  /// 小于主题的最小宽度 64（Material 3 `TextButton` 的默认值）。
  static double _buttonsWidth(BuildContext context, List<String> labels) {
    final style = Theme.of(context).textTheme.labelLarge;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var total = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textScaler: scaler,
        textDirection: direction,
        maxLines: 1,
      )..layout();
      total += math.max(64, painter.width + 24);
      painter.dispose();
    }
    return total;
  }
}
