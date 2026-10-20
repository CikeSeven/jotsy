import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/code_block_codec.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_language.dart';

void main() {
  group('kDiaryCodeLanguages', () {
    test('lists every codec language in codec order with its name', () {
      expect(
        kDiaryCodeLanguages.map((language) => language.id).toList(),
        kDiaryCodeLanguageIds,
      );
      for (final language in kDiaryCodeLanguages) {
        expect(language.name, kDiaryCodeLanguageNames[language.id]);
      }
    });

    test('every id resolves and unknown ids do not', () {
      for (final id in kDiaryCodeLanguageIds) {
        expect(diaryCodeLanguageById(id)?.id, id);
      }
      expect(diaryCodeLanguageById('plain'), isNull);
      expect(diaryCodeLanguageById('cobol'), isNull);
    });
  });

  group('DiaryCodeLanguageChoice', () {
    test('reads attribute values and round-trips them', () {
      final auto = DiaryCodeLanguageChoice.fromAttributeValue(true);
      expect(auto, DiaryCodeLanguageChoice.auto);
      expect(auto.isAuto, isTrue);
      expect(auto.attributeValue, isTrue);
      expect(auto.languageId, isNull);

      final plain = DiaryCodeLanguageChoice.fromAttributeValue('plain');
      expect(plain, DiaryCodeLanguageChoice.plain);
      expect(plain.isPlain, isTrue);
      expect(plain.attributeValue, kCodeBlockPlain);
      expect(plain.languageId, isNull);

      final python = DiaryCodeLanguageChoice.fromAttributeValue('python');
      expect(python, const DiaryCodeLanguageChoice.explicit('python'));
      expect(python.attributeValue, 'python');
      expect(python.languageId, 'python');
      expect(
        python.hashCode,
        const DiaryCodeLanguageChoice.explicit('python').hashCode,
      );
      expect(
        DiaryCodeLanguageChoice.fromAttributeValue(python.attributeValue),
        python,
      );
    });

    test('unknown or missing values fall back to auto', () {
      for (final value in <Object?>['weird', null, false, 42, '']) {
        expect(
          DiaryCodeLanguageChoice.fromAttributeValue(value),
          DiaryCodeLanguageChoice.auto,
          reason: '$value',
        );
      }
    });

    test('aliases normalize to the canonical id', () {
      expect(
        DiaryCodeLanguageChoice.fromAttributeValue('py').languageId,
        'python',
      );
      expect(
        DiaryCodeLanguageChoice.fromAttributeValue('text'),
        DiaryCodeLanguageChoice.plain,
      );
    });

    test('distinct choices are not equal', () {
      expect(
        DiaryCodeLanguageChoice.auto == DiaryCodeLanguageChoice.plain,
        isFalse,
      );
      expect(
        const DiaryCodeLanguageChoice.explicit('dart') ==
            const DiaryCodeLanguageChoice.explicit('go'),
        isFalse,
      );
    });
  });
}
