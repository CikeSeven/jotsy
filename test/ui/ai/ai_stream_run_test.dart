import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/ai/ai_failure.dart';
import 'package:node_diary/core/services/ai/ai_models.dart';
import 'package:node_diary/ui/ai/controllers/ai_stream_run.dart';

void main() {
  testWidgets(
    'a burst publishes once per window and completion flushes the last chunk',
    (tester) async {
      final run = AiStreamRun();
      addTearDown(run.dispose);
      final stream = StreamController<AiChunk>();
      var notifications = 0;
      run.addListener(() => notifications++);
      final finished = run.start((_) => stream.stream);
      for (var i = 0; i < 100; i++) {
        stream.add(const AiChunk(text: '字', reasoning: '想'));
      }
      await tester.pump();
      expect(run.text, '字' * 100);
      expect(run.reasoning, '想' * 100);
      expect(notifications, 1); // running 立即通知，增量还在合并窗口内。
      await tester.pump(const Duration(milliseconds: 16));
      expect(notifications, 2);
      stream.add(const AiChunk(text: '末尾'));
      await stream.close();
      await finished;
      expect(run.status, AiRunStatus.done);
      expect(run.text, '${'字' * 100}末尾');
      expect(notifications, 3);
      await tester.pump(const Duration(milliseconds: 16));
      expect(notifications, 3);
    },
  );

  testWidgets(
    'reset cancels pending updates and cancellation keeps the received tail',
    (tester) async {
      final run = AiStreamRun();
      addTearDown(run.dispose);
      final first = StreamController<AiChunk>();
      final oldRun = run.start((_) => first.stream);
      first.add(const AiChunk(text: 'old'));
      await tester.pump();
      run.reset();
      await first.close();
      await oldRun;
      await tester.pump(const Duration(milliseconds: 16));
      expect(run.status, AiRunStatus.idle);
      expect(run.text, isEmpty);

      final second = StreamController<AiChunk>();
      final stopped = run.start((_) => second.stream);
      second.add(const AiChunk(text: '保留'));
      second.addError(const AiException(AiFailureKind.cancelled));
      await second.close();
      await stopped;
      expect(run.status, AiRunStatus.stopped);
      expect(run.text, '保留');
      expect(run.hasResult, isTrue);
    },
  );
}
