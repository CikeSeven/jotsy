import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';

Widget _host({required bool selection, int count = 3}) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: DiaryHeadSection(
      isSelectionMode: selection,
      selectedCount: count,
      onCancelSelection: () {},
      isPinActionUnpin: false,
      onPinSelected: () {},
      onArchiveSelected: () {},
      onExportSelected: () {},
      onDeleteSelected: () {},
      onOpenArchived: () {},
      onOpenViewOptions: () {},
      onOpenSearchPage: () {},
    ),
  ),
);

void main() {
  testWidgets('selection header shows the selected count and cross-fades', (
    tester,
  ) async {
    await tester.pumpWidget(_host(selection: false));
    expect(find.byKey(const ValueKey<String>('head_default')), findsOneWidget);

    await tester.pumpWidget(_host(selection: true));
    await tester.pump(const Duration(milliseconds: 60));
    // 过渡中两态同时存在（交叉淡入），而不是硬切。
    expect(find.byKey(const ValueKey<String>('head_default')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('head_selection')),
      findsOneWidget,
    );

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('head_default')), findsNothing);
    expect(find.text('已选择 3 项'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduce motion switches the header immediately', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_host(selection: false));
    await tester.pumpWidget(_host(selection: true));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('head_default')), findsNothing);
  });
}
