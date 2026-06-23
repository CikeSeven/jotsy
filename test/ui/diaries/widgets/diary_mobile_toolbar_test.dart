import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';

void main() {
  test('toolbar hidden item codec round-trips and ignores invalid keys', () {
    final hidden = <DiaryToolbarItem>{
      DiaryToolbarItem.bold,
      DiaryToolbarItem.image,
    };

    final raw = encodeDiaryToolbarHiddenItems(hidden);

    expect(raw, 'bold,image');
    expect(decodeDiaryToolbarHiddenItems('$raw,unknown'), containsAll(hidden));
    expect(decodeDiaryToolbarHiddenItems('$raw,unknown').length, hidden.length);
  });

  test('enabled toolbar order filters hidden items but keeps order', () {
    final order = <DiaryToolbarItem>[
      DiaryToolbarItem.image,
      DiaryToolbarItem.bold,
      DiaryToolbarItem.italic,
    ];

    final enabled = filterEnabledDiaryToolbarOrder(order, {
      DiaryToolbarItem.bold,
    });

    expect(enabled.take(2), <DiaryToolbarItem>[
      DiaryToolbarItem.image,
      DiaryToolbarItem.italic,
    ]);
    expect(enabled, isNot(contains(DiaryToolbarItem.bold)));
  });

  test('default toolbar order includes current time tool', () {
    expect(kDefaultDiaryToolbarOrder, contains(DiaryToolbarItem.currentTime));
    expect(DiaryToolbarItem.currentTime.storageKey, 'current_time');
  });

  test('default current time format is prefilled pattern', () {
    expect(kDefaultDiaryToolbarCurrentTimeFormat, 'M月d日 HH:mm');
  });

  testWidgets('current time toolbar button inserts formatted time', (
    tester,
  ) async {
    final controller = quill.QuillController.basic();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ...AppLocalizations.localizationsDelegates,
          quill.FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: 44,
            child: buildDiaryFloatingToolbar(
              controller: controller,
              order: const <DiaryToolbarItem>[DiaryToolbarItem.currentTime],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final now = DateTime.now();
    await tester.tap(find.byTooltip('插入当前时间'));
    await tester.pumpAndSettle();

    final plainText = controller.document.toPlainText();
    expect(plainText, contains('${now.month}月'));
    expect(plainText, contains('${now.day}日'));
    expect(plainText, contains(':'));
    expect(plainText, isNot(contains('${now.year}')));
  });

  testWidgets('current time toolbar button uses custom format', (tester) async {
    final controller = quill.QuillController.basic();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ...AppLocalizations.localizationsDelegates,
          quill.FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: 44,
            child: buildDiaryFloatingToolbar(
              controller: controller,
              order: const <DiaryToolbarItem>[DiaryToolbarItem.currentTime],
              currentTimeFormatPattern: 'yyyy/MM/dd HH:mm',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final now = DateTime.now();
    await tester.tap(find.byTooltip('插入当前时间'));
    await tester.pumpAndSettle();

    final plainText = controller.document.toPlainText();
    expect(plainText, contains('${now.year}/'));
    expect(plainText, contains('/'));
    expect(plainText, contains(':'));
    expect(plainText, isNot(contains('年')));
  });

  test(
    'current time format validator accepts empty and DateFormat patterns',
    () {
      final l10n = lookupAppLocalizations(const Locale('zh'));

      expect(isValidDiaryToolbarCurrentTimeFormat(l10n, ''), isTrue);
      expect(
        isValidDiaryToolbarCurrentTimeFormat(l10n, 'yyyy-MM-dd HH:mm'),
        isTrue,
      );
    },
  );

  testWidgets('floating toolbar hides unchecked tools', (tester) async {
    final controller = quill.QuillController.basic();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ...AppLocalizations.localizationsDelegates,
          quill.FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: 44,
            child: buildDiaryFloatingToolbar(
              controller: controller,
              order: const <DiaryToolbarItem>[
                DiaryToolbarItem.bold,
                DiaryToolbarItem.italic,
              ],
              hiddenItems: const <DiaryToolbarItem>{DiaryToolbarItem.bold},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(FontAwesomeIcons.bold), findsNothing);
    expect(find.byIcon(FontAwesomeIcons.italic), findsOneWidget);
  });
}
