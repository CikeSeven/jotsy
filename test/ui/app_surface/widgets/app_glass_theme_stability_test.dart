import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/derived_theme_cache.dart';
import 'package:node_diary/ui/app_surface/models/app_glass_style.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_controls_theme.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_scope.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_snack_bar_theme.dart';

import '../../../support/expressive_test_theme.dart';

/// 记录主题依赖变化的次数（didChangeDependencies 只在依赖真的通知时调用）。
class _ThemeReader extends StatefulWidget {
  const _ThemeReader(this.onChange);

  final VoidCallback onChange;

  @override
  State<_ThemeReader> createState() => _ThemeReaderState();
}

class _ThemeReaderState extends State<_ThemeReader> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Theme.of(context);
    widget.onChange();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  testWidgets('glass control themes do not notify the app on every keyboard '
      'frame', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        // 与应用壳相同：builder 读整份 MediaQuery，键盘升降时逐帧重建，
        // 玻璃主题覆盖挂在里面。
        builder: (BuildContext context, Widget? child) {
          MediaQuery.of(context);
          return AppGlassScope(
            style: const AppGlassStyle(mode: AppGlassMode.glass),
            child: AppGlassSnackBarTheme(
              child: AppGlassControlsTheme(child: child!),
            ),
          );
        },
        home: _ThemeReader(() => changes++),
      ),
    );
    final before = changes;
    expect(
      Theme.of(
        tester.element(find.byType(_ThemeReader)),
      ).chipTheme.backgroundColor,
      isNotNull,
      reason: 'glass control colors are applied',
    );

    for (final inset in <double>[60, 120, 180, 240, 300, 200, 100, 0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(changes, before);
  });

  test('DerivedThemeCache reuses the result for an equal base theme', () {
    final cache = DerivedThemeCache<int>();
    final base = ThemeData(useMaterial3: true);
    var derivations = 0;
    ThemeData derive() {
      derivations++;
      return base.copyWith(
        switchTheme: SwitchThemeData(
          trackColor: WidgetStateProperty.resolveWith((_) => null),
        ),
      );
    }

    final first = cache.resolve(base, 1, derive);
    // Theme.of 返回的本地化副本：内容相同、实例不同。
    final copy = base.copyWith();
    expect(identical(copy, base), isFalse);
    expect(identical(cache.resolve(copy, 1, derive), first), isTrue);
    expect(derivations, 1);

    // 派生参数或基础主题变了时重新派生。
    expect(identical(cache.resolve(copy, 2, derive), first), isFalse);
    final dark = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    expect(identical(cache.resolve(dark, 1, derive), first), isFalse);
    expect(derivations, 3);
  });
}
