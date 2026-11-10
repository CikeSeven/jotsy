/// 首页栏（底部导航栏与四个 Tab 的顶栏）样式的枚举。
///
/// 枚举名即持久化值（设置键、备份与样式码里），改名会让已保存的选择失效；
/// 旧版本读到不认识的值时回退该字段的默认值（旧数据里已移除的
/// `tint: custom` 同样如此，回退中性）。
library;

/// 玻璃的底色：[neutral] 中性表面色；[theme] 向主题色容器色偏一点。
enum HomeBarTint { neutral, theme }

/// 底栏文字：[always] 始终显示；[selected] 只显示选中项；[never] 只有图标
/// （栏更矮、每项更窄）。
enum HomeBarLabelMode { always, selected, never }

/// 新建按钮（FAB）相对悬浮底栏的位置：[above] 浮在底栏上方；[inline] 并排
/// 放在底栏右侧。
enum HomeBarFabPlacement { above, inline }
