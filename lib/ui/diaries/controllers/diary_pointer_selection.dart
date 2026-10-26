import 'dart:math' as math;

import 'package:flutter/services.dart';

/// 桌面上 Shift + 点按选范围时的起点：最近一次点按、勾选或长按的那张卡片。
///
/// 页面状态里持有一份（日记页、归档页），交给 `DiariesListSection`；只是
/// 内存里的一个 id，不触发重建。起点不在当前列表里（被筛掉、归档）时，
/// Shift + 点按按 Ctrl + 点按处理。
class DiarySelectionAnchor {
  String? id;
}

/// 桌面上带修饰键的卡片点按（多选），返回是否已处理。
///
/// - Ctrl / ⌘ + 点按：切换这张的勾选（不在多选模式时即进入多选），并成为
///   新的范围起点；
/// - Shift + 点按：把起点到这张之间（按 [order] 的列表顺序，含两端）全部
///   勾上，起点不变；没有可用的起点时同 Ctrl + 点按；
/// - 不带修饰键：只记下起点，返回 false，卡片照常执行点按（双栏选中阅读、
///   否则打开预览，多选模式下切换勾选）。
///
/// [toggle] 即列表的 `onToggleSelection`：`force` 为 true 时只勾上不取消。
bool handleDiaryModifierTap({
  required List<String> order,
  required String diaryId,
  required DiarySelectionAnchor anchor,
  required void Function(String diaryId, bool force) toggle,
}) {
  final keyboard = HardwareKeyboard.instance;
  if (keyboard.isShiftPressed) {
    final from = anchor.id == null ? -1 : order.indexOf(anchor.id!);
    final to = order.indexOf(diaryId);
    if (from >= 0 && to >= 0) {
      for (
        var index = math.min(from, to);
        index <= math.max(from, to);
        index++
      ) {
        toggle(order[index], true);
      }
      return true;
    }
  }
  if (keyboard.isShiftPressed ||
      keyboard.isControlPressed ||
      keyboard.isMetaPressed) {
    anchor.id = diaryId;
    toggle(diaryId, false);
    return true;
  }
  anchor.id = diaryId;
  return false;
}
