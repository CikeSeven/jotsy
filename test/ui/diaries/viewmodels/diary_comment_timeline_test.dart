import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_comment_timeline.dart';

void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));
  final diary = DateTime(2025, 1, 31, 22);

  String label(DateTime comment, [AppLocalizations? l10n]) =>
      diaryCommentRelativeLabel(l10n ?? zh, diary, comment);

  group('relative label', () {
    test('the same calendar day reads as written that day', () {
      expect(label(DateTime(2025, 1, 31, 23, 59)), '当天写下');
      // 时刻早于日记（日记时间被改到了以后）按当天处理，不出现负数。
      expect(label(DateTime(2025, 1, 30)), '当天写下');
    });

    test('counts calendar days, not 24-hour spans', () {
      expect(label(DateTime(2025, 2, 1, 0, 5)), '写下后 1 天');
      expect(label(DateTime(2025, 2, 27)), '写下后 27 天');
    });

    test('a calendar month is whole only once the day is reached', () {
      // 1 月 31 日到 2 月 28 日还不满一个月。
      expect(label(DateTime(2025, 2, 28)), '写下后 28 天');
      expect(label(DateTime(2025, 3, 31)), '写下后 2 个月');
      expect(label(DateTime(2025, 12, 31)), '写下后 11 个月');
    });

    test('years with and without leftover months', () {
      expect(label(DateTime(2026, 1, 31)), '写下后 1 年');
      expect(label(DateTime(2027, 4, 1)), '写下后 2 年 2 个月');
      expect(label(DateTime(2027, 4, 1), en), '2 years, 2 months later');
      expect(label(DateTime(2025, 2, 1), en), '1 day later');
    });

    test('day gap ignores the time of day', () {
      expect(diaryCommentDayGap(diary, DateTime(2025, 2, 1, 0, 1)), 1);
      expect(diaryCommentDayGap(diary, DateTime(2025, 1, 31, 23)), 0);
    });
  });

  group('fold', () {
    List<int> items(int count) => List<int>.generate(count, (i) => i);

    test('up to five comments are all shown', () {
      final fold = DiaryCommentFold<int>.of(items(5), expanded: false);
      expect(fold.folded, isFalse);
      expect(fold.head, items(5));
      expect(fold.tail, isEmpty);
    });

    test('more than five keep the first one and the latest three', () {
      final fold = DiaryCommentFold<int>.of(items(9), expanded: false);
      expect(fold.head, <int>[0]);
      expect(fold.hiddenCount, 5);
      expect(fold.tail, <int>[6, 7, 8]);
    });

    test('expanded shows everything', () {
      final fold = DiaryCommentFold<int>.of(items(9), expanded: true);
      expect(fold.folded, isFalse);
      expect(fold.head, items(9));
    });
  });
}
