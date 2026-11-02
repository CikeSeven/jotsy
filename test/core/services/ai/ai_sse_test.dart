import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/ai/ai_client.dart';
import 'package:node_diary/core/services/ai/ai_sse.dart';

Stream<List<int>> _chunks(List<List<int>> chunks) =>
    Stream<List<int>>.fromIterable(chunks);

void main() {
  group('decodeAiSse', () {
    test('splits events on blank lines and joins multi-line data', () async {
      final events = await decodeAiSse(
        _chunks([
          utf8.encode('event: a\ndata: one\ndata: two\n\n'),
          utf8.encode(': heartbeat\n\ndata: three\n\n'),
        ]),
      ).toList();
      expect(events, hasLength(2));
      expect(events[0].event, 'a');
      expect(events[0].data, 'one\ntwo');
      expect(events[1].event, isNull);
      expect(events[1].data, 'three');
    });

    test('handles CRLF and UTF-8 split across chunks', () async {
      final bytes = utf8.encode('data: 你好\r\n\r\n');
      final events = await decodeAiSse(
        _chunks([bytes.sublist(0, 8), bytes.sublist(8)]),
      ).toList();
      expect(events.single.data, '你好');
    });

    test('emits a trailing event without a final blank line', () async {
      final events = await decodeAiSse(
        _chunks([utf8.encode('data: [DONE]')]),
      ).toList();
      expect(events.single.isDone, isTrue);
    });

    test('keeps the space only once after the colon', () async {
      final events = await decodeAiSse(
        _chunks([utf8.encode('data:  two spaces\n\n')]),
      ).toList();
      expect(events.single.data, ' two spaces');
    });
  });

  group('AiThinkTagSplitter', () {
    test('moves a leading think block to reasoning across chunks', () {
      final splitter = AiThinkTagSplitter();
      final parts = [
        splitter.add('  <thi'),
        splitter.add('nk>想一'),
        splitter.add('想</th'),
        splitter.add('ink>\n答案'),
      ];
      final rest = splitter.close();
      expect(parts.map((p) => p.reasoning).join() + rest.reasoning, '想一想');
      expect(parts.map((p) => p.text).join() + rest.text, '答案');
    });

    test('leaves text without a leading think tag untouched', () {
      final splitter = AiThinkTagSplitter();
      final first = splitter.add('Hello <think>not a tag');
      expect(first.text, 'Hello <think>not a tag');
      expect(first.reasoning, isEmpty);
    });

    test('returns an unterminated think block as reasoning on close', () {
      final splitter = AiThinkTagSplitter();
      final first = splitter.add('<think>still thinking');
      final rest = splitter.close();
      expect(first.text + rest.text, isEmpty);
      expect(first.reasoning + rest.reasoning, 'still thinking');
    });
  });
}
