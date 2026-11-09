import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_edit_prefs.dart';

void main() {
  test('defaults save automatically and are not stored', () {
    expect(DiaryEditPrefs.defaults.manualSave, isFalse);
    expect(DiaryEditPrefs.defaults.encode(), isNull);
  });

  test('round-trips manual saving', () {
    const prefs = DiaryEditPrefs(saveMode: DiaryEditSaveMode.manual);
    final raw = prefs.encode();
    expect(raw, '{"save":"manual"}');
    expect(DiaryEditPrefs.decode(raw), prefs);
    expect(DiaryEditPrefs.decode(raw).manualSave, isTrue);
  });

  test('broken or unknown values fall back to saving automatically', () {
    for (final raw in <String?>[
      null,
      '',
      'not json',
      '[1]',
      '{"save":3}',
      '{"save":"somethingNewer"}',
    ]) {
      expect(DiaryEditPrefs.decode(raw), DiaryEditPrefs.defaults);
    }
  });
}
