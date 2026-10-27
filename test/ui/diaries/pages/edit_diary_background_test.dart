import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_settings.dart';
import 'package:node_diary/ui/app_surface/widgets/app_background_layers_view.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

const Size _view = Size(400, 900);
const Color _editorColor = Color(0xFFE8DCC4);

String _editorColorRaw() => AppSurfaceSettings.defaults
    .withArea(
      AppBackgroundArea.editor,
      AppAreaBackground(
        mode: AppAreaBackgroundMode.custom,
        custom: AppBackground(
          kind: AppBackgroundKind.color,
          colorLight: _editorColor.toARGB32(),
        ),
      ),
    )
    .encode()!;

Future<void> _pumpEditor(WidgetTester tester, {String? appSurfaceRaw}) async {
  tester.view.physicalSize = _view;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app.settings.app_surface': ?appSurfaceRaw,
  });
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  final settings = await SettingsService.create();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          quill.AppFlowyEditorLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

Scaffold _pageScaffold(WidgetTester tester) => tester.widget<Scaffold>(
  find
      .descendant(
        of: find.byType(EditDiaryPage),
        matching: find.byType(Scaffold),
      )
      .first,
);

void main() {
  testWidgets('without a background the editor page is unchanged', (
    tester,
  ) async {
    await _pumpEditor(tester);
    final scheme = Theme.of(
      tester.element(find.byType(EditDiaryPage)),
    ).colorScheme;
    expect(_pageScaffold(tester).backgroundColor, scheme.surface);
    expect(find.byType(AppBackgroundLayersView), findsNothing);
    await _unmount(tester);
  });

  testWidgets('the editor area background shows through a clear page', (
    tester,
  ) async {
    await _pumpEditor(tester, appSurfaceRaw: _editorColorRaw());
    expect(_pageScaffold(tester).backgroundColor, Colors.transparent);
    final layers = find.byType(AppBackgroundLayersView);
    expect(
      tester
          .widgetList<ColoredBox>(
            find.descendant(of: layers, matching: find.byType(ColoredBox)),
          )
          .map((box) => box.color),
      <Color>[_editorColor],
    );
    // 顶栏是实色栏：与纯色背景同色。
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
      _editorColor,
    );
    expect(tester.getRect(layers), Offset.zero & _view);

    // 键盘弹出：Scaffold 的正文让出键盘，背景按路由尺寸铺满、不动。
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.getRect(layers), Offset.zero & _view);
    await _unmount(tester);
  });
}
