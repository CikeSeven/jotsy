import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/app_color_scheme.dart';
import 'package:node_diary/ui/widgets/color_palette_families.dart';

// 官网“主题色”面板的配色数据（docs/assets/data/themes.json）与应用同源：
// 色板取 kColorPaletteFamilies，每个种子色的明暗两套配色经
// appColorSchemeFromSeed 生成。改了色板或配色算法时这里会失败，用
//   flutter test test/app/theme/site_theme_export_test.dart \
//     --dart-define=UPDATE_SITE_THEMES=true
// 重新导出。官网只列统一色板的 80 个色，不含主题色专用的“黑白”。

const _update = bool.fromEnvironment('UPDATE_SITE_THEMES');
const _path = 'docs/assets/data/themes.json';

/// 官网 CSS 色槽（`--c-*`）与配色色槽的对应，顺序即数据里的打包顺序。
final List<(String, Color Function(ColorScheme))> _roles =
    <(String, Color Function(ColorScheme))>[
      ('primary', (s) => s.primary),
      ('on-primary', (s) => s.onPrimary),
      ('primary-container', (s) => s.primaryContainer),
      ('on-primary-container', (s) => s.onPrimaryContainer),
      ('secondary', (s) => s.secondary),
      ('on-secondary', (s) => s.onSecondary),
      ('secondary-container', (s) => s.secondaryContainer),
      ('on-secondary-container', (s) => s.onSecondaryContainer),
      ('tertiary', (s) => s.tertiary),
      ('on-tertiary', (s) => s.onTertiary),
      ('tertiary-container', (s) => s.tertiaryContainer),
      ('on-tertiary-container', (s) => s.onTertiaryContainer),
      ('surface', (s) => s.surface),
      ('on-surface', (s) => s.onSurface),
      ('on-surface-variant', (s) => s.onSurfaceVariant),
      ('surface-lowest', (s) => s.surfaceContainerLowest),
      ('surface-low', (s) => s.surfaceContainerLow),
      ('surface-container', (s) => s.surfaceContainer),
      ('surface-high', (s) => s.surfaceContainerHigh),
      ('surface-highest', (s) => s.surfaceContainerHighest),
      ('outline', (s) => s.outline),
      ('outline-variant', (s) => s.outlineVariant),
      ('inverse-surface', (s) => s.inverseSurface),
      ('inverse-on-surface', (s) => s.onInverseSurface),
      ('inverse-primary', (s) => s.inversePrimary),
    ];

String _hex(Color color) =>
    (color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');

String _packed(Color seed, Brightness brightness) {
  final scheme = appColorSchemeFromSeed(seed, brightness);
  return _roles.map((r) => _hex(r.$2(scheme))).join();
}

Map<String, Object> _expected() {
  final schemes = <String, List<String>>{
    for (final family in kColorPaletteFamilies)
      for (final seed in family.colors)
        _hex(seed): <String>[
          _packed(seed, Brightness.light),
          _packed(seed, Brightness.dark),
        ],
  };
  // 数据最早由浏览器的 JSON.stringify 写出：JS 对象里形如数组下标的键（不带
  // 前导零的纯数字，如 616161；006064 不算）排在最前、按数值升序。沿用同一
  // 顺序，重新导出时 diff 只落在真正变了的配色上。
  final numeric = schemes.keys
      .where((k) => RegExp(r'^(0|[1-9]\d*)$').hasMatch(k))
      .toList();
  final ordered = <String, List<String>>{
    for (final key in numeric..sort((a, b) => int.parse(a) - int.parse(b)))
      key: schemes[key]!,
    for (final entry in schemes.entries)
      if (!numeric.contains(entry.key)) entry.key: entry.value,
  };
  return <String, Object>{
    'roles': _roles.map((r) => r.$1).toList(),
    'families': <List<String>>[
      for (final family in kColorPaletteFamilies)
        family.colors.map(_hex).toList(),
    ],
    'schemes': ordered,
  };
}

void main() {
  test('website theme data matches the app theme colors', () {
    final expected = _expected();
    final file = File(_path);
    if (_update) {
      file.writeAsStringSync(jsonEncode(expected));
    }
    final actual = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(actual['roles'], expected['roles']);
    expect(actual['families'], expected['families']);
    final actualSchemes = actual['schemes'] as Map<String, dynamic>;
    final expectedSchemes = expected['schemes']! as Map<String, List<String>>;
    final stale = <String>[
      for (final entry in expectedSchemes.entries)
        if (!listEquals(
          (actualSchemes[entry.key] as List<dynamic>?)?.cast<String>(),
          entry.value,
        ))
          entry.key,
    ];
    expect(
      stale,
      isEmpty,
      reason:
          '$_path 与应用配色不一致，用 --dart-define=UPDATE_SITE_THEMES=true '
          '重新导出',
    );
    expect(actualSchemes.keys.toSet(), expectedSchemes.keys.toSet());
  });
}
