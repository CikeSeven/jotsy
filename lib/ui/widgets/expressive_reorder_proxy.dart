import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/expressive_motion.dart';
import '../../app/theme/expressive_surfaces.dart';
import 'reorder_handle.dart';

/// 可排序列表（ReorderableListView）拖起态的统一外观。
///
/// 默认 proxyDecorator 是直角、elevation 6 的 Material，与 Expressive 圆角卡片
/// 和极淡投影体系不一致。这里改为卡片表面 + 16dp 圆角（与 ListTile 主题一致），
/// 投影随拖起进度从 0 平滑升到 3，落下时同样回落。拖起的副本包一层
/// [ReorderHandleLift]，行里的拖动手柄保持“握住”状态。
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
        child: ReorderHandleLift(animation: animation, child: child!),
      );
    },
  );
}

/// 行本身已是带描边的卡片时（日记模板、日记本管理、AI 写作指令）的拖起态：
/// 只轻微放大到 1.02，不另加卡片与投影，免得在圆角卡片外再套一层底色。
Widget cardRowReorderProxyDecorator(
  Widget child,
  int index,
  Animation<double> animation,
) {
  return AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (BuildContext context, Widget? child) => Transform.scale(
      scale: 1 + 0.02 * ExpressiveMotion.effects.transform(animation.value),
      child: Material(
        type: MaterialType.transparency,
        child: ReorderHandleLift(animation: animation, child: child!),
      ),
    ),
  );
}
