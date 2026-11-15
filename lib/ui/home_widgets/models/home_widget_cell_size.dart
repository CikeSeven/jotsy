// 小组件在桌面上占几格，以及应用内预览按多大来画。
//
// 不同启动器一格的大小不一样；预览取常见手机竖屏的近似值，原生按实际尺寸
// 分档（`SizeMode.Responsive`，`WidgetSizes.kt`），两边的分档界线一致：
// 预览里看到的版式就是桌面上同样格数时的版式。

import 'dart:ui' show Size;

import '../../../core/services/home_widgets/home_widget_kind.dart';

enum HomeWidgetCellSize {
  s1x1(1, 1),
  s2x1(2, 1),
  s4x1(4, 1),
  s2x2(2, 2),
  s3x3(3, 3),
  s4x2(4, 2),
  s4x4(4, 4);

  const HomeWidgetCellSize(this.columns, this.rows);

  final int columns;
  final int rows;

  /// 按钮与标签上的写法，如“2×2”（不翻译）。
  String get label => '$columns×$rows';

  /// 预览尺寸（dp）：一格约 80×84，扣掉格间距。
  Size get previewSize => Size(80.0 * columns - 8, 84.0 * rows - 8);

  /// 某种类可用的尺寸（与 `res/xml/widget_info_*.xml` 的缩放范围一致），
  /// 第一个是放到桌面时的默认尺寸。
  static List<HomeWidgetCellSize> sizesOf(
    HomeWidgetKind kind,
  ) => switch (kind) {
    HomeWidgetKind.quickCapture => const <HomeWidgetCellSize>[
      s2x2,
      s1x1,
      s2x1,
      s4x1,
      s4x2,
    ],
    HomeWidgetKind.today => const <HomeWidgetCellSize>[s2x2, s2x1, s4x1, s4x2],
    HomeWidgetKind.anniversary => const <HomeWidgetCellSize>[
      s2x2,
      s1x1,
      s2x1,
      s4x2,
      s4x4,
    ],
    HomeWidgetKind.moodCalendar => const <HomeWidgetCellSize>[
      s3x3,
      s2x2,
      s4x2,
      s4x4,
    ],
    HomeWidgetKind.todos => const <HomeWidgetCellSize>[s4x2, s2x2, s4x4],
    HomeWidgetKind.onThisDay => const <HomeWidgetCellSize>[s2x2, s4x2, s4x4],
    HomeWidgetKind.recentDiaries => const <HomeWidgetCellSize>[s4x2, s4x4],
    HomeWidgetKind.writingStats => const <HomeWidgetCellSize>[s2x2, s4x2, s4x4],
    HomeWidgetKind.photoMemories => const <HomeWidgetCellSize>[
      s2x2,
      s1x1,
      s4x2,
      s4x4,
    ],
  };
}
