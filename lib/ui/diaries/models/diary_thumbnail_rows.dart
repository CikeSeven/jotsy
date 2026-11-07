import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import 'diary_image_embed_data.dart';

/// 小图并排：正文顶层连续的小图（图片块且 `data.thumbnail == true`）从这一串
/// 的第一张起每 [kDiaryThumbnailRowCapacity] 张排成一排，余下的另起一排。
/// 纯计算，不读布局、不改文档。
///
/// 为什么只排顶层：顶层块是页面列表的一项一项（`DiaryScrollPage` /
/// `DiaryInlinePage`），把一排的几块交给同一项横着摆即可，每块仍是自己的块
/// 组件（自己的 `node.key`、选区与点按）；列表、折叠块等容器里的子块由各自
/// 的块组件竖着排，不在这里并排。
///
/// 数据不变：每张小图仍是独立的图片块，删掉小图标记、拖走或在中间插入别的
/// 块，这一排就按新的顺序重新分。导出（PDF / Word / 网页）读块文档的 JSON，
/// 经 [diaryThumbnailRowsBy] 按同一口径分排（`ExportBlock.thumbnailRow`）；
/// 旧版本与 Markdown、纯文本仍一张一行。

/// 一排最多几张小图。
const int kDiaryThumbnailRowCapacity = 3;

/// 一排里相邻小图的水平间距（逻辑像素）。
const double kDiaryThumbnailRowGap = 8;

/// [node] 是否参与并排：图片块且标为小图。
bool isDiaryThumbnailImage(af.Node node) =>
    node.type == kDiaryBlockImage && diaryImageIsThumbnail(node);

/// 正文列宽 [width] 下小图的边长：一排三张恰好放得下，最大
/// [kDiaryImageThumbnailExtent]。单张的小图也取这个边长，几排之间上下对齐。
double diaryThumbnailExtentFor(double width) {
  if (!width.isFinite) return kDiaryImageThumbnailExtent;
  const gaps = kDiaryThumbnailRowGap * (kDiaryThumbnailRowCapacity - 1);
  final fit = (width - gaps) / kDiaryThumbnailRowCapacity;
  return math.max(0, math.min(kDiaryImageThumbnailExtent, fit)).toDouble();
}

/// 一排的起止下标（含头不含尾）。
typedef DiaryThumbnailRow = ({int start, int end});

/// [siblings] 里每一块所在那排的起止：不是小图的块自成一排（只有自己）。
/// 下标与 [siblings] 一一对应。
List<DiaryThumbnailRow> diaryThumbnailRows(List<af.Node> siblings) =>
    diaryThumbnailRowsBy(siblings, isDiaryThumbnailImage);

/// [diaryThumbnailRows] 的通用形式：[isThumbnail] 判断一块是不是小图。编辑器
/// 传节点，导出传块文档的 JSON（导出不经编辑器），两边分排的口径只在这里。
List<DiaryThumbnailRow> diaryThumbnailRowsBy<T>(
  List<T> siblings,
  bool Function(T block) isThumbnail,
) {
  final rows = List<DiaryThumbnailRow>.filled(siblings.length, (
    start: 0,
    end: 0,
  ));
  var i = 0;
  while (i < siblings.length) {
    if (!isThumbnail(siblings[i])) {
      rows[i] = (start: i, end: i + 1);
      i++;
      continue;
    }
    final start = i;
    var end = i + 1;
    while (end < siblings.length &&
        end - start < kDiaryThumbnailRowCapacity &&
        isThumbnail(siblings[end])) {
      end++;
    }
    for (var j = start; j < end; j++) {
      rows[j] = (start: start, end: end);
    }
    i = end;
  }
  return rows;
}

/// 正文顶层块 [node] 所在那排；不是顶层块时为 null（子块不并排）。
DiaryThumbnailRow? diaryThumbnailRowOf(af.Node node) {
  final parent = node.parent;
  if (parent == null || parent.parent != null) return null;
  final index = node.path.last;
  // 只往前后看同一串小图，不必把整篇正文分一遍。
  if (!isDiaryThumbnailImage(node)) return (start: index, end: index + 1);
  final siblings = parent.children;
  var runStart = index;
  while (runStart > 0 && isDiaryThumbnailImage(siblings[runStart - 1])) {
    runStart--;
  }
  final start =
      runStart +
      (index - runStart) ~/
          kDiaryThumbnailRowCapacity *
          kDiaryThumbnailRowCapacity;
  var end = start + 1;
  while (end < siblings.length &&
      end - start < kDiaryThumbnailRowCapacity &&
      isDiaryThumbnailImage(siblings[end])) {
    end++;
  }
  return (start: start, end: end);
}

/// 顶层第 [index] 块在页面列表里由哪一项画出：并排的小图都画在这一排第一张
/// 那一项里，其余的项是空的。用于按下标跳转（揭示某块、拖动时固定锚点）。
int diaryThumbnailRowLeader(af.Node root, int index) {
  final children = root.children;
  if (index < 0 || index >= children.length) return index;
  return diaryThumbnailRowOf(children[index])?.start ?? index;
}
