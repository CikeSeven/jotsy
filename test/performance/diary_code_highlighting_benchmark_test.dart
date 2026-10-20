import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_highlighter.dart';

import '../support/diary_code_samples.dart';

// 本机前后对照用微基准，不以墙钟时间作为 CI 门禁，也不代表手机功耗。
// flutter test test/performance/diary_code_highlighting_benchmark_test.dart \
//   --dart-define=PERFORMANCE_BENCHMARK=true --reporter expanded
void main() {
  const enabled = bool.fromEnvironment('PERFORMANCE_BENCHMARK');
  test('reports detection, editing and cache costs', () {
    final highlighter = DiaryCodeHighlighter.instance;
    final first = Stopwatch()..start();
    highlighter.detect(diaryCodeSamples['dart']!);
    stdout.writeln('BENCH first detection: ${first.elapsedMicroseconds} us');

    final detection = <int>[];
    final cached = <int>[];
    for (var iteration = 0; iteration < 20; iteration++) {
      for (final text in diaryCodeSamples.values) {
        final sample = '$text\n${' ' * iteration}';
        final watch = Stopwatch()..start();
        highlighter.detect(sample);
        detection.add(watch.elapsedMicroseconds);
        watch.reset();
        highlighter.detect(sample);
        cached.add(watch.elapsedMicroseconds);
      }
    }
    _report('uncached short detection', detection);
    _report('cached short detection', cached);

    final block = 'const item = {name: "Hello", value: 42};\n' * 450;
    final editing = <int>[];
    for (var iteration = 0; iteration < 60; iteration++) {
      final watch = Stopwatch()..start();
      final result = highlighter.tokens('$block// $iteration', 'javascript');
      editing.add(watch.elapsedMicroseconds);
      expect(result.tokens, isNotEmpty);
    }
    _report('highlight ${block.length} characters while editing', editing);
  }, skip: !enabled);
}

void _report(String label, List<int> samples) {
  samples.sort();
  stdout.writeln(
    'BENCH $label: p50=${samples[samples.length ~/ 2]} us, '
    'p95=${samples[(samples.length * .95).floor()]} us',
  );
}
