import 'package:flutter/material.dart';

/// 原生启动页已在屏幕中央绘制品牌图形时，`MainActivity` 传给 Dart 入口的参数。
///
/// 只有 Android 12+ 会传：系统 SplashScreen 把图形画在窗口正中，Flutter 视图
/// 又与窗口全屏对齐，首帧才能在同一位置原样接上。更早的 Android、iOS、桌面
/// 与测试不传，启动层只铺底色，不会凭空冒出一个原生启动页上没有的图形。
const String launchBrandMarkEntrypointArg = '--launch-brand-mark';

/// 品牌图形：一本带装订环的笔记本（取自应用图标）。
///
/// 与原生闪屏图标 `android/app/src/main/res/drawable/launch_brand_mark.xml`
/// 同源：几何、尺寸（[height] dp 高、屏幕居中）、颜色（默认种子色的
/// `primary`，即启动首帧尚未读到设置时的主题色）三者必须一致，Flutter 首帧
/// 才能与系统闪屏无缝接力。改动任一端都要同步另一端，
/// `test/app/launch_brand_mark_test.dart` 会校验两端一致。
class LaunchBrandMark extends StatelessWidget {
  const LaunchBrandMark({super.key});

  /// 图形高度（dp）。原生矢量在 288dp 画布（系统闪屏无图标底板时的前景尺寸）
  /// 中以同样高度居中。
  static const double height = 80;

  /// 设计网格：图形外框 85 × 100，下面的几何都在该网格内定义。
  static const Size designSize = Size(85, 100);

  /// 封皮主体。
  static const RRect body = RRect.fromLTRBXY(5, 0, 85, 100, 10, 10);

  /// 装订环：圆心压在封皮左缘上，与封皮合并成一个轮廓。
  static const double ringRadius = 5;
  static const List<Offset> ringCenters = <Offset>[
    Offset(5, 20),
    Offset(5, 40),
    Offset(5, 60),
    Offset(5, 80),
  ];

  /// 封面标签：镂空，透出底色。
  static const RRect label = RRect.fromLTRBXY(20, 20, 70, 40, 8, 8);

  /// 实际绘制尺寸：68 × 80 dp。
  static Size get size => designSize * (height / designSize.height);

  /// 按 [scale]（设计网格 → 逻辑像素）生成单一轮廓：封皮与装订环取并集，
  /// 再减去标签。合成为一条路径而不是分次绘制，半透明时重叠处不会叠深。
  static Path pathAtScale(double scale) {
    final matrix = Matrix4.diagonal3Values(scale, scale, 1).storage;
    final outline = Path()..addRRect(body);
    for (final center in ringCenters) {
      outline.addOval(Rect.fromCircle(center: center, radius: ringRadius));
    }
    return Path.combine(
      PathOperation.difference,
      outline.transform(matrix),
      (Path()..addRRect(label)).transform(matrix),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: size,
      painter: _LaunchBrandMarkPainter(Theme.of(context).colorScheme.primary),
    );
  }
}

class _LaunchBrandMarkPainter extends CustomPainter {
  _LaunchBrandMarkPainter(this.color);

  final Color color;

  // 图形固定尺寸绘制，轮廓只需合成一次；主题色补间期间逐帧重绘也不再做
  // 路径布尔运算。
  static final Path _path = LaunchBrandMark.pathAtScale(
    LaunchBrandMark.height / LaunchBrandMark.designSize.height,
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LaunchBrandMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
