import 'package:flutter/material.dart';

import '../../app_surface/widgets/on_glass.dart';

/// 同步界面里面板 / 卡片上“凹槽块”的底色（配对插图的设备块、安全说明块、
/// 二维码倒计时胶囊）。
///
/// - 玻璃上：`OnGlass.wellColor`（半透明叠色，透出玻璃）；
/// - 亮色：`surfaceContainerLow`——面板与卡片本身是 `surfaceContainerLowest`，
///   低一档已经看得出层次；
/// - 暗色：`surfaceContainerHigh`——暗色主题下底部面板与卡片的底色就是
///   `surfaceContainerLow`（见 `ExpressiveSurfaces.bottomSheetTheme` /
///   `cardColor`），再用 `surfaceContainerLow` 会与底色完全相同、块看不见，
///   所以升一档到 `surfaceContainerHigh`（跳过与底色只差一点的
///   `surfaceContainer`）。
Color lanSyncWellColor(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  if (OnGlass.of(context)) return OnGlass.wellColor(colors);
  return colors.brightness == Brightness.light
      ? colors.surfaceContainerLow
      : colors.surfaceContainerHigh;
}
