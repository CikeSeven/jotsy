import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/launch_brand_mark.dart';

/// 原生闪屏矢量：系统闪屏把它画成 288dp 并居中，Flutter 首帧必须与之重合。
const _nativeVectorPath =
    'android/app/src/main/res/drawable/launch_brand_mark.xml';
const double _nativeCanvas = 288;

/// 与原生 pathData 相同的数字写法：最多两位小数，去掉多余的 0。
String _n(double value) {
  final fixed = value.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

void main() {
  final scale = LaunchBrandMark.height / LaunchBrandMark.designSize.height;
  final origin = Offset(
    (_nativeCanvas - LaunchBrandMark.size.width) / 2,
    (_nativeCanvas - LaunchBrandMark.size.height) / 2,
  );

  // 按 Flutter 侧几何推出原生画布里应有的 pathData（顺时针圆角矩形）。
  String rrectPath(RRect rrect) {
    final l = origin.dx + rrect.left * scale;
    final t = origin.dy + rrect.top * scale;
    final r = origin.dx + rrect.right * scale;
    final b = origin.dy + rrect.bottom * scale;
    final radius = rrect.tlRadiusX * scale;
    final arc = 'A${_n(radius)},${_n(radius)} 0 0 1';
    return 'M${_n(l + radius)},${_n(t)} H${_n(r - radius)} '
        '$arc ${_n(r)},${_n(t + radius)} V${_n(b - radius)} '
        '$arc ${_n(r - radius)},${_n(b)} H${_n(l + radius)} '
        '$arc ${_n(l)},${_n(b - radius)} V${_n(t + radius)} '
        '$arc ${_n(l + radius)},${_n(t)} Z';
  }

  String circlePath(Offset center) {
    final cx = origin.dx + center.dx * scale;
    final cy = origin.dy + center.dy * scale;
    final radius = LaunchBrandMark.ringRadius * scale;
    final arc = 'A${_n(radius)},${_n(radius)} 0 1 0';
    return 'M${_n(cx - radius)},${_n(cy)} '
        '$arc ${_n(cx + radius)},${_n(cy)} '
        '$arc ${_n(cx - radius)},${_n(cy)} Z';
  }

  test('the outline merges the rings into the cover and cuts the label', () {
    final path = LaunchBrandMark.pathAtScale(1);

    expect(path.getBounds(), const Rect.fromLTRB(0, 0, 85, 100));
    // 封皮主体、压在左缘上的装订环。
    expect(path.contains(const Offset(45, 70)), isTrue);
    expect(path.contains(const Offset(1, 20)), isTrue);
    expect(path.contains(const Offset(7, 80)), isTrue);
    // 封面标签镂空、装订环之间的缺口、圆角之外。
    expect(path.contains(const Offset(45, 30)), isFalse);
    expect(path.contains(const Offset(1, 30)), isFalse);
    expect(path.contains(const Offset(84, 1)), isFalse);
  });

  testWidgets('the mark paints at its native size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: LaunchBrandMark())),
    );
    expect(tester.getSize(find.byType(LaunchBrandMark)), const Size(68, 80));
  });

  test('the native splash vector draws the same outline', () {
    final xml = File(_nativeVectorPath).readAsStringSync();

    // 288dp 画布是系统闪屏无底板时的前景尺寸，视口与之一一对应（1 单位 = 1dp）。
    expect(xml, contains('android:width="288dp"'));
    expect(xml, contains('android:height="288dp"'));
    expect(xml, contains('android:viewportWidth="288"'));
    expect(xml, contains('android:viewportHeight="288"'));

    final pathData = RegExp(
      r'android:pathData="([^"]+)"',
    ).allMatches(xml).map((match) => match.group(1)).toList();
    expect(pathData, <String>[
      '${rrectPath(LaunchBrandMark.body)} '
          '${rrectPath(LaunchBrandMark.label)}',
      LaunchBrandMark.ringCenters.map(circlePath).join(' '),
    ]);
    // 第一条路径靠偶奇填充挖出标签。
    expect(
      RegExp(r'<path[^>]*fillType="evenOdd"[^>]*>').allMatches(xml).length,
      1,
    );
  });
}
