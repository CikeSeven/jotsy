/// 日记卡片样式的枚举。
///
/// 持久化按 `Enum.name` 存取（见 diary_card_style_json.dart）：改名即改存储
/// 格式，新增值只能追加；旧版本或备份里出现未知的名字时，只让该字段回退到
/// 默认值。
library;

/// 样式作用的布局模式。
///
/// 与页面层的 `DiaryLayoutMode` 一一对应；模型层不依赖页面枚举，由渲染层
/// 负责映射。
enum DiaryCardMode { list, waterfall }

/// 颜色来源。
///
/// [theme] 表示沿用默认外观：每个颜色位各自取原本的主题语义色（卡片表面、
/// 描边、阴影、文字各不相同），因此默认样式与改版前逐像素一致。
enum DiaryCardColorSource {
  theme,
  primary,
  secondary,
  tertiary,
  mood,
  firstTag,
  custom,
}

enum DiaryCardGradientDirection { vertical, horizontal, diagonal }

/// 卡片强调条：贴在卡片起始边或顶边，由卡片圆角裁切。
enum DiaryCardAccentBar { none, start, top }

/// 阴影样式。[themed] 是改版前的默认多层投影（亮色两到三层、暗色一层）。
enum DiaryCardShadowStyle { themed, none, soft, floating, custom }

/// 标题字重。内置 HarmonyOS 字体只有 400/500/700 三个字重，更重的取值会
/// 落回 700，因此只提供三档。
enum DiaryCardTitleWeight { regular, medium, bold }

/// 摘要行高档位，在各模式的基础行高上加减。
enum DiaryCardLineHeight { compact, standard, relaxed }

enum DiaryCardTextAlign { start, center }

/// 卡片正文的区块；顺序可由用户拖拽调整。
enum DiaryCardBlock { eyebrow, title, tags, preview, footer }

enum DiaryCardTagStyle { chip, plain, dot }

/// 置顶徽章：[standard] 为改版前的样子（列表“图钉 + 置顶”，瀑布流仅图钉）。
enum DiaryCardPinnedBadge { standard, iconOnly, hidden }

/// 没有封面时在封面位置显示的占位。
enum DiaryCardCoverFallback { none, dateBlock, moodTile }

/// 眉线日期格式。[eyebrow] 即改版前的“10月5日 · 周一”。
enum DiaryCardDateFormat { eyebrow, full, numeric, relative }

enum DiaryCardDateSource { created, updated }

/// 底栏时间。[relativeUpdated] 是改版前的“3 小时前”。
enum DiaryCardFooterTime { relativeUpdated, absoluteUpdated, created, hidden }

/// 心情与天气的呈现：[stamp] 为带底色的微胶囊印章，[plain] 只画图标。
enum DiaryCardIndicatorStyle { stamp, plain }

/// 心情与天气所在的位置。[cover] 叠在封面角上；没有封面时回退到该模式的
/// 默认位置。
enum DiaryCardMetaPosition { eyebrow, footer, cover }

/// 封面位置。瀑布流只支持 [top]、[background] 与 [hidden]。
enum DiaryCardCoverPosition { start, end, top, background, hidden }

/// 列表侧边封面的形状。
enum DiaryCardCoverShape { square, landscape, portrait, circle }
