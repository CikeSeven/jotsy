import '../../../support/diary_content_test_helpers.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/controllers/diary_block_language_tracker.dart';

const _python = '''
import os

def greet(name, times=3):
    """Say hello."""
    for _ in range(times):
        print(f"Hello, {name}!")
    return None

class Greeter(object):
    def __init__(self):
        self.count = 0
''';

const _json = '''
{
  "name": "jotsy",
  "version": 3,
  "tags": ["diary", "notes"],
  "private": true,
  "nested": {"value": null, "ratio": 0.5}
}
''';

/// 一个只含一个自动识别代码块的文档，返回该块与它的识别状态。
(quill.Node, DiaryBlockLanguageTracker) _setUp() {
  final document = documentFromLegacyDelta(<Map<String, Object?>>[
    <String, Object?>{'insert': 'x'},
    <String, Object?>{
      'insert': '\n',
      'attributes': <String, Object?>{'code-block': true},
    },
  ]);
  final controller = DiaryEditorController(
    document: document,
    selection: quill.Selection.single(path: [0], startOffset: 0),
  );
  final block = document.root.children.first;
  return (block, DiaryBlockLanguageTracker.of(controller));
}

void main() {
  test('one tracker per controller', () {
    final controller = DiaryEditorController();
    expect(
      DiaryBlockLanguageTracker.of(controller),
      same(DiaryBlockLanguageTracker.of(controller)),
    );
    expect(
      DiaryBlockLanguageTracker.of(controller),
      isNot(same(DiaryBlockLanguageTracker.of(DiaryEditorController()))),
    );
  });

  testWidgets('detects synchronously the first time a block is seen', (
    tester,
  ) async {
    final (block, tracker) = _setUp();
    addTearDown(tracker.dispose);

    expect(tracker.lastDetected(block), isNull);
    expect(tracker.languageFor(block, _python), 'python');
    expect(tracker.lastDetected(block), 'python');
  });

  testWidgets('keeps the old language while typing, re-detects once after '
      'the debounce', (tester) async {
    final (block, tracker) = _setUp();
    addTearDown(tracker.dispose);
    var notifications = 0;
    tracker.addListener(() => notifications++);

    expect(tracker.languageFor(block, _python), 'python');
    // 文本变了：沿用旧结果，不闪。
    expect(tracker.languageFor(block, _json), 'python');
    await tester.pump(const Duration(milliseconds: 400));
    // 又敲了一个字：重新计时。
    expect(tracker.languageFor(block, '$_json\n'), 'python');
    await tester.pump(const Duration(milliseconds: 400));
    expect(notifications, 0);
    expect(tracker.lastDetected(block), 'python');

    await tester.pump(const Duration(milliseconds: 200));
    expect(notifications, 1);
    expect(tracker.lastDetected(block), 'json');
    expect(tracker.languageFor(block, '$_json\n'), 'json');

    await tester.pump(const Duration(seconds: 1));
    expect(notifications, 1);
  });

  testWidgets('does not notify when the re-detected language is the same', (
    tester,
  ) async {
    final (block, tracker) = _setUp();
    addTearDown(tracker.dispose);
    var notifications = 0;
    tracker.addListener(() => notifications++);

    tracker.languageFor(block, _python);
    expect(tracker.languageFor(block, '$_python\nprint(1)\n'), 'python');
    await tester.pump(DiaryBlockLanguageTracker.debounce);
    expect(notifications, 0);
    expect(tracker.lastDetected(block), 'python');
  });

  testWidgets('rebuilding with the same pending text does not postpone', (
    tester,
  ) async {
    final (block, tracker) = _setUp();
    addTearDown(tracker.dispose);
    var notifications = 0;
    tracker.addListener(() => notifications++);

    tracker.languageFor(block, _python);
    tracker.languageFor(block, _json);
    await tester.pump(const Duration(milliseconds: 500));
    tracker.languageFor(block, _json);
    await tester.pump(const Duration(milliseconds: 100));
    expect(notifications, 1);
  });

  testWidgets('dispose cancels the pending re-detection', (tester) async {
    final (block, tracker) = _setUp();
    var notifications = 0;
    tracker.addListener(() => notifications++);

    tracker.languageFor(block, _python);
    tracker.languageFor(block, _json);
    tracker.dispose();
    // 计时器若未取消，测试结束时会报“仍有挂起的 Timer”。
    await tester.pump(const Duration(seconds: 1));
    expect(notifications, 0);
    expect(tracker.lastDetected(block), 'python');
  });

  testWidgets('manual choice drops pending work and auto can resume later', (
    tester,
  ) async {
    final (block, tracker) = _setUp();
    addTearDown(tracker.dispose);
    var notifications = 0;
    tracker.addListener(() => notifications++);
    tracker.languageFor(block, _python);
    tracker.languageFor(block, _json);
    tracker.cancelPendingFor(block);
    await tester.pump(DiaryBlockLanguageTracker.debounce);
    expect(notifications, 0);
    expect(tracker.lastDetected(block), 'python');
    tracker.languageFor(block, _json);
    await tester.pump(DiaryBlockLanguageTracker.debounce);
    expect(notifications, 1);
    expect(tracker.lastDetected(block), 'json');
  });

  testWidgets('the last listener leaving drops the pending re-detection', (
    tester,
  ) async {
    final (block, tracker) = _setUp();
    addTearDown(tracker.dispose);
    void listener() {}
    tracker.addListener(listener);

    tracker.languageFor(block, _python);
    tracker.languageFor(block, _json);
    tracker.removeListener(listener);
    await tester.pump(const Duration(seconds: 1));
    expect(tracker.lastDetected(block), 'python');

    // 再次显示时按新文本重新排队。
    tracker.addListener(listener);
    expect(tracker.languageFor(block, _json), 'python');
    await tester.pump(DiaryBlockLanguageTracker.debounce);
    expect(tracker.lastDetected(block), 'json');
  });
}
