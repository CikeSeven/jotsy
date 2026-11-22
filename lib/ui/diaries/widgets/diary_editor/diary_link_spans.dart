/// 正文里链接片段的点按与外观（`diaryEditorSpanDecorator` 给了 `links` 时，
/// 带 `href` 的行内片段都经这里）。
///
/// - 输入：上游逐片段给出的块、偏移、片段与默认样式，以及 [DiaryLinkSpanOptions]；
/// - 输出：带点按识别器的 [TextSpan]（日记本功能关闭时日记本链接为普通文字）；
/// - 副作用：编辑态单击写正文选区（整段链接），网址链接随后打开应用的链接
///   对话框；打开日记链接经 `openDiaryLinkTarget`，网址经上游 `editorLaunchUrl`。
library;

import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../../core/database/diary_blocks/diary_link_target.dart';
import '../../controllers/diary_link_editing.dart';

/// 链接的点按与外观（`diaryEditorSpanDecorator` 的 `links`）。
class DiaryLinkSpanOptions {
  const DiaryLinkSpanOptions({
    required this.state,
    required this.onOpen,
    required this.onEditWebLink,
    required this.notebooksEnabled,
    required this.plainColor,
  });

  final af.EditorState state;

  /// 打开链接目标（编辑态是否打开日记本由它决定，见 `openDiaryLinkTarget`）。
  final ValueChanged<DiaryLinkTarget> onOpen;

  /// 编辑态单击网址链接、整段选中之后调用：打开应用的链接对话框。
  final VoidCallback onEditWebLink;

  /// 日记本功能关闭时，日记本链接按普通文字绘制、不可点。
  final bool notebooksEnabled;

  /// 正文墨色：按普通文字绘制时代替链接色。
  final Color? plainColor;
}

/// 链接片段的点按（日记链接与网址链接共用），分工沿用上游网址链接
/// （`defaultTextSpanDecoratorForAttribute`）：
/// - 只读正文（预览页）：点按即 [open]；
/// - 编辑态：单击选中整段链接文字（[diaryLinkRangeAt]，工具栏「链接」随之
///   高亮），新选区落定后调用 [onSelected]；200ms 内再点一次或按住 Ctrl / ⌘
///   点按才 [open]，不打断正常的点按定位。
/// 识别器与上游一样随每次构建新建：片段的生命周期由上游的文字渲染管理。
TapGestureRecognizer _linkTapRecognizer(
  af.EditorState state,
  af.Node node,
  int index,
  af.TextInsert insert, {
  required VoidCallback open,
  VoidCallback? onSelected,
}) {
  Timer? timer;
  var taps = 0;
  return TapGestureRecognizer()
    ..onTap = () {
      if (state.isDisposed) return;
      if (!state.editable) {
        open();
        return;
      }
      taps += 1;
      timer?.cancel();
      final keyboard = HardwareKeyboard.instance;
      if (taps >= 2 || keyboard.isControlPressed || keyboard.isMetaPressed) {
        taps = 0;
        open();
        return;
      }
      // 双击的判定窗口（非动画计时），与上游网址链接相同。
      timer = Timer(const Duration(milliseconds: 200), () {
        taps = 0;
        if (state.isDisposed || node.parent == null) return;
        // 被点的片段末尾一定落在它所属的整段链接里；文字已变、找不到时
        // 退回只选这一片。
        final end = index + insert.text.length;
        final selection =
            diaryLinkRangeAt(node, end)?.range ??
            af.Selection.single(
              path: node.path,
              startOffset: index,
              endOffset: end,
            );
        unawaited(
          state.updateSelectionWithReason(
            selection,
            reason: af.SelectionUpdateReason.uiEvent,
          ),
        );
        if (onSelected == null) return;
        // 等下一帧上游按新选区重建、接回焦点之后再调用（与上游链接浮层同一
        // 时机）。选区与原来相同时上游不重建、不排帧，所以自己排一帧，免得
        // 一直等不到。段落选择模式会挡掉这次选区，那时不调用。
        WidgetsBinding.instance
          ..addPostFrameCallback((_) {
            if (!state.isDisposed && state.selection == selection) {
              onSelected();
            }
          })
          ..ensureVisualUpdate();
      });
    };
}

/// 日记链接的片段：点按见 [_linkTapRecognizer]，“打开”为应用内跳转；编辑态
/// 单击只选中（经工具栏「链接」编辑或移除）。
TextSpan diaryLinkTextSpan(
  af.Node node,
  int index,
  af.TextInsert insert,
  TextSpan before,
  DiaryLinkTarget target,
  DiaryLinkSpanOptions links,
) {
  if (target.kind == DiaryLinkKind.notebook && !links.notebooksEnabled) {
    return TextSpan(
      text: insert.text,
      style: _plainLinkStyle(before.style, insert.attributes, links.plainColor),
    );
  }
  return TextSpan(
    text: insert.text,
    style: before.style,
    recognizer: _linkTapRecognizer(
      links.state,
      node,
      index,
      insert,
      open: () => links.onOpen(target),
    ),
    mouseCursor: SystemMouseCursors.click,
  );
}

/// 网址链接的片段，取代上游的 `defaultTextSpanDecoratorForAttribute`：上游
/// 编辑态单击后弹出自己的链接浮层（`showLinkMenu`），按“编辑器宽高减去
/// 固定 300”摆位置，手机窄屏上会摆到屏幕外（#336），样式与网址校验也与
/// 应用不一致。这里单击选中整段后交给 [DiaryLinkSpanOptions.onEditWebLink]
/// （应用的链接对话框）；打开仍经上游的 `editorLaunchUrl`，外观不变
/// （[before] 已带链接色）。
TextSpan diaryWebLinkTextSpan(
  af.Node node,
  int index,
  af.TextInsert insert,
  TextSpan before,
  String href,
  DiaryLinkSpanOptions links,
) => TextSpan(
  text: insert.text,
  style: before.style,
  recognizer: _linkTapRecognizer(
    links.state,
    node,
    index,
    insert,
    open: () => unawaited(af.editorLaunchUrl(href)),
    onSelected: links.onEditWebLink,
  ),
  mouseCursor: SystemMouseCursors.click,
);

/// 去掉链接色与链接下划线，保留用户自己设的文字色、下划线与删除线。
TextStyle? _plainLinkStyle(
  TextStyle? style,
  Map<String, dynamic>? attributes,
  Color? plainColor,
) {
  if (style == null) return null;
  final decorations = [
    if (attributes?[kDiaryInlineUnderline] == true) TextDecoration.underline,
    if (attributes?[kDiaryInlineStrikethrough] == true)
      TextDecoration.lineThrough,
  ];
  final color = attributes?[kDiaryInlineTextColor] != null
      ? style.color
      : plainColor;
  return style.copyWith(
    color: color,
    decoration: TextDecoration.combine(decorations),
    // 线条随文字色，同正文（见 `diaryEditorSpanDecorator`）。
    decorationColor: color,
  );
}
