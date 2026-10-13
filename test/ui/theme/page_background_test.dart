import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/ui/widgets/expressive_reorder_proxy.dart';

import '../../support/expressive_test_theme.dart';

void main() {
  test('page canvas and light navigation bar share the seeded surface', () {
    // 暖色种子色下，固定冷灰蓝底栏会与带色调的页面产生接缝。
    final theme = expressiveTestTheme(
      Brightness.light,
      seedColor: const Color(0xFFE91E63),
    );
    final surface = theme.colorScheme.surface;

    expect(ExpressiveSurfaces.pageBackground(theme.colorScheme), surface);
    expect(theme.scaffoldBackgroundColor, surface);
    expect(theme.navigationBarTheme.backgroundColor, surface);
    expect(
      theme.navigationBarTheme.backgroundColor,
      isNot(const Color(0xFFF7F9FC)),
    );
  });

  testWidgets('reorder proxy lifts a rounded card surface', (tester) async {
    final theme = expressiveTestTheme(Brightness.light);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: expressiveReorderProxyDecorator(
            const SizedBox(height: 56, child: Text('dragging')),
            0,
            const AlwaysStoppedAnimation<double>(1),
          ),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find
          .ancestor(of: find.text('dragging'), matching: find.byType(Material))
          .first,
    );
    expect(material.elevation, 3);
    expect(material.color, ExpressiveSurfaces.cardColor(theme.colorScheme));
    final shape = material.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(16));
  });
}
