/// 首页栏（底部导航栏与四个 Tab 的顶栏）样式的枚举。
///
/// 枚举名即持久化值（设置键、备份与样式码里），改名会让已保存的选择失效；
/// 只能在末尾追加新值，旧版本读到不认识的值时回退该字段的默认值。
library;

/// 栏的材质：[solid] 实色（改版前的样子）；[glass] 毛玻璃，底栏变为悬浮的
/// 圆角胶囊，顶栏可选同样透出下方内容。
enum HomeBarMaterial { solid, glass }

/// 玻璃的底色：[neutral] 中性表面色；[theme] 向主题色容器色偏一点；
/// [custom] 自定义色（未设颜色时按 [neutral] 解读）。
enum HomeBarTint { neutral, theme, custom }

/// 底栏文字：[always] 始终显示（改版前的样子）；[selected] 只显示选中项；
/// [never] 只有图标。实色与玻璃两种材质都适用。
enum HomeBarLabelMode { always, selected, never }

/// 选中指示器：[capsule] 图标后的胶囊（改版前的样子）；[block] 盖住整个
/// 选中项的圆角块；[none] 不画指示器，只靠颜色区分。
enum HomeBarIndicator { capsule, block, none }

/// 新建按钮（FAB）相对悬浮底栏的位置：[above] 浮在底栏上方（改版前的
/// 样子）；[inline] 并排放在底栏右侧。只在玻璃材质下有意义。
enum HomeBarFabPlacement { above, inline }

/// 描边 / 分隔线的颜色来源：[theme] 跟随主题的 outlineVariant（改版前的
/// 细线）；[highlight] 明亮的玻璃边缘高光；[primary] 主题色；[custom] 自定义色
/// （未设颜色时按 [theme] 解读）。
enum HomeBarLineColor { theme, highlight, primary, custom }
