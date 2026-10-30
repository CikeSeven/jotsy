// 二维码的模块矩阵（DESIGN.md §5.28“二维码面板”）：纯 Dart，无副作用。
//
// 编码经 `qr` 包，纠错级别固定为 Q（可恢复约 25% 的码字）。实际载荷（完整
// 指纹、令牌、设备名与地址）约 300 字节：H 级要第 17–19 版（85–93 模块），
// 216dp 的码每个模块只有 2.3–2.5dp，1× 缩放的显示器上不到 3 个物理像素，
// 手机扫屏幕很吃力；Q 级降到约第 15 版（77 模块），每个模块约 2.8dp。M 级
// （约 15%）相对中心挖空的余量太紧，不用。生成矩阵要试 8 种掩码，不便宜，
// 调用方按载荷与码的边长缓存一份（换码或跨过宽 / 窄档时才重算）。
//
// 中心挖空：设计稿按“7 × 7 模块”画，前提是模块约 6dp；实际模块不到 3dp，
// 7 × 7 模块盖不住 40dp 的品牌块。因此挖空边长取“能盖住品牌块的模块数
// 再各留一圈”，且不少于 7、取奇数以居中（模块总数 4v + 17 恒为奇数）。
// 挖掉的模块占比远低于 Q 级的纠错余量（见测试）。

import 'package:qr/qr.dart';

/// 见文件头注释。
class LanSyncQrMatrix {
  LanSyncQrMatrix._(
    this.moduleCount,
    this.typeNumber,
    this.cleared,
    this._dark,
  );

  /// 按 [payload] 编码：码画成 [codeExtent] 见方，中心挖空盖住 [markExtent]
  /// 见方的品牌块（单位都是逻辑像素，只用来换算挖空的模块数）。
  factory LanSyncQrMatrix.encode(
    String payload, {
    double codeExtent = 216,
    double markExtent = 40,
  }) {
    final code = QrCode.fromData(
      data: payload,
      errorCorrectLevel: errorCorrectLevel,
    );
    final image = QrImage(code);
    final count = image.moduleCount;
    final cleared = _clampCleared(
      clearedFor(extent: markExtent, moduleExtent: codeExtent / count),
      count,
    );
    final dark = List<bool>.filled(count * count, false);
    final start = (count - cleared) ~/ 2;
    final end = start + cleared;
    for (var row = 0; row < count; row++) {
      for (var col = 0; col < count; col++) {
        final inCentre = row >= start && row < end && col >= start && col < end;
        dark[row * count + col] = !inCentre && image.isDark(row, col);
      }
    }
    return LanSyncQrMatrix._(count, image.typeNumber, cleared, dark);
  }

  /// 纠错级别（Q，约 25%），理由见文件头注释。
  static const int errorCorrectLevel = QrErrorCorrectLevel.Q;

  /// 中心挖空的最小边长（设计稿的 7 × 7）。
  static const int minClearedModules = 7;

  /// 定位角的边长（模块）。
  static const int finderModules = 7;

  /// 每边的模块数（4 × 版本 + 17）。
  final int moduleCount;

  /// 二维码版本（1–40）。
  final int typeNumber;

  /// 中心挖空的边长（模块，奇数）。
  final int cleared;

  final List<bool> _dark;

  /// 盖住 [extent] 逻辑像素的品牌块、每边再留一圈所需的挖空边长（模块）。
  static int clearedFor({
    required double extent,
    required double moduleExtent,
  }) {
    final cover = (extent / moduleExtent).ceil() + 2;
    final odd = cover.isOdd ? cover : cover + 1;
    return odd < minClearedModules ? minClearedModules : odd;
  }

  static int _clampCleared(int value, int count) {
    var cleared = value < minClearedModules ? minClearedModules : value;
    if (cleared.isEven) cleared += 1;
    // 至多挖到定位角内侧为止（实际远小于此）。
    final limit = count - 2 * (finderModules + 1);
    return cleared > limit ? (limit.isOdd ? limit : limit - 1) : cleared;
  }

  /// 第 [row] 行第 [col] 列是否为深色模块（挖空区一律为浅色）。
  bool isDark(int row, int col) => _dark[row * moduleCount + col];

  /// 是否落在三个定位角（含外圈）里：这些模块不画成圆点，由画家整体画成
  /// 圆角方框。
  bool isFinder(int row, int col) {
    const f = finderModules;
    final far = moduleCount - f;
    return (row < f && col < f) ||
        (row < f && col >= far) ||
        (row >= far && col < f);
  }

  /// 是否落在中心挖空区里。
  bool isCleared(int row, int col) {
    final start = (moduleCount - cleared) ~/ 2;
    final end = start + cleared;
    return row >= start && row < end && col >= start && col < end;
  }
}
