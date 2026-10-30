import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/ui/lan_sync/widgets/lan_sync_well_color.dart';

import '../../support/expressive_test_theme.dart';

Future<Color> _wellIn(WidgetTester tester, ThemeData theme) async {
  late Color well;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (BuildContext context) {
          well = lanSyncWellColor(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return well;
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'the well stands out from sheets and cards in ${brightness.name} theme',
      (tester) async {
        final theme = expressiveTestTheme(brightness);
        final well = await _wellIn(tester, theme);
        expect(well, isNot(theme.bottomSheetTheme.backgroundColor));
        expect(well, isNot(theme.bottomSheetTheme.modalBackgroundColor));
        expect(well, isNot(ExpressiveSurfaces.cardColor(theme.colorScheme)));
      },
    );
  }

  testWidgets('dark theme lifts the well to surfaceContainerHigh', (
    tester,
  ) async {
    final theme = expressiveTestTheme(Brightness.dark);
    expect(
      await _wellIn(tester, theme),
      theme.colorScheme.surfaceContainerHigh,
    );
  });
}
