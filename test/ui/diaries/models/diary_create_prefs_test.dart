import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_create_prefs.dart';

void main() {
  test('defaults keep drafts and are not stored', () {
    expect(DiaryCreatePrefs.defaults.publishOnLeave, isFalse);
    expect(DiaryCreatePrefs.defaults.encode(), isNull);
  });

  test('round-trips publishing on leave', () {
    const prefs = DiaryCreatePrefs(leaveAction: DiaryCreateLeaveAction.publish);
    final raw = prefs.encode();
    expect(raw, '{"leave":"publish"}');
    expect(DiaryCreatePrefs.decode(raw), prefs);
    expect(DiaryCreatePrefs.decode(raw).publishOnLeave, isTrue);
  });

  test('broken or unknown values fall back to keeping drafts', () {
    for (final raw in <String?>[
      null,
      '',
      'not json',
      '[1]',
      '{"leave":3}',
      '{"leave":"somethingNewer"}',
    ]) {
      expect(DiaryCreatePrefs.decode(raw), DiaryCreatePrefs.defaults);
    }
  });
}
