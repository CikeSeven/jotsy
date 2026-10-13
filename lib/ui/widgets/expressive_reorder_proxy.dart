import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/expressive_motion.dart';
import '../../app/theme/expressive_surfaces.dart';

/// 可排序列表（ReorderableListView）拖起态的统一外观。
///
/// 默认 proxyDecorator 是直角、elevation 6 的 Material，与 Expressive 圆角卡片
/// 和极淡投影体系不一致。这里改为卡片表面 + 16dp 圆角（与 ListTile 主题一致），
/// 投影随拖起进度从 0 平滑升到 3，落下时同样回落。
Widget expressiveReorderProxyDecorator(
  Widget child,
  int index,
  Animation<double> animation,
) {
  return AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (BuildContext context, Widget? child) {
      final colors = Theme.of(context).colorScheme;
      final lift = ExpressiveMotion.effects.transform(animation.value);
      return Material(
        color: ExpressiveSurfaces.cardColor(colors),
        elevation: lerpDouble(0, 3, lift)!,
        shadowColor: colors.shadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    },
  );
}
