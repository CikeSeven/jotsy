import '../../../core/database/app_database.dart';
import '../../diaries/viewmodels/diary_card_view_data.dart';
import '../../diaries/viewmodels/diary_leading_line.dart';

/// 目录行显示的标题：[fromContent] 为 true 时是顶替标题的正文第一行（行组件
/// 据此用常规字重与次要颜色，与真标题区分）。
typedef NotebookContentsTitle = ({String text, bool fromContent});

/// 目录行的标题（纯函数）：写了标题用标题；没写标题时与日记卡片同一口径取
/// 正文第一行（[DiaryLeadingLine]，跳过空行、压成单行、最长
/// [DiaryCardViewData.previewTextMaxLength]）；正文没有文字（只有图片或空
/// 文档）才退回 [untitled]。
///
/// 与卡片的不同之处：
/// - 不看“日记卡片样式 → 没有标题时用正文第一行作标题”开关。那个开关关掉时
///   卡片整行不显示标题，而目录是按名字找日记的列表，每行都要有可读的名字；
/// - 导图日记照样取第一行（中心主题没写字时是第一个分支主题）。卡片退回
///   “无标题”是因为下面紧接着画大纲、会重复，目录行没有大纲。
///
/// [sealed]（未解封的胶囊）时与卡片一样不露正文，没写标题就是 [untitled]。
NotebookContentsTitle notebookContentsTitle(
  NotebookContentsEntry entry, {
  required bool sealed,
  required String untitled,
}) {
  if (entry.title.trim().isNotEmpty) {
    return (text: entry.title, fromContent: false);
  }
  if (sealed) {
    return (text: untitled, fromContent: false);
  }
  final leading = DiaryLeadingLine.of(
    entry.leadingText,
    maxLength: DiaryCardViewData.previewTextMaxLength,
  );
  return leading == null
      ? (text: untitled, fromContent: false)
      : (text: leading.line, fromContent: true);
}
