import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_create_prefs.dart';

void main() {
  test(
    'defaults keep drafts, keep publish panel collapsed and are not stored',
    () {
      expect(DiaryCreatePrefs.defaults.publishOnLeave, isFalse);
      expect(DiaryCreatePrefs.defaults.expandPublishPanel, isFalse);
      expect(DiaryCreatePrefs.defaults.encode(), isNull);
    },
  );

  test('round-trips publishing on leave and auto-expanding publish panel', () {
    const publishOnly = DiaryCreatePrefs(
      leaveAction: DiaryCreateLeaveAction.publish,
    );
    expect(publishOnly.encode(), '{"leave":"publish"}');
    expect(DiaryCreatePrefs.decode(publishOnly.encode()), publishOnly);

    const expandOnly = DiaryCreatePrefs(expandPublishPanel: true);
    final expandRaw = expandOnly.encode();
    expect(expandRaw, '{"expand_publish_panel":true}');
    expect(DiaryCreatePrefs.decode(expandRaw), expandOnly);
    expect(DiaryCreatePrefs.decode(expandRaw).expandPublishPanel, isTrue);
    expect(DiaryCreatePrefs.decode(expandRaw).publishOnLeave, isFalse);

    const both = DiaryCreatePrefs(
      leaveAction: DiaryCreateLeaveAction.publish,
      expandPublishPanel: true,
    );
    expect(DiaryCreatePrefs.decode(both.encode()), both);
  });

  test('broken or unknown values fall back to defaults', () {
    for (final raw in <String?>[
      null,
      '',
      'not json',
      '[1]',
      '{"leave":3,"expand_publish_panel":"yes"}',
      '{"leave":"somethingNewer","expand_publish_panel":1}',
    ]) {
      expect(DiaryCreatePrefs.decode(raw), DiaryCreatePrefs.defaults);
    }
  });
}
