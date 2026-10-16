import 'package:flutter/material.dart';

import '../models/diary_card_style/diary_card_style.dart';

/// 卡片表面的投影列表。
///
/// - themed：改版前的默认投影，亮色两到三层（置顶多一层主色辉光）、暗色
///   一层，逐项保留原值；
/// - soft / floating / custom：用 [color]（null 时为 colorScheme.shadow）乘以
///   阴影颜色的浓度，暗色主题加深以便在深色底上看得出；
/// - [translucent]：卡片半透明时阴影改为只画形状外侧（BlurStyle.outer），
///   否则会从卡片底下透出来。
List<BoxShadow> diaryCardShadows({
  required DiaryCardSurfaceStyle surface,
  required ColorScheme scheme,
  required bool pinnedTinted,
  required Color? color,
  required bool translucent,
}) {
  final isLight = scheme.brightness == Brightness.light;
  final shadowColor = color ?? scheme.shadow;
  final strength = surface.shadowColor.strength;
  Color shade(double alpha) =>
      shadowColor.withValues(alpha: alpha.clamp(0, 1).toDouble());
  final shadows = switch (surface.shadow) {
    // 改版前的默认投影：亮色两到三层（置顶多一层主色辉光），暗色一层。
    DiaryCardShadowStyle.themed =>
      isLight
          ? <BoxShadow>[
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
              BoxShadow(
                color: scheme.shadow.withValues(
                  alpha: pinnedTinted ? 0.055 : 0.04,
                ),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              if (pinnedTinted)
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 3.5),
                ),
            ]
          : <BoxShadow>[
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.32),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
    DiaryCardShadowStyle.none => const <BoxShadow>[],
    DiaryCardShadowStyle.soft => <BoxShadow>[
      BoxShadow(
        color: shade(strength * (isLight ? 0.6 : 1.4)),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ],
    DiaryCardShadowStyle.floating => <BoxShadow>[
      BoxShadow(
        color: shade(strength * (isLight ? 0.9 : 1.8)),
        blurRadius: 26,
        offset: const Offset(0, 12),
      ),
      BoxShadow(
        color: shade(strength * 0.4),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
    DiaryCardShadowStyle.custom when surface.shadowElevation <= 0 =>
      const <BoxShadow>[],
    DiaryCardShadowStyle.custom => <BoxShadow>[
      BoxShadow(
        color: shade(strength * (isLight ? 1 : 1.6)),
        blurRadius: surface.shadowElevation * 1.5,
        offset: Offset(0, surface.shadowElevation * 0.5),
      ),
    ],
  };
  if (!translucent) {
    return shadows;
  }
  // 半透明卡片下方的阴影会透出来，只保留形状外侧的部分。
  return <BoxShadow>[
    for (final shadow in shadows)
      BoxShadow(
        color: shadow.color,
        offset: shadow.offset,
        blurRadius: shadow.blurRadius,
        spreadRadius: shadow.spreadRadius,
        blurStyle: BlurStyle.outer,
      ),
  ];
}
