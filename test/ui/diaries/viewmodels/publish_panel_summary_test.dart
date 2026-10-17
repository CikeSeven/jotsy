import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';
import 'package:node_diary/ui/diaries/viewmodels/publish_panel_summary.dart';

void main() {
  Tag tag(int id, String name) => Tag(id: id, name: name, color: 0xff2196f3);
  final tags = [tag(1, 'Life'), tag(2, 'Travel'), tag(3, 'Work')];

  test('nothing chosen gives an empty summary', () {
    expect(publishPanelSummary(const DiaryMetaDraft(), tags), isEmpty);
  });

  test('items come in a fixed order: capsule, mood, weather, tag, place', () {
    final items = publishPanelSummary(
      DiaryMetaDraft(
        tagIds: const {3, 1},
        location: '北京市 · 望京街道',
        weather: 'Sunny 24℃',
        weatherIconCode: '100',
        moodEmoji: '🙂',
        capsule: TimeCapsuleSchedule(
          unlockAt: DateTime(2027),
          precision: TimeCapsulePrecision.date,
        ),
      ),
      tags,
    );
    expect(items.map((item) => item.runtimeType), [
      PublishSummaryCapsule,
      PublishSummaryMood,
      PublishSummaryWeather,
      PublishSummaryTag,
      PublishSummaryPlace,
    ]);
    final tagItem = items[3] as PublishSummaryTag;
    expect(tagItem.tag.name, 'Life');
    expect(tagItem.more, 1);
    expect((items[4] as PublishSummaryPlace).text, '望京街道');
  });

  test('deleted tags are ignored', () {
    final items = publishPanelSummary(const DiaryMetaDraft(tagIds: {9}), tags);
    expect(items, isEmpty);
  });

  test('a short place keeps the most specific level', () {
    expect(shortPlace('北京市 · 朝阳区 · 阜通东大街'), '阜通东大街');
    expect(shortPlace('My cafe'), 'My cafe');
    expect(shortPlace(' · '), '·');
  });
}
