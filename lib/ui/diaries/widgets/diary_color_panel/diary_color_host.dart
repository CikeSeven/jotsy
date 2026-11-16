import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart'
    as editor;
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';

/// 颜色面板（`DiaryColorPanel` 与其中的自定义页）作用的对象：正文编辑器的
/// 选区，或思维导图里正在编辑的主题文字 / 主题的整条样式。
///
/// 面板只经它读当前颜色、写入颜色，随它的通知刷新；不关心颜色最后写在
/// 哪里。写入值一律是 [encodeDiaryColor] 的 `#AARRGGBB`，两边按原色显示。
abstract interface class DiaryColorHost implements Listenable {
  /// 当前选区在 [target] 上的颜色。
  DiaryColorValue colorValue(DiaryColorTarget target);

  /// 把 [target] 设为 [color]（null 为清除）。
  void applyColor(DiaryColorTarget target, Color? color);

  /// 当前选区的标识：自定义页据此判断接连写入是不是“同一次调色”（同一次
  /// 调色只在我的颜色里留最后一个）。值相等即同一选区。
  Object? get selectionToken;
}

/// 正文编辑器的选区。按控制器判等：每次构建新建一个也不会让面板重新订阅。
final class DiaryEditorColorHost implements DiaryColorHost {
  const DiaryEditorColorHost(this.controller);

  final editor.DiaryEditorController controller;

  @override
  DiaryColorValue colorValue(DiaryColorTarget target) =>
      DiaryColorValue.of(controller.selectionAttributes, target);

  @override
  void applyColor(DiaryColorTarget target, Color? color) =>
      controller.formatSelection(target.attributeFor(color));

  @override
  Object? get selectionToken => controller.selection;

  @override
  void addListener(VoidCallback listener) => controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      controller.removeListener(listener);

  @override
  bool operator ==(Object other) =>
      other is DiaryEditorColorHost && identical(other.controller, controller);

  @override
  int get hashCode => identityHashCode(controller);
}
