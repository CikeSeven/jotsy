import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_saved_colors.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';

import 'expressive_test_theme.dart';

// 颜色面板测试的公共装配：正文编辑器 + 悬浮工具栏（颜色工具排在最前），
// 记录路由推入与面板高度报告；我的颜色存在 [ColorPanelHarness.saved] 里，
// 面板的改写立即生效（与 provider 一样作用在最新记录上）。

const String colorPanelTextTool = '文字颜色';
const String colorPanelBackgroundTool = '背景颜色';
const String colorPanelMoreTooltip = '更多工具';
const String colorPanelHideMoreTooltip = '收起更多工具';

/// 颜色工具排在最前，360dp 下常驻在工具栏一排上。
const List<DiaryToolbarItem> colorFirstToolbarOrder = <DiaryToolbarItem>[
  DiaryToolbarItem.textColor,
  DiaryToolbarItem.backgroundColor,
  ...kDefaultDiaryToolbarOrder,
];

class ColorPanelRouteCounter extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

class ColorPanelHarness {
  ColorPanelHarness(
    this.controller,
    this.editorFocus,
    this.routes,
    DiarySavedColors saved,
  ) : saved = ValueNotifier<DiarySavedColors>(saved);

  final quill.QuillController controller;
  final FocusNode editorFocus;
  final ColorPanelRouteCounter routes;
  final List<double> extents = <double>[];
  final ValueNotifier<DiarySavedColors> saved;

  /// 面板经 `onEditSavedColors` 改写了几次（含没有变化的）。
  int edits = 0;

  void edit(DiarySavedColorsEdit change) {
    edits++;
    saved.value = change(saved.value);
  }
}

/// 正文为 [text] 并全选的控制器。
quill.QuillController colorPanelController([String text = 'hello']) {
  final controller = quill.QuillController.basic();
  addTearDown(controller.dispose);
  controller.replaceText(0, 0, text, null);
  controller.updateSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
    quill.ChangeSource.local,
  );
  return controller;
}

/// 用应用的真实字体排版：表头放不放得下标题取决于字宽，测试默认的 Ahem 每个
/// 字都是满格方块，比真实文字宽得多。在 `setUpAll` 里调用。
Future<void> loadColorPanelFonts() async {
  final loader = FontLoader('HarmonyOSSansSC');
  for (final weight in <String>['Regular', 'Medium', 'Bold']) {
    loader.addFont(
      rootBundle.load(
        'assets/fonts/harmonyos_sans_sc/HarmonyOS_Sans_SC_$weight.ttf',
      ),
    );
  }
  await loader.load();
}

Future<ColorPanelHarness> pumpColorPanel(
  WidgetTester tester, {
  quill.QuillController? controller,
  double screenWidth = 360,
  List<DiaryToolbarItem> order = colorFirstToolbarOrder,
  bool recordingOpen = false,
  Locale locale = const Locale('zh'),
  DiarySavedColors savedColors = DiarySavedColors.empty,
  ColorPanelHarness? reuse,
}) async {
  tester.view.physicalSize = Size(screenWidth, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness =
      reuse ??
      ColorPanelHarness(
        controller ?? colorPanelController(),
        FocusNode(),
        ColorPanelRouteCounter(),
        savedColors,
      );
  if (reuse == null) {
    addTearDown(harness.editorFocus.dispose);
    addTearDown(harness.saved.dispose);
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      locale: locale,
      navigatorObservers: <NavigatorObserver>[harness.routes],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        ...AppLocalizations.localizationsDelegates,
        quill.FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(
          children: <Widget>[
            Expanded(
              child: quill.QuillEditor.basic(
                controller: harness.controller,
                focusNode: harness.editorFocus,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kDiaryFloatingToolbarInset,
              ),
              child: ValueListenableBuilder<DiarySavedColors>(
                valueListenable: harness.saved,
                builder:
                    (BuildContext context, DiarySavedColors saved, Widget? _) =>
                        DiaryFloatingToolbar(
                          controller: harness.controller,
                          order: order,
                          recordingOpen: recordingOpen,
                          onPanelExtentChanged: harness.extents.add,
                          savedColors: saved,
                          onEditSavedColors: harness.edit,
                        ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

Future<void> openTextColorPanel(WidgetTester tester) async {
  await tester.tap(find.byTooltip(colorPanelTextTool));
  await tester.pumpAndSettle();
}

/// 第 [i] 个字符上的行内属性。
Map<String, dynamic>? colorPanelAttributesAt(
  quill.QuillController controller,
  int i,
) {
  var offset = 0;
  for (final op in controller.document.toDelta().toList()) {
    final length = op.length ?? 0;
    if (i < offset + length) return op.attributes;
    offset += length;
  }
  return null;
}
