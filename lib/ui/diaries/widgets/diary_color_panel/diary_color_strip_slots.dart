/// “我的颜色”一行的条目与增删动画的排位（纯计算，不依赖 BuildContext）。
///
/// 一行里依次是：我的颜色（跨日记保存的）→ 分隔 → 本篇用过、但没保存的
/// 颜色。保存、移除与收藏都会让条目进出；[mergeDiaryColorStripSlots] 把
/// 新条目排进来、把离开的条目留在原位，让它们原地收拢，而不是瞬间消失、
/// 后面的色块一下子跳过去。
library;

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';

enum DiaryColorStripKind {
  /// 我的颜色：点按套用，管理时移除。
  saved,

  /// 我的颜色与本篇颜色之间的细分隔，两组都有时才出现。
  divider,

  /// 本篇用过、但没保存的颜色：点按套用，管理时收藏进我的颜色。
  document,
}

@immutable
class DiaryColorStripEntry {
  const DiaryColorStripEntry.saved(Color this.color)
    : kind = DiaryColorStripKind.saved;
  const DiaryColorStripEntry.document(Color this.color)
    : kind = DiaryColorStripKind.document;
  const DiaryColorStripEntry.divider()
    : kind = DiaryColorStripKind.divider,
      color = null;

  final DiaryColorStripKind kind;
  final Color? color;

  /// 同一种颜色在“我的”与“本篇”里是两个条目：收藏后旧条目收拢、新条目在
  /// 最前展开，看得出它换了地方。
  String get key => switch (kind) {
    DiaryColorStripKind.divider => 'divider',
    _ => '${kind.name}-${color!.toARGB32()}',
  };
}

/// 一行要显示的条目：我的颜色在前（保存顺序），两组都有时接分隔，再接本篇
/// 用过、但没保存的颜色。
List<DiaryColorStripEntry> diaryColorStripEntries({
  required List<Color> saved,
  required List<Color> document,
}) {
  final unsaved = <Color>[
    for (final color in document)
      if (!saved.any((Color other) => sameDiaryColor(other, color))) color,
  ];
  return <DiaryColorStripEntry>[
    for (final color in saved) DiaryColorStripEntry.saved(color),
    if (saved.isNotEmpty && unsaved.isNotEmpty)
      const DiaryColorStripEntry.divider(),
    for (final color in unsaved) DiaryColorStripEntry.document(color),
  ];
}

/// 正在显示的一格：[leaving] 为 true 时正在收拢，收拢完由行移除。
@immutable
class DiaryColorStripSlot {
  const DiaryColorStripSlot(this.entry, {this.leaving = false});

  final DiaryColorStripEntry entry;
  final bool leaving;

  String get key => entry.key;
}

/// 按新条目 [next] 重排正在显示的 [previous]：顺序以 [next] 为准，不在
/// [next] 里的旧格标为离开、留在原来的相对位置。
///
/// 收拢途中又回来的格子（如移除后立刻收藏回来）复用同一格、重新展开。
List<DiaryColorStripSlot> mergeDiaryColorStripSlots(
  List<DiaryColorStripSlot> previous,
  List<DiaryColorStripEntry> next,
) {
  final nextKeys = <String>{for (final entry in next) entry.key};
  final previousIndex = <String, int>{
    for (final (index, slot) in previous.indexed) slot.key: index,
  };
  final result = <DiaryColorStripSlot>[];
  var cursor = 0;

  void flushLeavingBefore(int end) {
    for (; cursor < end; cursor++) {
      final slot = previous[cursor];
      if (!nextKeys.contains(slot.key)) {
        result.add(DiaryColorStripSlot(slot.entry, leaving: true));
      }
    }
  }

  for (final entry in next) {
    final index = previousIndex[entry.key];
    if (index != null && index >= cursor) {
      flushLeavingBefore(index);
      cursor = index + 1;
    }
    result.add(DiaryColorStripSlot(entry));
  }
  flushLeavingBefore(previous.length);
  return result;
}
