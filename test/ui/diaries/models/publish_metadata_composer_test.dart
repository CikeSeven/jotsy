import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_location.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/models/publish_metadata_composer.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';

void main() {
  final generatedAt = DateTime(2026, 10, 16, 9, 30);
  const address = <String, Object?>{
    'province': '北京市',
    'district': '朝阳区',
    'township': '望京街道',
  };
  const located = DiaryMetaDraft(
    cover: '/covers/a.jpg',
    tagIds: {3, 1},
    location: '北京市 · 望京街道',
    locationAddressComponent: address,
    locationLatitude: 39.98941,
    locationLongitude: 116.480881,
    locationFromAuto: true,
    locationPrecision: DiaryLocationPrecision.city,
    weather: 'Sunny 24°C',
    weatherIconCode: '100',
    moodEmoji: '🙂',
    energyLevel: 4,
  );

  Map<String, Object?> decode(String raw) =>
      jsonDecode(raw) as Map<String, Object?>;

  group('composeDraft ↔ parse', () {
    test('context fields survive a round trip', () {
      final raw = PublishMetadataComposer.composeDraft(
        draft: located,
        contentText: 'A walk in the park',
        generatedAt: generatedAt,
        deviceInfo: const {'platform': 'android'},
      );
      final metadata = decode(raw);
      expect(metadata['tagIds'], [1, 3]);
      expect(metadata['hasCover'], isTrue);
      expect(metadata.containsKey('capsule'), isFalse);

      final parsed = PublishMetadataComposer.parse(raw);
      // 封面与标签是日记表的列，不从 metadata 读回。
      expect(
        parsed,
        located.copyWith(
          cover: null,
          tagIds: const <int>{},
          locationAddressComponent: parsed.locationAddressComponent,
        ),
      );
      expect(parsed.locationAddressComponent, address);
    });

    test('a capsule block is written only with a lock time', () {
      final capsule = TimeCapsuleSchedule(
        unlockAt: DateTime(2027, 1, 1, 18, 45),
        precision: TimeCapsulePrecision.date,
      );
      final draft = located.copyWith(capsule: capsule);
      final returned = decode(
        PublishMetadataComposer.composeDraft(
          draft: draft,
          contentText: '',
          generatedAt: generatedAt,
        ),
      );
      expect(returned.containsKey('capsule'), isFalse);

      final sealed = decode(
        PublishMetadataComposer.composeDraft(
          draft: draft,
          contentText: '',
          generatedAt: generatedAt,
          capsuleLockedAt: generatedAt,
        ),
      );
      expect(sealed['capsule'], {
        'lockedAt': generatedAt.toIso8601String(),
        'unlockAt': DateTime(2027).toIso8601String(),
        'precision': 'date',
      });
    });

    test('keys the composer does not own are preserved', () {
      final metadata = decode(
        PublishMetadataComposer.composeDraft(
          draft: located,
          contentText: '',
          generatedAt: generatedAt,
          preserve: const {
            'import': {'source': 'dayOne'},
            'capsule': {'unlockAt': '2025-02-01T00:00:00.000'},
            'context': {'location': 'stale'},
          },
        ),
      );
      expect(metadata['import'], {'source': 'dayOne'});
      expect(metadata['capsule'], {'unlockAt': '2025-02-01T00:00:00.000'});
      expect((metadata['context'] as Map)['location'], located.location);
    });

    test('legacy and malformed metadata parse leniently', () {
      expect(PublishMetadataComposer.parse('not json'), const DiaryMetaDraft());
      expect(PublishMetadataComposer.parse('[]'), const DiaryMetaDraft());
      expect(PublishMetadataComposer.parse('{}'), const DiaryMetaDraft());
      final legacy = PublishMetadataComposer.parse(
        '{"context":{"energyLevel":"7","moodEmoji":"  "}}',
      );
      expect(legacy.energyLevel, 5);
      expect(legacy.moodEmoji, isNull);
      expect(legacy.locationFromAuto, isFalse);
    });
  });

  group('DiaryMetaDraft', () {
    test('round trips through the editor ↔ publisher draft', () {
      final capsule = TimeCapsuleSchedule(
        unlockAt: DateTime(2027, 1, 1),
        precision: TimeCapsulePrecision.date,
      );
      final draft = located.copyWith(capsule: capsule);
      const base = NewDiaryDraft(
        title: 'A walk',
        contentDocJson: '[]',
        contentText: '',
      );
      final carried = draft.applyTo(base);
      expect(carried.title, 'A walk');
      expect(carried.capsulePrecision, 'date');
      expect(DiaryMetaDraft.fromNewDiaryDraft(carried), draft);
    });

    test('blank text and out-of-range energy are normalised', () {
      final draft = DiaryMetaDraft.fromNewDiaryDraft(
        const NewDiaryDraft(
          title: '',
          contentDocJson: '',
          contentText: '',
          cover: '  ',
          weather: ' ',
          energyLevel: 9,
        ),
      );
      expect(draft.cover, isNull);
      expect(draft.weather, isNull);
      expect(draft.energyLevel, 5);
    });

    test('copyWith clears a field only when null is passed', () {
      expect(located.copyWith().moodEmoji, '🙂');
      expect(located.copyWith(moodEmoji: null).moodEmoji, isNull);
      expect(located.copyWith(energyLevel: null), isNot(located));
      expect(located.copyWith(tagIds: {1, 3}), located);
    });
  });
}
