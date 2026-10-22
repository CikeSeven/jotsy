import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_clipboard.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? clipboardText;
  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String?;
          }
          if (call.method == 'Clipboard.getData') {
            return {'text': clipboardText};
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('pasteboard'),
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('pasteboard'), null);
  });

  test(
    'copy and paste preserve the native subtree and inline styles',
    () async {
      final source = DiaryEditorController.fromContent(
        jsonEncode({
          'document': {
            'type': 'page',
            'children': [
              {
                'type': 'quote',
                'data': {
                  'delta': [
                    {
                      'insert': 'quote',
                      'attributes': {'bold': true, 'font_color': '#FF123456'},
                    },
                  ],
                },
                'children': [
                  {
                    'type': 'todo_list',
                    'data': {
                      'checked': true,
                      'delta': [
                        {'insert': 'child'},
                      ],
                    },
                  },
                ],
              },
            ],
          },
        }),
      );
      final target = DiaryEditorController();
      source.select(
        af.Selection.single(path: [0], startOffset: 0, endOffset: 5),
      );
      final original = source.contentJson;
      await DiaryEditorClipboard.copy(source);
      await DiaryEditorClipboard.paste(target);
      expect(target.contentJson, original);
      expect(source.contentJson, original);
      target.undo();
      expect(target.plainText, isEmpty);
      source.dispose();
      target.dispose();
    },
  );

  test('new system clipboard text replaces the previous in-app copy', () async {
    final source = DiaryEditorController.fromContent('old');
    source.select(af.Selection.single(path: [0], startOffset: 0, endOffset: 3));
    await DiaryEditorClipboard.copy(source);
    await Clipboard.setData(const ClipboardData(text: 'new\nplain text'));
    final target = DiaryEditorController();
    await DiaryEditorClipboard.paste(target);
    expect(target.plainText, 'new\nplain text');
    expect(target.document.root.children, hasLength(2));
    source.dispose();
    target.dispose();
  });
}
