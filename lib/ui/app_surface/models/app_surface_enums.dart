/// “背景与材质”设置的枚举。
///
/// 枚举名即持久化值（设置键 `app.settings.app_surface` 与备份里），改名会让
/// 已保存的选择失效；只能在末尾追加新值，旧版本读到不认识的值时回退该字段
/// 的默认值（认不出的区域 / 组件键整项忽略）。
library;

/// 一块背景的种类：[none] 不画背景（沿用主题表面色）；[color] 纯色；
/// [image] 用户导入的图片（托管在 `app_backgrounds/`）。
enum AppBackgroundKind { none, color, image }

/// 可以单独设置背景的区域。
///
/// - [diaries] / [calendar] / [explore]：首页对应的 Tab；
/// - [settings]：设置 Tab 与全部设置子页；
/// - [editor]：编辑页、发表页、模板编辑页；
/// - [preview]：预览页（仅当预览样式的纸张为“跟随主题”时，用户自定义的
///   纸张颜色优先）；
/// - [other]：其余二级页（搜索、日记本、纪念日、草稿箱、归档、回收站等）。
enum AppBackgroundArea {
  diaries,
  calendar,
  explore,
  settings,
  editor,
  preview,
  other,
}

/// 区域背景的取值方式：[follow] 跟随全局背景；[off] 这个区域不画背景；
/// [custom] 用区域自己的背景。
enum AppAreaBackgroundMode { follow, off, custom }

/// 组件材质：[classic] 经典实色（改版前的样子）；[glass] 毛玻璃，透出下方的
/// 背景与内容。
enum AppGlassMode { classic, glass }

/// 可以单独切换材质的组件类别：顶栏、编辑器工具栏、底部面板、对话框、
/// 卡片、控件（按钮组、输入框等）。
enum AppGlassComponent { topBars, toolbar, sheets, dialogs, cards, controls }

/// 某类组件的材质覆盖：[follow] 跟随整体材质；[classic] / [glass] 固定为
/// 对应材质，不随整体切换。
enum AppGlassOverride { follow, classic, glass }

/// 玻璃的底色：[neutral] 中性表面色；[theme] 向主题色容器色偏一点；
/// [custom] 自定义色（未设颜色时按 [neutral] 解读）。
enum AppGlassTint { neutral, theme, custom }
