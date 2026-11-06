import 'package:flutter/material.dart';

import '../../../../app/theme/app_radii.dart';
import '../../../../l10n/app_localizations.dart';
import '../../models/diary_preview_style/diary_preview_style.dart';
import '../../viewmodels/diary_preview_resolved_style.dart';
import '../diary_preview/diary_preview_header.dart';

/// 阅读式编辑页的页头：头图、信息栏（标题上方或下方）、可编辑的标题与标题
/// 下分隔线，次序与间距同预览页（`DiaryPreviewContent`），放在正文编辑器
/// 的 `header` 里随正文一起滚动。
///
/// 与预览页的差别只有两处：标题是输入框（[title]，由页面给出，始终在，
/// 即使样式隐藏了标题——编辑时总得能改标题）；信息栏点按打开信息面板。
/// 页头自己按 [resolved] 留边与限宽（编辑器的 header 不套正文的左右
/// 内边距），通栏头图因此能贴边。末尾留出标题区到正文的距离
/// （[DiaryPreviewTitleStyle.bodyGap]），正文紧接着开始。
class DiaryReadingEditorHeader extends StatelessWidget {
  const DiaryReadingEditorHeader({
    super.key,
    required this.resolved,
    required this.title,
    this.cover,
    this.meta,
  });

  /// 已按编辑器实际宽度换算过的样式（`atWidth`）。
  final DiaryPreviewResolvedStyle resolved;

  /// 标题输入框。
  final Widget title;

  /// 头图；没有头图来源或样式不显示头图时为 null。
  final Widget? cover;

  /// 信息栏（已包好点按）；这篇在当前样式下没有可显示的信息、或信息栏在
  /// 正文之后时为 null（正文之后的信息栏由页尾显示）。
  final Widget? meta;

  @override
  Widget build(BuildContext context) {
    final style = resolved.style;
    final meta = this.meta;
    final position = style.meta.position;
    final metaAbove =
        meta != null && position == DiaryPreviewMetaPosition.aboveTitle;
    final metaBelow =
        meta != null && position == DiaryPreviewMetaPosition.belowTitle;
    // 标题总在，标题区总是存在：标题区到正文按样式留距离，开分隔线时线上、
    // 线下各一份。
    final bodyGap = style.title.bodyGap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ?cover,
        if (metaAbove)
          DiaryPreviewColumn(resolved: resolved, top: 14, child: meta),
        DiaryPreviewColumn(
          resolved: resolved,
          top: metaAbove ? 10 : 14,
          child: title,
        ),
        if (metaBelow)
          DiaryPreviewColumn(resolved: resolved, top: 10, child: meta),
        if (style.title.divider)
          DiaryPreviewColumn(
            resolved: resolved,
            top: bodyGap,
            child: DiaryPreviewTitleDivider.line(resolved),
          ),
        SizedBox(height: bodyGap),
      ],
    );
  }
}

/// 阅读式编辑页的信息栏：外观与预览页的信息栏相同（[child]），整块可点，
/// 点按打开信息面板（心情、天气、地点、标签、日记本、发表时间、封面都在
/// 那里改）。里面的胶囊与预览页一样自己响应（里层的点按先于整块胜出）：
/// “N 条留言”滚到留言区，标签打开搜索，日记本打开那本；点胶囊之外的地方
/// 打开面板，按压水波画在整块信息栏上。
class DiaryReadingMetaButton extends StatelessWidget {
  const DiaryReadingMetaButton({
    super.key,
    required this.onPressed,
    required this.child,
  });

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.diaryReadingEditInfo,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadii.input),
        child: child,
      ),
    );
  }
}
