import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/qweather_icon.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('weather icons follow the theme color (${brightness.name})', (
      tester,
    ) async {
      final theme = ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1E6586),
        brightness: brightness,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(body: QWeatherIcon(iconCode: '100')),
        ),
      );

      // 图标 SVG 以 currentColor 着色；未设置时 flutter_svg 画成黑色，暗色
      // 主题下看不见。
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        (svg.bytesLoader as SvgAssetLoader).theme?.currentColor,
        theme.colorScheme.onSurfaceVariant,
      );
    });
  }

  testWidgets('an explicit color tints the icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QWeatherIcon(iconCode: '100', fallbackColor: Color(0xFF123456)),
        ),
      ),
    );

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(
      (svg.bytesLoader as SvgAssetLoader).theme?.currentColor,
      const Color(0xFF123456),
    );
  });
}
