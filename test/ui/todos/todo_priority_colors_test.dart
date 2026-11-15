import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/app_color_scheme.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_priority_colors.dart';
import 'package:node_diary/ui/todos/widgets/todo_labels.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

const List<TodoPriority> _set = <TodoPriority>[
  TodoPriority.low,
  TodoPriority.medium,
  TodoPriority.high,
];

void main() {
  for (final brightness in Brightness.values) {
    group('${brightness.name} theme', () {
      final blue = appColorSchemeFromSeed(const Color(0xFF1565C0), brightness);
      final gray = appColorSchemeFromSeed(const Color(0xFF9E9E9E), brightness);
      final mono = appColorSchemeFromSeed(
        const Color(kMonochromeThemeSeedValue),
        brightness,
      );

      test('no priority has no colors and keeps the default box', () {
        expect(TodoPriorityColors.of(blue, TodoPriority.none), isNull);
        expect(TodoLabels.priorityColor(blue, TodoPriority.none), isNull);
        expect(TodoLabels.priorityOnColor(blue, TodoPriority.none), isNull);
      });

      test('the three priorities differ and ignore the theme color', () {
        final accents = <Color>{
          for (final p in _set) TodoPriorityColors.of(blue, p)!.accent,
        };
        expect(accents, hasLength(3));
        for (final p in _set) {
          final colors = TodoPriorityColors.of(blue, p)!;
          // 灰色与黑白主题里也是同样的红橙蓝，不会变成灰。
          expect(TodoPriorityColors.of(gray, p)!.accent, colors.accent);
          expect(TodoPriorityColors.of(mono, p)!.accent, colors.accent);
          expect(TodoLabels.priorityColor(mono, p), colors.accent);
          expect(TodoLabels.priorityOnColor(mono, p), colors.onAccent);
        }
      });

      test('colors stay readable on the page surface', () {
        for (final p in _set) {
          final colors = TodoPriorityColors.of(blue, p)!;
          final surface = blue.surfaceContainerLowest;
          // 描边与旗子：非文字元素 3:1；对勾：4.5:1。
          expect(_contrast(colors.accent, surface), greaterThanOrEqualTo(3));
          expect(
            _contrast(colors.onAccent, colors.accent),
            greaterThanOrEqualTo(4.5),
          );
          expect(colors.tint.a, lessThan(1), reason: '淡底半透明，叠在玻璃上');
        }
      });
    });
  }
}
