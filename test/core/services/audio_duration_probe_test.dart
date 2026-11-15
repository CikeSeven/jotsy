import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/audio_duration_probe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a player that cannot open the file answers null, never throws',
    () async {
      // 测试环境没有 audioplayers 的原生实现：与本机播不了同一种结果。
      expect(
        await probeAudioDuration(
          '/missing/voice.m4a',
          timeout: const Duration(seconds: 2),
        ),
        isNull,
      );
    },
  );
}
