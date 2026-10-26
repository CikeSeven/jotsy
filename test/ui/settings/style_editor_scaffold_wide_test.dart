import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/widgets/style_editor/style_editor_scaffold.dart';

/// 样式编辑页外壳的宽屏并排布局：选项栏最宽 480，其余宽度给预览；
/// 720–960 之间与原来一样各占一半。
void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StyleEditorScaffold(
          title: '样式',
          listenable: ChangeNotifier(),
          isDefault: () => true,
          onReset: () {},
          tabs: const <String>['一', '二'],
          tabViews: () => const <Widget>[
            SizedBox.expand(key: ValueKey<String>('tab_1')),
            SizedBox.expand(key: ValueKey<String>('tab_2')),
          ],
          previewBuilder:
              ({required bool showToolbar, required double bottomPadding}) =>
                  const SizedBox.expand(key: ValueKey<String>('preview')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a wide window caps the controls pane at 480', (tester) async {
    await pumpAt(tester, const Size(1184, 800));
    final preview = tester.getRect(find.byKey(const ValueKey('preview')));
    final controls = tester.getRect(find.byKey(const ValueKey('tab_1')));
    expect(controls.width, 480);
    expect(controls.right, 1184);
    // 预览占其余宽度（扣掉 1dp 分隔线）。
    expect(preview.left, 0);
    expect(preview.width, 1184 - 480 - 1);
  });

  testWidgets('a narrower side-by-side window still splits in half', (
    tester,
  ) async {
    await pumpAt(tester, const Size(800, 800));
    final preview = tester.getRect(find.byKey(const ValueKey('preview')));
    final controls = tester.getRect(find.byKey(const ValueKey('tab_1')));
    expect(controls.width, 399.5);
    expect(preview.width, 399.5);
  });
}
