import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color, Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_kind.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_languages.dart';
import 'package:node_diary/l10n/app_localizations_gen.dart';
import 'package:node_diary/ui/home_widgets/viewmodels/home_widget_sample_data.dart';

/// 预览图用的示例快照（每种界面语言一份），Kotlin 的预览图生成
/// （`WidgetPreviewImageTest`）读它。格式一变这里就失败，用
/// `UPDATE_WIDGET_FIXTURE=1` 重新生成后再重画预览图。
String _samplePath(String language) =>
    'android/app/src/test/resources/widget_sample_$language.json';

final DateTime _now = DateTime(2026, 11, 15, 10);

Future<Map<String, Object?>> _sample(String language) =>
    buildHomeWidgetSampleSnapshot(
      now: _now,
      l10n: lookupAppLocalizations(Locale(language)),
      appSeed: const Color(SettingsService.defaultThemeSeedColorValue),
    );

Map<String, Object?> _map(Object? value) =>
    (value! as Map).cast<String, Object?>();

void main() {
  test('the sample covers every kind with content', () async {
    final sample = await _sample('zh');
    expect(sample['redacted'], isFalse);
    expect(
      _map(sample['defaults']).keys,
      unorderedEquals(HomeWidgetKind.values.map((kind) => kind.id)),
    );
    for (final section in <String>[
      'today',
      'anniversaries',
      'todos',
      'calendar',
      'onThisDay',
      'recent',
      'photos',
      'stats',
      'diaries',
    ]) {
      expect(sample[section], isNotNull, reason: section);
    }
    final today = _map(_map(_map(sample['onThisDay'])['days'])['2026-11-15']);
    expect((today['sameDay']! as List).length, 2);
    expect(
      (_map(sample['photos'])['all']! as List),
      containsAll(<String>['sample-run', 'sample-sea']),
    );
    expect(_map(sample['stats'])['streak'], greaterThanOrEqualTo(7));
    // 示例照片不是文件路径：原生按名字画。
    expect(
      _map(_map(sample['diaries'])['sample-sea'])['photo'],
      '${kHomeWidgetSamplePhotoScheme}sunset',
    );
  });

  test('the sample follows the interface language', () async {
    final en = await _sample('en');
    final title = _map(_map(en['diaries'])['sample-sea'])['title'];
    expect(
      title,
      lookupAppLocalizations(const Locale('en')).homeWidgetSampleDiaryTitle1,
    );
  });

  test('the preview image fixtures match the sample builder', () async {
    for (final language in appLanguages) {
      final sample = await _sample(language.code);
      final encoded = '${const JsonEncoder.withIndent('  ').convert(sample)}\n';
      final file = File(_samplePath(language.code));
      if (Platform.environment['UPDATE_WIDGET_FIXTURE'] == '1') {
        file.writeAsStringSync(encoded);
      }
      expect(file.readAsStringSync(), encoded, reason: language.code);
    }
  });
}
