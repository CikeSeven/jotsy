// 日历显示选项用到的枚举。持久化存的是枚举名（`Enum.name`），
// 重命名枚举值等同于改存储格式：旧值会按未知名称回退到默认值。

/// 日期格样式：决定月/周网格里每一天画什么。
enum CalendarCellStyle {
  /// 有几篇画几个圆点（最多 3 个）。
  dot,

  /// 心情 emoji（默认，延续旧版日历）。
  mood,

  /// 按篇数或字数分档的主色填充。
  heat,

  /// 当天代表图铺满格子。
  photo,

  /// 当天前 3 个标签的颜色点。
  tags,
}

/// 热力样式的取值依据。
enum CalendarHeatBasis { entries, words }

/// 心情样式下一天有多篇日记时的显示方式：取平均会抹平一天里的情绪起伏，
/// 逐篇则按时间顺序并排显示（最多 3 个）。
enum CalendarMoodAggregation { average, each }

/// 一周起始日；[locale] 跟随应用语言区域（中文周一、英文周日）。应用只
/// 支持中英文，两种语言区域都不以周六起始，不提供该选项。
enum CalendarWeekStart { locale, monday, sunday }

/// 打开日历页时的网格格式；[remember] 沿用上次切换到的月/周格式。
enum CalendarDefaultFormat { month, week, remember }

/// 月/周两种网格格式（持久化用，避免模型层依赖 table_calendar）。
enum CalendarGridFormat { month, week }

/// 选中日日记的展示方式：时间线（默认，轻量）或与日记列表相同的卡片。
enum CalendarDayContentStyle { timeline, cards }

/// 年视图每个日期小格的着色依据。
enum CalendarYearBasis { mood, entries, words }

/// 中国历法相关内容的显示方式，用于农历小字（农历日、节气与传统节日）
/// 与法定节假日（休/班）两项选项；[locale] 跟随应用语言区域（中文显示、
/// 英文不显示）。模型层不知道语言区域，解析在 UI 层。
enum CalendarLunarMode { locale, always, never }
