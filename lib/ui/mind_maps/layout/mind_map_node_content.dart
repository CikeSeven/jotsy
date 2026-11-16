import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../core/database/mind_map/mind_map_document.dart';
import '../models/mind_map_markers.dart';
import '../models/mind_map_options.dart';
import '../viewmodels/mind_map_visuals.dart';
import 'mind_map_text_cache.dart';

/// 节点里可以点的部件（待办框、备注、链接、任务进度）。
enum MindMapNodePart { checkbox, note, link }

/// 一个节点框里的内容排版：一行“待办框 · 贴纸 · 文字 · 进度 / 备注 / 链接
/// 标记”，其下一行标签胶囊。矩形都相对节点左上角（未缩放的导图坐标）。
///
/// 测量与绘制、命中测试共用这一份结果：布局时算好，画的时候只按比例平移。
final class MindMapNodeContent {
  const MindMapNodeContent({
    required this.size,
    required this.textRect,
    required this.iconSize,
    this.checkbox,
    this.markers = const <(MindMapMarker, Rect)>[],
    this.progress,
    this.note,
    this.link,
    this.labels = const <(TextPainter, Rect)>[],
    this.taskDone = false,
    this.diaryLink = false,
  });

  /// 节点框的整体尺寸（含内边距）。
  final Size size;

  /// 文字的位置（输入框也叠在这里）。
  final Rect textRect;
  final double iconSize;
  final Rect? checkbox;
  final List<(MindMapMarker, Rect)> markers;

  /// 子孙里待办的完成情况（有待办时才有）。
  final ({int done, int total, Rect rect})? progress;
  final Rect? note;
  final Rect? link;
  final List<(TextPainter, Rect)> labels;
  final bool taskDone;

  /// 链接是日记链接（画书本）而不是网址（画链条）。
  final bool diaryLink;

  /// [local]（相对节点左上角）点中的部件。
  MindMapNodePart? partAt(Offset local, {double slop = 0}) {
    bool hit(Rect? rect) =>
        rect != null && rect.inflate(slop + 4).contains(local);
    if (hit(checkbox)) return MindMapNodePart.checkbox;
    if (hit(note)) return MindMapNodePart.note;
    if (hit(link)) return MindMapNodePart.link;
    return null;
  }
}

/// 测量节点内容。[text] 为已排版的文字（或占位文字），[minTextWidth] 为
/// 文字区的最小宽度，[progress] 为子孙待办的完成数 / 总数（没有为 null）。
MindMapNodeContent measureMindMapNodeContent({
  required MindMapNode node,
  required MindMapNodeVisual visual,
  required TextPainter text,
  required double minTextWidth,
  required MindMapTextCache texts,
  ({int done, int total})? progress,
}) {
  final fontSize = visual.textStyle.fontSize ?? 14;
  final iconSize = (fontSize * 1.05).roundToDouble();
  final gap = math.max(4.0, fontSize * 0.36);
  final markers = <MindMapMarker>[
    for (final id in node.icons) ?MindMapMarker.parse(id),
  ];
  final textWidth = math.max(text.width, minTextWidth);
  final rowHeight = math.max(text.height, iconSize);

  // 先排一行（从 0 起），最后整体平移到内边距里、居中或靠起始边。
  var x = 0.0;
  Rect icon() {
    final rect = Rect.fromLTWH(
      x,
      (rowHeight - iconSize) / 2,
      iconSize,
      iconSize,
    );
    x += iconSize + gap;
    return rect;
  }

  final checkbox = node.isTask ? icon() : null;
  final markerRects = <(MindMapMarker, Rect)>[
    for (final marker in markers) (marker, icon()),
  ];
  final textRect = Rect.fromLTWH(
    x,
    (rowHeight - text.height) / 2,
    textWidth,
    text.height,
  );
  x += textWidth;
  final small = iconSize * 0.82;
  Rect trailing() {
    x += gap;
    final rect = Rect.fromLTWH(x, (rowHeight - small) / 2, small, small);
    x += small;
    return rect;
  }

  final progressRect = progress == null ? null : trailing();
  final hasNote = (node.note ?? '').trim().isNotEmpty;
  final noteRect = hasNote ? trailing() : null;
  final href = node.href?.trim() ?? '';
  final linkRect = href.isEmpty ? null : trailing();
  final rowWidth = x;

  // 标签：一行排不下就换行，最宽不超过文字区的最大宽度。
  final labels = <(TextPainter, Rect)>[];
  var labelsHeight = 0.0;
  var labelsWidth = 0.0;
  if (node.labels.isNotEmpty) {
    final labelStyle = visual.textStyle.copyWith(
      fontSize: math.max(10.5, fontSize * 0.72),
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.none,
      fontStyle: FontStyle.normal,
    );
    final maxWidth = math.max(rowWidth, visual.maxTextWidth);
    var lx = 0.0;
    var ly = 0.0;
    var lineHeight = 0.0;
    for (final label in node.labels) {
      final trimmed = label.trim();
      if (trimmed.isEmpty) continue;
      final painter = texts.painterFor(
        trimmed,
        labelStyle,
        maxWidth: visual.maxTextWidth - 12,
      );
      final w = painter.width + 12;
      final h = painter.height + 4;
      if (lx > 0 && lx + w > maxWidth) {
        lx = 0;
        ly += lineHeight + 4;
        lineHeight = 0;
      }
      labels.add((painter, Rect.fromLTWH(lx, ly, w, h)));
      lx += w + 4;
      lineHeight = math.max(lineHeight, h);
      labelsWidth = math.max(labelsWidth, lx - 4);
    }
    labelsHeight = ly + lineHeight;
  }

  final contentWidth = math.max(rowWidth, labelsWidth);
  final rowTop = 0.0;
  final labelsTop = rowHeight + (labels.isEmpty ? 0 : gap * 0.8);
  final contentHeight = labelsTop + labelsHeight;
  final padding = visual.padding;
  var width = contentWidth + padding.horizontal;
  var height = contentHeight + padding.vertical;
  var extraX = 0.0;
  var extraY = 0.0;
  if (visual.shape == MindMapNodeShape.ellipse) {
    extraX = width * 0.11;
    extraY = height * 0.15;
    width *= 1.22;
    height *= 1.3;
  }
  final centered = visual.textAlign == TextAlign.center;
  final rowShift = Offset(
    padding.left + extraX + (centered ? (contentWidth - rowWidth) / 2 : 0),
    padding.top + extraY + rowTop,
  );
  final labelsShift = Offset(
    padding.left + extraX + (centered ? (contentWidth - labelsWidth) / 2 : 0),
    padding.top + extraY + labelsTop,
  );
  Rect? shift(Rect? rect) => rect?.shift(rowShift);
  return MindMapNodeContent(
    size: Size(width.ceilToDouble(), height.ceilToDouble()),
    textRect: textRect.shift(rowShift),
    iconSize: iconSize,
    checkbox: shift(checkbox),
    markers: <(MindMapMarker, Rect)>[
      for (final (marker, rect) in markerRects) (marker, rect.shift(rowShift)),
    ],
    progress: progress == null || progressRect == null
        ? null
        : (
            done: progress.done,
            total: progress.total,
            rect: progressRect.shift(rowShift),
          ),
    note: shift(noteRect),
    link: shift(linkRect),
    labels: <(TextPainter, Rect)>[
      for (final (painter, rect) in labels) (painter, rect.shift(labelsShift)),
    ],
    taskDone: node.taskDone,
    diaryLink: DiaryLinkTarget.isLink(href),
  );
}

/// 每个节点的子孙里待办的完成情况（一次后序遍历算完；没有待办的节点不在
/// 结果里）。
Map<String, ({int done, int total})> mindMapTaskProgress(MindMapNode root) {
  final out = <String, ({int done, int total})>{};
  (int, int) visit(MindMapNode node) {
    var done = 0;
    var total = 0;
    for (final child in node.children) {
      if (child.isTask) {
        total++;
        if (child.taskDone) done++;
      }
      final (d, t) = visit(child);
      done += d;
      total += t;
    }
    if (total > 0) out[node.id] = (done: done, total: total);
    return (done, total);
  }

  visit(root);
  return out;
}
