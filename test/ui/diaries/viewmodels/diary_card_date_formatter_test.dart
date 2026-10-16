import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_date_formatter.dart';
import 'package:node_diary/utils/relative_time_formatter.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('zh');
    await initializeDateFormatting('en');
  });

  final now = DateTime(2026, 10, 16, 21, 30);
  final written = DateTime(2026, 10, 13, 9, 5);
  final edited = DateTime(2026, 10, 16, 18, 0);

  for (final locale in <String>['zh', 'en']) {
    group('DiaryCardDateFormatter ($locale)', () {
      late AppLocalizations l10n;
      setUp(() async {
        l10n = await AppLocalizations.delegate.load(Locale(locale));
      });

      String eyebrow(DiaryCardMetaStyle meta) => DiaryCardDateFormatter.eyebrow(
        l10n: l10n,
        meta: meta,
        createdAt: written,
        updatedAt: edited,
        now: now,
      );

      test('the default eyebrow is the legacy eyebrow date', () {
        expect(
          eyebrow(const DiaryCardMetaStyle()),
          l10n.formatEyebrowDate(written),
        );
      });

      test('formats, weekday, time and date source combine', () {
        expect(
          eyebrow(const DiaryCardMetaStyle(showWeekday: false)),
          l10n.formatMonthDay(written),
        );
        expect(
          eyebrow(
            const DiaryCardMetaStyle(
              dateFormat: DiaryCardDateFormat.full,
              showWeekday: false,
            ),
          ),
          l10n.formatFullDate(written),
        );
        final numeric = eyebrow(
          const DiaryCardMetaStyle(
            dateFormat: DiaryCardDateFormat.numeric,
            showWeekday: false,
            showTime: true,
          ),
        );
        expect(numeric, contains('2026'));
        expect(numeric, endsWith('09:05'));
        final full = eyebrow(
          const DiaryCardMetaStyle(dateFormat: DiaryCardDateFormat.full),
        );
        expect(full, startsWith(l10n.formatFullDate(written)));
        expect(full, contains(' · '));
        expect(
          eyebrow(
            const DiaryCardMetaStyle(
              showWeekday: false,
              dateSource: DiaryCardDateSource.updated,
            ),
          ),
          l10n.formatMonthDay(edited),
        );
      });

      test('relative dates ignore the weekday and time', () {
        expect(
          eyebrow(
            const DiaryCardMetaStyle(
              dateFormat: DiaryCardDateFormat.relative,
              showTime: true,
            ),
          ),
          RelativeTimeFormatter.formatUpdatedAt(
            updatedAt: written,
            now: now,
            l10n: l10n,
          ),
        );
      });

      test('footer modes', () {
        String? footer(DiaryCardFooterTime mode) =>
            DiaryCardDateFormatter.footer(
              l10n: l10n,
              mode: mode,
              createdAt: written,
              updatedAt: edited,
              now: now,
            );
        expect(
          footer(DiaryCardFooterTime.relativeUpdated),
          RelativeTimeFormatter.formatUpdatedAt(
            updatedAt: edited,
            now: now,
            l10n: l10n,
          ),
        );
        expect(
          footer(DiaryCardFooterTime.absoluteUpdated),
          l10n.diaryCardFooterUpdated(l10n.formatPreciseDateTime(edited, now)),
        );
        expect(
          footer(DiaryCardFooterTime.created),
          l10n.diaryCardFooterCreated(l10n.formatPreciseDateTime(written, now)),
        );
        expect(footer(DiaryCardFooterTime.hidden), isNull);
      });
    });
  }
}
