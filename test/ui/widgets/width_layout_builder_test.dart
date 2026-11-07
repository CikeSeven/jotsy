import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/width_layout_builder.dart';

/// builder 里读取的依赖：值变化时通知依赖者。
class _Shade extends InheritedWidget {
  const _Shade({required this.value, required super.child});

  final int value;

  static int of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Shade>()!.value;

  @override
  bool updateShouldNotify(_Shade oldWidget) => value != oldWidget.value;
}

/// 测试台：尺寸与依赖值经 notifier 变化，[WidthLayoutBuilder] 本身是同一个
/// 实例（只有父级换 builder 时才换），就像 Scaffold 随键盘逐帧缩小 body。
class _Bench {
  _Bench() {
    layoutBuilder = _make('a');
  }

  final size = ValueNotifier<Size>(const Size(300, 500));
  final shade = ValueNotifier<int>(0);
  final calls = <String>[];
  late WidthLayoutBuilder layoutBuilder;

  WidthLayoutBuilder _make(String label) => WidthLayoutBuilder(
    builder: (BuildContext context, double maxWidth) {
      final value = _Shade.of(context);
      calls.add('$label:${maxWidth.toInt()}:$value');
      return Text('$label $value', textDirection: TextDirection.ltr);
    },
  );

  /// 模拟父级重建并传入新的 builder。
  void replaceBuilder(String label) => layoutBuilder = _make(label);

  Widget build() => ValueListenableBuilder<int>(
    valueListenable: shade,
    builder: (BuildContext context, int value, Widget? _) => _Shade(
      value: value,
      child: Align(
        alignment: Alignment.topLeft,
        child: ValueListenableBuilder<Size>(
          valueListenable: size,
          builder: (BuildContext context, Size size, Widget? child) =>
              SizedBox(width: size.width, height: size.height, child: child),
          child: layoutBuilder,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('height-only changes reuse the built subtree', (tester) async {
    final bench = _Bench();
    await tester.pumpWidget(bench.build());
    expect(bench.calls, <String>['a:300:0']);

    for (final height in <double>[450, 400, 350]) {
      bench.size.value = Size(300, height);
      await tester.pump();
    }
    expect(bench.calls, <String>['a:300:0']);
    expect(tester.getSize(find.byType(WidthLayoutBuilder)).height, 350);
  });

  testWidgets('width changes rebuild', (tester) async {
    final bench = _Bench();
    await tester.pumpWidget(bench.build());
    bench.size.value = const Size(200, 500);
    await tester.pump();
    expect(bench.calls, <String>['a:300:0', 'a:200:0']);
  });

  testWidgets('a changed dependency rebuilds even in the same frame as a '
      'height change', (tester) async {
    final bench = _Bench();
    await tester.pumpWidget(bench.build());
    bench
      ..size.value = const Size(300, 420)
      ..shade.value = 1;
    await tester.pump();
    expect(bench.calls, <String>['a:300:0', 'a:300:1']);
    expect(find.text('a 1'), findsOneWidget);
  });

  testWidgets('a new builder from the parent rebuilds', (tester) async {
    final bench = _Bench();
    await tester.pumpWidget(bench.build());
    bench
      ..replaceBuilder('b')
      ..size.value = const Size(300, 420);
    await tester.pumpWidget(bench.build());
    expect(bench.calls, <String>['a:300:0', 'b:300:0']);
    expect(find.text('b 0'), findsOneWidget);
  });
}
