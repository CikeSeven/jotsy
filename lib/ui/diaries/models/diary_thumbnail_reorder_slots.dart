import 'dart:ui' show Offset, Size;

import 'diary_thumbnail_rows.dart';

/// 长按拖动小图排序的纯计算：挪动后的顺序与一串小图的格位。不读布局、
/// 不改文档；布局量好的位置由调用方传入。

/// 一串里第 [from] 张挪到第 [to] 张（都按挪动前的顺序数）后，原来第
/// [index] 张排在第几张：被拿起的那张到 [to]，两者之间的各让一格。
int diaryThumbnailReorderedIndex(
  int index, {
  required int from,
  required int to,
}) {
  if (index == from) return to;
  if (from < to && index > from && index <= to) return index - 1;
  if (to < from && index >= to && index < from) return index + 1;
  return index;
}

/// 拖动期间一串小图的格位：第 k 格的左上角（全局坐标）。拖动途中正文
/// 不变，第 k 格就是原来第 k 张所在的地方。
///
/// 建着的格子由调用方量好放进 [known]；没建的（滚出了列表的缓存区）按
/// 同一排的格距或上下排的行距推算——一排的几格等宽、格距
/// [kDiaryThumbnailRowGap]，几排上下紧挨着。推算只给看不见的格子用：
/// 看得见的格子让位时，目标格多半也建着。
class DiaryThumbnailSlots {
  const DiaryThumbnailSlots({
    required this.count,
    required this.known,
    required this.cell,
  });

  /// 这一串有几张。
  final int count;

  /// 量好的格位：格号 → 左上角。
  final Map<int, Offset> known;

  /// 一格（整块，含上下留白）的大小，几排紧挨着时也就是行距。
  final Size cell;

  static const int _capacity = kDiaryThumbnailRowCapacity;

  /// 第 [k] 格的左上角；没有任何量好的格子可推时为 null。
  Offset? origin(int k) {
    if (k < 0 || k >= count) return null;
    final measured = known[k];
    if (measured != null) return measured;
    if (known.isEmpty) return null;
    final row = k ~/ _capacity;
    final column = k % _capacity;
    // 同一排有量好的格子：只差几格的格距（一排怎么对齐都一样）。
    MapEntry<int, Offset>? reference;
    for (final entry in known.entries) {
      if (entry.key ~/ _capacity == row) {
        reference = entry;
        break;
      }
      // 别的排里优先取同一列的，横向不必再推。
      if (reference == null ||
          (entry.key % _capacity == column &&
              reference.key % _capacity != column)) {
        reference = entry;
      }
    }
    final ref = reference!;
    final step = cell.width + kDiaryThumbnailRowGap;
    return Offset(
      ref.value.dx + (column - ref.key % _capacity) * step,
      ref.value.dy + (row - ref.key ~/ _capacity) * _pitch(),
    );
  }

  /// 行距：两排都量到时按实测（一排里有张图解码失败、占位更高时也对），
  /// 否则取一格的高度。
  double _pitch() {
    MapEntry<int, Offset>? first;
    for (final entry in known.entries) {
      if (first == null) {
        first = entry;
        continue;
      }
      final rows = entry.key ~/ _capacity - first.key ~/ _capacity;
      if (rows != 0) return (entry.value.dy - first.value.dy) / rows;
    }
    return cell.height;
  }

  /// 拿起的画面中心在 [point] 时该落在哪一格：取格子里 [anchor]（画面中心
  /// 相对格子左上角）离它最近的一格。[current] 是现在的落点：别的格要比它
  /// 近出 [hysteresis] 才换，手指停在两格交界处时落点不来回跳。
  int? nearest(
    Offset point, {
    required Offset anchor,
    int? current,
    double hysteresis = 0,
  }) {
    int? best;
    var bestDistance = double.infinity;
    double? currentDistance;
    for (var k = 0; k < count; k++) {
      final origin = this.origin(k);
      if (origin == null) continue;
      final distance = (origin + anchor - point).distance;
      if (k == current) currentDistance = distance;
      if (distance < bestDistance) {
        best = k;
        bestDistance = distance;
      }
    }
    if (best == null || current == null || best == current) return best;
    if (currentDistance != null &&
        bestDistance + hysteresis >= currentDistance) {
      return current;
    }
    return best;
  }
}
