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
