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

/// 顶栏标题：[label] 为“日记”（改版前的样子），[date] 为这篇日记的日期，
/// [position] 为在翻页顺序中的位置（如“3 / 57”，单篇打开时退回“日记”）。
enum DiaryPreviewTopBarTitle { label, date, none, position }

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

/// 左右翻页的过渡：[slide] 两页并排平移（默认）；[stack] 新的一页盖上来、
/// 旧的一页原地缩小；[fade] 两页原地交叉淡入淡出。
enum DiaryPreviewPageTransition { slide, stack, fade }

/// 翻页灵敏度（阅读行为）：越往后越需要明显的横向滑动才翻页，竖着读时更
/// 不容易误翻。
enum DiaryPreviewSwipeSensitivity { sensitive, standard, strict }

/// 正文长图（高 ≥ 宽 × 3，如长截图）的显示方式（阅读行为）：[fold] 折叠成
/// 宽 : 高 = 2 : 3 的盒子、只露出顶部，点按进看图页（默认）；[full] 按列宽
/// 完整展开在正文里。
enum DiaryPreviewLongImageMode { fold, full }
