import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';

// ExpressiveMotion.containerSpring：卡片展开成整页用的临界阻尼弹簧曲线——
// 一按就走、速度没有尖峰、慢慢落稳、不越过终点。

const _steps = 2000;

/// 每一小段的斜率（相对平均速度的倍数），t 取该段起点。
Iterable<(double, double)> _slopes(Curve curve) sync* {
  for (var i = 0; i < _steps; i++) {
    final a = i / _steps;
    final b = (i + 1) / _steps;
    yield (a, (curve.transform(b) - curve.transform(a)) * _steps);
  }
}

double _maxSlope(Curve curve) =>
    _slopes(curve).map((s) => s.$2).reduce((a, b) => a > b ? a : b);

void main() {
  const curve = ExpressiveMotion.containerSpring;

  test('starts exactly on the card and ends exactly on the page', () {
    expect(curve.transform(0), 0);
    expect(curve.transform(1), 1);
  });

  test('never moves backwards or past the page', () {
    var previous = 0.0;
    for (var i = 1; i <= _steps; i++) {
      final value = curve.transform(i / _steps);
      expect(value, greaterThanOrEqualTo(previous), reason: 't ${i / _steps}');
      expect(value, lessThanOrEqualTo(1), reason: 't ${i / _steps}');
      previous = value;
    }
  });

  test('moves right away instead of holding at the start', () {
    expect(curve.transform(0.1), greaterThan(0.15));
    expect(curve.transform(0.5), greaterThan(0.9));
  });

  test('peaks far below the speed spike of the M3 emphasized curve', () {
    // M3 emphasized 在 t≈0.17 处冲到平均速度的约 10 倍，这正是旧转场“甩一下”
    // 的来源；弹簧的峰值约为 3.3 倍。
    expect(_maxSlope(Curves.easeInOutCubicEmphasized), greaterThan(8));
    expect(_maxSlope(curve), lessThan(4));
  });

  test('lands softly without a visible stop', () {
    for (final (t, slope) in _slopes(curve)) {
      if (t >= 0.95) {
        expect(slope, lessThan(0.05), reason: 't $t');
      }
    }
  });
}
