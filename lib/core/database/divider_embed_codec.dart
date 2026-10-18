/// 正文分隔线嵌入，沿用 Quill 水平线的约定 `{"divider": "hr"}`，不带数据。
///
/// 导入的 HTML `<hr>`、Markdown `---` 与手机笔记的分隔线都写成它；编辑页、
/// 预览页与发布页由 `DiaryDividerEmbedBuilder` 渲染，导出时成为各格式的
/// 分隔线（`ExportBlockKind.divider`）。
const String diaryDividerEmbedType = 'divider';

/// 一条分隔线的嵌入数据。
const Map<String, Object?> diaryDividerEmbed = {diaryDividerEmbedType: 'hr'};
