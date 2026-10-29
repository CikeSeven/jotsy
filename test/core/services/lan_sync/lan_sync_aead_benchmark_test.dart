import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';

// 局域网同步信道的 AEAD 吞吐微基准（本机前后对照用，不作为 CI 门禁）：
// 用与信道相同的 64 KiB 明文帧、同步 API 比较 ChaCha20-Poly1305 与 AES-256-GCM。
// flutter test test/core/services/lan_sync/lan_sync_aead_benchmark_test.dart \
//   --dart-define=PERFORMANCE_BENCHMARK=true --reporter expanded
void main() {
  const enabled = bool.fromEnvironment('PERFORMANCE_BENCHMARK');

  test('reports ChaCha20-Poly1305 and AES-256-GCM throughput', () {
    final random = Random(7);
    final frame = Uint8List.fromList(
      List<int>.generate(64 * 1024, (_) => random.nextInt(256)),
    );
    final key = SecretKeyData(List<int>.generate(32, (i) => i));
    final nonce = List<int>.filled(12, 1);
    final aad = [0, 1, 0, 16];
    const frames = 160; // 10 MiB

    const chacha = DartChacha20.poly1305Aead();
    _report('ChaCha20-Poly1305 seal', frames, frame.length, () {
      chacha.encryptSync(frame, secretKey: key, nonce: nonce, aad: aad);
    });
    final chachaBox = chacha.encryptSync(
      frame,
      secretKey: key,
      nonce: nonce,
      aad: aad,
    );
    _report('ChaCha20-Poly1305 open', frames, frame.length, () {
      chacha.decryptSync(chachaBox, secretKey: key, aad: aad);
    });

    final aes = DartAesGcm.with256bits();
    _report('AES-256-GCM seal', frames, frame.length, () {
      aes.encryptSync(frame, secretKeyData: key, nonce: nonce, aad: aad);
    });
    final aesBox = aes.encryptSync(
      frame,
      secretKeyData: key,
      nonce: nonce,
      aad: aad,
    );
    _report('AES-256-GCM open', frames, frame.length, () {
      aes.decryptSync(aesBox, secretKeyData: key, aad: aad);
    });
  }, skip: !enabled);
}

void _report(String label, int frames, int frameLength, void Function() run) {
  // 先预热，让 JIT 编译热点路径，再计时。
  for (var i = 0; i < 8; i++) {
    run();
  }
  final watch = Stopwatch()..start();
  for (var i = 0; i < frames; i++) {
    run();
  }
  watch.stop();
  final megabytes = frames * frameLength / (1024 * 1024);
  final seconds = watch.elapsedMicroseconds / 1e6;
  stdout.writeln(
    'BENCH $label: ${(megabytes / seconds).toStringAsFixed(1)} MiB/s '
    '(${megabytes.toStringAsFixed(0)} MiB in '
    '${watch.elapsedMilliseconds} ms)',
  );
}
