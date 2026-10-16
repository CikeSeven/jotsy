/// 日记预览页样式的枚举。
///
/// 枚举名即持久化值（设置键、备份与样式码里），改名会让已保存的选择失效；
/// 只能在末尾追加新值，旧版本读到不认识的值时回退该字段的默认值。
library;

/// 整页配色基调：[app] 跟随应用主题色；[mood] 取这篇日记心情对应的颜色；
/// [tag] 取首个标签的颜色；[custom] 为自定义色。没有心情、标签或自定义色时
/// 回到应用主题色。
enum DiaryPreviewColorSeed { app, mood, tag, custom }

/// 纸张（页面底色）：[theme] 为主题底色（改版前的样子），其余为内置纸色与
/// 自定义色。纸色与主题深浅相反时整页换成同一配色的另一种明暗，保证文字可读。
enum DiaryPreviewPaper { theme, warm, sepia, mint, gray, ink, custom }

/// 顶栏：[floating] 随滚动隐藏、往回滚即出现（改版前的样子）；[pinned] 常驻。
enum DiaryPreviewTopBarMode { floating, pinned }

/// 顶栏标题：[label] 为“日记”（改版前的样子），[date] 为这篇日记的日期。
enum DiaryPreviewTopBarTitle { label, date, none }

/// 阅读进度：[line] 在页面顶端画一条随滚动增长的细线。
enum DiaryPreviewProgress { none, line }

/// 头图：[banner] 通栏（改版前的样子），[inset] 两侧留边的圆角卡片，[hidden]
/// 不显示头图（正文里的图片照常显示）。
enum DiaryPreviewCoverMode { banner, inset, hidden }

/// 头图适配：[contain] 完整显示原图、上下或左右留出底色（改版前的样子）；
/// [cover] 铺满头图框并裁掉超出部分。
enum DiaryPreviewCoverFit { contain, cover }

/// 标题字重；[heavy] 为改版前的 w800。
enum DiaryPreviewTitleWeight { regular, medium, bold, heavy }

/// 标题对齐。
enum DiaryPreviewAlign { start, center }

/// 信息栏位置：标题下方（改版前的样子）、标题上方，或正文之后。
enum DiaryPreviewMetaPosition { belowTitle, aboveTitle, end }

/// 信息栏版式：[stacked] 时间、地点天气、胶囊各占一行（改版前的样子）；
/// [inline] 所有项目排成一段并以间隔点分开；[card] 收进一张信息卡。
enum DiaryPreviewMetaLayout { stacked, inline, card }

/// 心情与精力的呈现：[chip] 带底色的胶囊（改版前的样子），[plain] 纯文字。
enum DiaryPreviewChipStyle { chip, plain }

/// “最后编辑于”的时间格式：[precise] 为改版前的分钟级精确时间。
enum DiaryPreviewEditedFormat { precise, relative, full }
