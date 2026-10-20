import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_code_block_look.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_quill_styles.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_code_block/diary_code_block_chrome.dart';
import 'package:node_diary/ui/diaries/widgets/diary_code_block/diary_code_block_header_geometry.dart';
import 'package:node_diary/ui/diaries/widgets/diary_code_block/render_diary_code_block_chrome.dart';

import '../../../../support/expressive_test_theme.dart';

/// 一行正文：文字与行属性（null 为普通段落）。
typedef _Line = (String text, Object? codeBlock);

quill.Document _document(List<_Line> lines) {
  final ops = <Map<String, Object?>>[];
  for (final (text, codeBlock) in lines) {
    if (text.isNotEmpty) {
      ops.add(<String, Object?>{'insert': text});
    }
    ops.add(<String, Object?>{
      'insert': '\n',
      if (codeBlock != null)
        'attributes': <String, Object?>{'code-block': codeBlock},
    });
  }
  return quill.Document.fromJson(ops);
}

/// 正文一段、Python 代码块、正文一段、纯文本代码块。
List<_Line> _twoBlocks() => <_Line>[
  ('Intro paragraph', null),
  ('def greet(name):', 'python'),
  ('    return name', 'python'),
  ('Between', null),
  ('plain one', 'plain'),
  ('plain two', 'plain'),
  ('Outro', null),
];

quill.QuillController _controller(
  quill.Document document, {
  bool readOnly = true,
}) => quill.QuillController(
  document: document,
  selection: const TextSelection.collapsed(offset: 0),
  readOnly: readOnly,
);

class _Harness {
  _Harness(this.tester);

  final WidgetTester tester;
  late DiaryQuillLook look;

  RenderDiaryCodeBlockChrome get chrome =>
      tester.allRenderObjects.whereType<RenderDiaryCodeBlockChrome>().single;

  quill.RenderEditor get editor =>
      tester.allRenderObjects.whereType<quill.RenderEditor>().single;

  List<DiaryCodeBlockHeaderGeometry> get headers => chrome.headers;

  /// 标题栏的全局坐标矩形。
  Rect globalHeader(int index) {
    final rect = headers[index].rect;
    return chrome.localToGlobal(rect.topLeft) & rect.size;
  }

  Offset globalCopyCenter(int index) =>
      chrome.localToGlobal(headers[index].copyRect.center);
}

Future<_Harness> _pump(
  WidgetTester tester,
  quill.QuillController controller, {
  DiaryCodeBlockStyle style = DiaryCodeBlockStyle.defaults,
  bool scrollable = false,
  ScrollController? editorScroll,
  ScrollController? pageScroll,
  double height = 1200,
}) async {
  tester.view.physicalSize = Size(400, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = _Harness(tester);
  final focus = FocusNode();
  addTearDown(focus.dispose);
  final editor = DiaryQuillStylesBuilder(
    appearance: const DiaryTextAppearance(typography: DiaryTypography()),
    controller: controller,
    codeBlockStyle: style,
    scrollController: editorScroll,
    builder: (BuildContext context, DiaryQuillLook look) {
      harness.look = look;
      return quill.QuillEditor.basic(
        controller: controller,
        focusNode: focus,
        scrollController: editorScroll,
        config: look.configure(
          quill.QuillEditorConfig(
            autoFocus: false,
            scrollable: scrollable,
            padding: EdgeInsets.zero,
          ),
        ),
      );
    },
  );
  final Widget body;
  if (scrollable) {
    body = SizedBox(height: 200, child: editor);
  } else if (pageScroll != null) {
    body = SingleChildScrollView(
      controller: pageScroll,
      child: Column(children: <Widget>[editor, const SizedBox(height: 2000)]),
    );
  } else {
    body = editor;
  }
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ...AppLocalizations.localizationsDelegates,
          quill.FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: body),
      ),
    ),
  );
  return harness;
}

/// 记录剪贴板写入与触觉反馈。
({List<String> clipboard, List<String> haptics}) _mockPlatform(
  WidgetTester tester,
) {
  final clipboard = <String>[];
  final haptics = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard.add((call.arguments as Map)['text'] as String);
      } else if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return (clipboard: clipboard, haptics: haptics);
}

/// RenderEditor 画出的代码块底色 RRect（全局坐标）。底色是块装饰的真实绘制
/// 结果，与标题栏的几何推算互相独立。
List<Rect> _paintedBlockBodies(_Harness harness) {
  final bodies = <Rect>[];
  final background = harness.look.code.palette.background;
  expect(
    harness.editor,
    paints..everything((Symbol method, List<dynamic> arguments) {
      if (method == #drawRRect &&
          (arguments[1] as Paint).color.toARGB32() == background.toARGB32()) {
        bodies.add((arguments[0] as RRect).outerRect);
      }
      return true;
    }),
  );
  final origin = harness.editor.localToGlobal(Offset.zero);
  return <Rect>[for (final body in bodies) body.shift(origin)];
}

void main() {
  testWidgets('each code block gets a header 32dp tall right above its body', (
    tester,
  ) async {
    final harness = await _pump(tester, _controller(_document(_twoBlocks())));

    expect(harness.headers, hasLength(2));
    final bodies = _paintedBlockBodies(harness);
    expect(bodies, hasLength(2));
    for (var i = 0; i < 2; i++) {
      final header = harness.globalHeader(i);
      expect(header.height, DiaryCodeBlockLook.headerHeight);
      expect(header.bottom, moreOrLessEquals(bodies[i].top));
      expect(header.left, moreOrLessEquals(bodies[i].left));
      expect(header.right, moreOrLessEquals(bodies[i].right));
    }
    expect(harness.headers.map((header) => header.label), <String>[
      'Python',
      '纯文本',
    ]);
  });

  testWidgets('an unspecified block shows the detected language or 代码', (
    tester,
  ) async {
    final harness = await _pump(
      tester,
      _controller(
        _document(<_Line>[
          ('{', true),
          ('  "name": "jotsy",', true),
          ('  "count": 3', true),
          ('}', true),
        ]),
      ),
    );
    expect(harness.headers.single.label, 'JSON');

    await _pump(
      tester,
      _controller(
        _document(<_Line>[
          ('{', true),
          ('  "name": "jotsy"', true),
          ('}', true),
        ]),
      ),
      style: DiaryCodeBlockStyle.defaults.copyWith(autoDetect: false),
    );
    expect(harness.headers.single.label, '代码');
  });

  testWidgets('tapping copy copies that block without moving the caret', (
    tester,
  ) async {
    final platform = _mockPlatform(tester);
    final controller = _controller(_document(_twoBlocks()), readOnly: false);
    final harness = await _pump(tester, controller);
    final selection = controller.selection;

    // 标题栏别处：什么都不发生，光标也不动。
    await tester.tapAt(
      harness.globalHeader(1).centerLeft + const Offset(40, 0),
    );
    await tester.pump();
    expect(controller.selection, selection);
    expect(platform.clipboard, isEmpty);

    await tester.tapAt(harness.globalCopyCenter(1));
    await tester.pump();

    expect(platform.clipboard, <String>['plain one\nplain two']);
    expect(platform.haptics, <String>['HapticFeedbackType.lightImpact']);
    expect(controller.selection, selection);
    expect(find.text('已复制代码'), findsOneWidget);
    expect(harness.chrome.copiedBlock, same(harness.headers[1].block));

    await tester.pump(
      DiaryCodeBlockChrome.copiedDuration - const Duration(milliseconds: 1),
    );
    expect(harness.chrome.copiedBlock, isNotNull);
    await tester.pump(const Duration(milliseconds: 1));
    expect(harness.chrome.copiedBlock, isNull);

    // 让 SnackBar 走完自己的计时。
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('with the header off nothing is drawn or intercepted', (
    tester,
  ) async {
    final harness = await _pump(
      tester,
      _controller(_document(_twoBlocks())),
      style: DiaryCodeBlockStyle.defaults.copyWith(header: false),
    );

    expect(harness.headers, isEmpty);
    expect(
      harness.look.code.blockStyle.verticalSpacing.top,
      DiaryCodeBlockLook.blockGap,
    );
    // 关闭时这一层不拦点按：块上方的外边距照常交给 Quill 的手势层（开启时
    // 那里是标题栏，命中只到本层为止）。
    final body = _paintedBlockBodies(harness).first;
    final result = BoxHitTestResult();
    harness.chrome.hitTest(
      result,
      position: harness.chrome.globalToLocal(
        body.topCenter - const Offset(0, 4),
      ),
    );
    final targets = result.path.map((entry) => entry.target).toList();
    expect(targets.first, isNot(same(harness.chrome)));
    expect(targets, contains(isA<RenderPointerListener>()));
  });

  testWidgets('headers follow a paragraph inserted above in the same frame', (
    tester,
  ) async {
    final controller = _controller(_document(_twoBlocks()), readOnly: false);
    final harness = await _pump(tester, controller);
    final before = harness.globalHeader(0);
    final bodyBefore = _paintedBlockBodies(harness).first;

    controller.replaceText(
      0,
      0,
      'A new line\n',
      const TextSelection.collapsed(offset: 11),
    );
    await tester.pump();

    final after = harness.globalHeader(0);
    final bodyAfter = _paintedBlockBodies(harness).first;
    final shift = bodyAfter.top - bodyBefore.top;
    expect(shift, greaterThan(0));
    expect(after.top - before.top, moreOrLessEquals(shift));
    expect(after.bottom, moreOrLessEquals(bodyAfter.top));
  });

  testWidgets('a scrollable editor moves its headers as it scrolls', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final harness = await _pump(
      tester,
      _controller(_document(<_Line>[..._twoBlocks(), ..._twoBlocks()])),
      scrollable: true,
      editorScroll: scroll,
    );
    final before = harness.headers[1].rect;

    scroll.jumpTo(30);
    await tester.pump();

    expect(harness.headers[1].rect.top, moreOrLessEquals(before.top - 30));
  });

  testWidgets('dragging from a header scrolls the editor it belongs to', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final harness = await _pump(
      tester,
      _controller(_document(<_Line>[..._twoBlocks(), ..._twoBlocks()])),
      scrollable: true,
      editorScroll: scroll,
    );

    await tester.dragFrom(harness.globalHeader(0).center, const Offset(0, -80));
    await tester.pumpAndSettle();

    expect(scroll.offset, greaterThan(0));
  });

  testWidgets('dragging from a header still scrolls the page', (tester) async {
    final page = ScrollController();
    addTearDown(page.dispose);
    final harness = await _pump(
      tester,
      _controller(_document(_twoBlocks())),
      pageScroll: page,
      height: 600,
    );

    await tester.dragFrom(harness.globalHeader(0).center, const Offset(0, -80));
    await tester.pumpAndSettle();

    expect(page.offset, greaterThan(0));
  });

  testWidgets('each copy button is a labelled semantics button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final platform = _mockPlatform(tester);
    await _pump(tester, _controller(_document(_twoBlocks())));

    final python = find.semantics.byLabel('复制 Python 代码');
    expect(python, findsOne);
    expect(find.semantics.byLabel('复制 纯文本 代码'), findsOne);
    expect(python.evaluate().single.flagsCollection.isButton, isTrue);

    tester.semantics.tap(python);
    await tester.pump();
    expect(platform.clipboard, <String>['def greet(name):\n    return name']);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    semantics.dispose();
  });
}
