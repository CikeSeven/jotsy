import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_edit_prefs.dart';

void main() {
  test(
    'defaults save automatically, keep media full size and are not stored',
    () {
      expect(DiaryEditPrefs.defaults.manualSave, isFalse);
      expect(DiaryEditPrefs.defaults.defaultMediaThumbnail, isFalse);
      expect(DiaryEditPrefs.defaults.encode(), isNull);
    },
  );

  test('round-trips manual saving and default media thumbnail', () {
    const manualOnly = DiaryEditPrefs(saveMode: DiaryEditSaveMode.manual);
    expect(manualOnly.encode(), '{"save":"manual"}');
    expect(DiaryEditPrefs.decode(manualOnly.encode()), manualOnly);

    const thumbnailOnly = DiaryEditPrefs(defaultMediaThumbnail: true);
    final thumbRaw = thumbnailOnly.encode();
    expect(thumbRaw, '{"default_media_thumbnail":true}');
    expect(DiaryEditPrefs.decode(thumbRaw), thumbnailOnly);
    expect(DiaryEditPrefs.decode(thumbRaw).defaultMediaThumbnail, isTrue);
    expect(DiaryEditPrefs.decode(thumbRaw).manualSave, isFalse);

    const both = DiaryEditPrefs(
      saveMode: DiaryEditSaveMode.manual,
      defaultMediaThumbnail: true,
    );
    expect(DiaryEditPrefs.decode(both.encode()), both);
  });

  test('broken or unknown values fall back to defaults', () {
    for (final raw in <String?>[
      null,
      '',
      'not json',
      '[1]',
      '{"save":3,"default_media_thumbnail":"yes"}',
      '{"save":"somethingNewer","default_media_thumbnail":1}',
    ]) {
      expect(DiaryEditPrefs.decode(raw), DiaryEditPrefs.defaults);
    }
  });
}
