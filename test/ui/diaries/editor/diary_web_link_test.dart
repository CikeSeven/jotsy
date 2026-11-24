import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_link_spans.dart';

import '../../../support/diary_link_editor_harness.dart';

/// 正文里的网址链接（#336、#346）：
/// - 编辑：点按与 Ctrl / ⌘ + K 都经应用的链接对话框，不再弹上游浮层；
/// - 打开：只读点按、编辑态双击与 Alt + Enter 都经应用的 `openExternalLink`
///   （直接外部打开，不经上游 `editorLaunchUrl` / `canLaunchUrl`）。
void main() {
  const url = 'https://mp.weixin.qq.com/s/test-article';

  /// “看 ” + 一段网址链接，链接后半截加粗（同一条链接分成两个片段）。
  List<Map<String, Object?>> linkedDelta([String href = url]) => [
    {'insert': '看 '},
    {
      'insert': '官网',
      'attributes': {'href': href},
    },
    {
      'insert': '首页',
      'attributes': {'href': href, 'bold': true},
    },
  ];

  /// 断言不会落入上游 `editorLaunchUrl`（它会先调 `canLaunchUrlString`，
  /// Android 11+ 上容易被包可见性静默拦住）。
  void forbidUpstreamLaunch() {
    final original = af.editorLaunchUrl;
    af.editorLaunchUrl = (href) async {
      fail('editor should not call upstream editorLaunchUrl($href)');
    };
    addTearDown(() => af.editorLaunchUrl = original);
  }

  /// 拦截 `url_launcher` 方法通道，记录调用；[result] 为 launch 的返回值，
  /// [error] 非空时抛出（模拟 Android 上 ACTIVITY_NOT_FOUND）。
  List<MethodCall> captureUrlLauncher({
    bool result = true,
    PlatformException? error,
  }) {
    final calls = <MethodCall>[];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'launch' && error != null) {
        throw error;
      }
      return result;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    return calls;
  }

  group('web link span', () {
    af.EditorState state({required bool editable}) => af.EditorState(
      document: af.Document.fromJson(
        jsonDecode(linkTestDocument([linkTestParagraph(linkedDelta())]))
            as Map<String, Object?>,
      ),
    )..editable = editable;

    /// 加粗的“首页”片段（偏移 4）的点按识别器；[opened] 记下打开的网址，
    /// [edits] 记下打开对话框的次数。
    TapGestureRecognizer recognizer(
      af.EditorState state,
      List<String> opened,
      List<int> edits,
    ) {
      final node = state.document.nodeAtPath([0])!;
      final span = diaryWebLinkTextSpan(
        node,
        4,
        af.TextInsert('首页', attributes: {'href': url, 'bold': true}),
        const TextSpan(text: '首页'),
        url,
        DiaryLinkSpanOptions(
          state: state,
          onOpen: (_) => fail('web links never open as diary links'),
          onOpenWebLink: opened.add,
          onEditWebLink: () => edits.add(1),
          notebooksEnabled: true,
          plainColor: null,
        ),
      );
      return span.recognizer! as TapGestureRecognizer;
    }

    testWidgets('read-only taps open the address right away', (tester) async {
      forbidUpstreamLaunch();
      final opened = <String>[];
      final edits = <int>[];
      recognizer(state(editable: false), opened, edits).onTap!();
      await tester.pump();
      expect(opened, [url]);
      expect(edits, isEmpty);
    });

    testWidgets('editing: a tap selects the whole link and opens the link '
        'dialog; a double tap opens the address instead', (tester) async {
      forbidUpstreamLaunch();
      final opened = <String>[];
      final edits = <int>[];
      final editor = state(editable: true);
      final tap = recognizer(editor, opened, edits);

      tap.onTap!();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      // 整段链接（“官网首页”），不只是被点的加粗片段。
      expect(
        editor.selection,
        af.Selection.single(path: [0], startOffset: 2, endOffset: 6),
      );
      expect(edits, hasLength(1));
      expect(opened, isEmpty);

      tap.onTap!();
      tap.onTap!();
      await tester.pump(const Duration(milliseconds: 250));
      expect(opened, [url]);
      expect(edits, hasLength(1));
    });
  });

  group('in the editor', () {
    late AppDatabase db;

    setUpAll(() => initializeDateFormatting());
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    /// 手机竖屏大小：上游浮层按“编辑器宽度减 300”摆放，在这里会出界。
    void usePhoneScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    /// 定位段落里“首”字的屏幕中心，用来精准点按加粗的那半段链接。
    Offset centerOfChar(WidgetTester tester, String text, String target) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.textContaining(text, findRichText: true),
      );
      final offset = paragraph.text.toPlainText().indexOf(target);
      final glyph = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: offset, extentOffset: offset + 1),
          )
          .first
          .toRect();
      return paragraph.localToGlobal(glyph.center);
    }

    void expectLinkDialogOnScreen(WidgetTester tester, String address) {
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(find.widgetWithText(TextField, address), findsOneWidget);
      // 对话框的面板（AlertDialog 自身还含四周的外边距）整个在屏幕里。
      final rect = tester.getRect(
        find.descendant(of: dialog, matching: find.byType(Material)).first,
      );
      expect(
        rect.left >= 0 && rect.top >= 0 && rect.right <= 360,
        isTrue,
        reason: 'dialog panel $rect should lie inside the 360×640 screen',
      );
      expect(rect.bottom, lessThanOrEqualTo(640));
      // 上游的链接浮层不再出现。
      expect(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == 'LinkMenu'),
        findsNothing,
      );
    }

    testWidgets('read-only tap opens a web link externally without checking '
        'canLaunch', (tester) async {
      forbidUpstreamLaunch();
      final calls = captureUrlLauncher();
      final controller = DiaryEditorController.fromContent(
        linkTestDocument([linkTestParagraph(linkedDelta())]),
        readOnly: true,
      );
      await pumpLinkEditor(tester, db, controller);

      await tester.tapAt(centerOfChar(tester, '官网首页', '首'));
      await settleLinkEditor(tester);

      expect(calls, hasLength(1));
      expect(calls.single.method, 'launch');
      final args = calls.single.arguments as Map;
      expect(args['url'], url);
      expect(args['useWebView'], isFalse);
      expect(args['useSafariVC'], isFalse);
      await unmountLinkEditor(tester);
    });

    testWidgets('read-only tap falls back to copying when launching throws '
        'ACTIVITY_NOT_FOUND', (tester) async {
      forbidUpstreamLaunch();
      captureUrlLauncher(
        error: PlatformException(
          code: 'ACTIVITY_NOT_FOUND',
          message: 'No Activity found',
        ),
      );
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      final controller = DiaryEditorController.fromContent(
        linkTestDocument([linkTestParagraph(linkedDelta())]),
        readOnly: true,
      );
      await pumpLinkEditor(tester, db, controller);

      await tester.tapAt(centerOfChar(tester, '官网首页', '首'));
      await settleLinkEditor(tester);

      expect(copied, url);
      expect(find.text('无法直接打开链接，已复制到剪贴板。'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await unmountLinkEditor(tester);
    });

    testWidgets('tapping a web link opens the app link dialog on screen, '
        'and confirming relinks the whole link', (tester) async {
      usePhoneScreen(tester);
      forbidUpstreamLaunch();
      final calls = captureUrlLauncher();
      final controller = DiaryEditorController.fromContent(
        linkTestDocument([linkTestParagraph(linkedDelta())]),
      );
      await pumpLinkEditor(tester, db, controller);

      // 点在“首页”的第一个字上。
      await tester.tapAt(centerOfChar(tester, '官网首页', '首'));
      await settleLinkEditor(tester);

      expectLinkDialogOnScreen(tester, url);
      expect(calls, isEmpty);

      await tester.enterText(find.byType(TextField), 'example.org');
      await tester.tap(find.text('确认'));
      await settleLinkEditor(tester);
      // 两个片段都换成新地址，加粗不变。
      expect(linkTestDelta(controller), linkedDelta('https://example.org'));
      await unmountLinkEditor(tester);
    });

    testWidgets('Ctrl + K on a phone opens the app link dialog too', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final node = FocusNode();
      addTearDown(node.dispose);
      final controller = DiaryEditorController.fromContent(
        linkTestDocument([linkTestParagraph(linkedDelta())]),
      );
      controller.select(af.Selection.single(path: [0], startOffset: 3));
      await pumpLinkEditor(tester, db, controller, focusNode: node);
      await focusLinkEditor(tester, node);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settleLinkEditor(tester);

      expectLinkDialogOnScreen(tester, url);
      // 取消不改动正文。
      await tester.tap(find.text('取消'));
      await settleLinkEditor(tester);
      expect(linkTestDelta(controller), linkedDelta());
      await unmountLinkEditor(tester);
    });

    testWidgets('Alt + Enter opens web links externally and routes diary '
        'links through openDiaryLinkTarget', (tester) async {
      forbidUpstreamLaunch();
      final calls = captureUrlLauncher();
      final node = FocusNode();
      addTearDown(node.dispose);
      final controller = DiaryEditorController.fromContent(
        linkTestDocument([
          linkTestParagraph([
            ...linkedDelta(),
            {'insert': ' '},
            {
              'insert': '那一天',
              'attributes': {'href': 'jotsy://diary/gone'},
            },
          ]),
        ]),
      );
      controller.select(af.Selection.single(path: [0], startOffset: 3));
      await pumpLinkEditor(tester, db, controller, focusNode: node);
      await focusLinkEditor(tester, node);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await settleLinkEditor(tester);

      expect(calls, hasLength(1));
      expect(calls.single.method, 'launch');
      expect((calls.single.arguments as Map)['url'], url);

      // 光标移到日记链接上再按 Alt + Enter：走应用内日记跳转，不调 url_launcher。
      controller.select(af.Selection.single(path: [0], startOffset: 8));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await settleLinkEditor(tester);

      expect(calls, hasLength(1));
      expect(find.text('这篇日记不存在或已删除'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await unmountLinkEditor(tester);
    });
  });
}
