import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_channel.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_crypto.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_frames.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_messages.dart';

import 'lan_sync_test_support.dart';

final List<int> _i2r = List<int>.generate(32, (i) => i);
final List<int> _r2i = List<int>.generate(32, (i) => 100 + i);

/// 用固定密钥在套接字上建信道（跳过握手，专测信道本身）。
LanSyncChannel _channelOn(Socket socket, {required bool initiator}) {
  final self = initiator ? LanSyncRole.initiator : LanSyncRole.responder;
  final peer = initiator ? LanSyncRole.responder : LanSyncRole.initiator;
  return LanSyncChannel.establish(
    socket: socket,
    reader: LanSyncFrameReader(socket),
    sendCipher: LanSyncFrameCipher(key: initiator ? _i2r : _r2i, sender: self),
    receiveCipher: LanSyncFrameCipher(
      key: initiator ? _r2i : _i2r,
      sender: peer,
    ),
    lingerTimeout: const Duration(milliseconds: 300),
  )..start();
}

Future<(LanSyncChannel, LanSyncChannel)> _channelPair() async {
  final (client, server) = await loopbackPair();
  return (
    _channelOn(client, initiator: true),
    _channelOn(server, initiator: false),
  );
}

/// 发起方方向的“手工”发送端：直接产出密文帧，供篡改、重放与乱序测试。
Future<(Socket, LanSyncChannel, LanSyncFrameCipher)> _rawToChannel() async {
  final (client, server) = await loopbackPair();
  return (
    client,
    _channelOn(server, initiator: false),
    LanSyncFrameCipher(key: _i2r, sender: LanSyncRole.initiator),
  );
}

Uint8List _messageFrame(LanSyncFrameCipher cipher, String type) {
  return cipher.seal([0x01, ...LanSyncMessage(type).encode()]);
}

TypeMatcher<LanSyncChannelException> _channelError(LanSyncChannelError e) =>
    isA<LanSyncChannelException>().having((x) => x.error, 'error', e);

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

/// 把内核收发缓冲压到最小，使“发送方被接收方拖住”可以在几百 KiB 内观察到
/// （Linux 回环的接收缓冲可自动增长到 32 MiB，会掩盖背压）。
void _clampKernelBuffers(Socket socket) {
  if (!Platform.isLinux) return;
  const soSndBuf = 7;
  const soRcvBuf = 8;
  for (final option in [soSndBuf, soRcvBuf]) {
    socket.setRawOption(
      RawSocketOption.fromInt(RawSocketOption.levelSocket, option, 64 * 1024),
    );
  }
}

void main() {
  test(
    'messages round-trip both ways, including fragmented large ones',
    () async {
      final (a, b) = await _channelPair();
      final big = 'x' * (300 * 1024);
      final atB = b.messages.take(2).toList();
      final atA = a.messages.first;
      await a.send(LanSyncMessage('small', {'n': 1}));
      await a.send(LanSyncMessage('big', {'text': big}));
      await b.send(LanSyncMessage('reply'));
      final received = await atB;
      expect(received.map((m) => m.type), ['small', 'big']);
      expect(received.last.fields['text'], big);
      expect((await atA).type, 'reply');
      await a.close();
      await b.done;
    },
  );

  test('a clean close ends both sides without errors', () async {
    final (a, b) = await _channelPair();
    final bMessages = b.messages.toList();
    await a.close();
    expect(await bMessages, isEmpty);
    await b.done;
    await a.done;
    await expectLater(
      a.send(LanSyncMessage('late')),
      throwsA(_channelError(LanSyncChannelError.closed)),
    );
    expect(b.isClosed, isTrue);
  });

  test('a tampered ciphertext byte closes the channel with an error', () async {
    final (raw, b, cipher) = await _rawToChannel();
    final rawClosed = raw.drain<void>().then((_) => true, onError: (_) => true);
    final frame = _messageFrame(cipher, 'hello');
    frame[frame.length - 20] ^= 0x01;
    raw.add(frame);
    await expectLater(
      b.messages,
      emitsInOrder([
        emitsError(_channelError(LanSyncChannelError.authenticationFailed)),
        emitsDone,
      ]),
    );
    await expectLater(
      b.done,
      throwsA(_channelError(LanSyncChannelError.authenticationFailed)),
    );
    expect(await rawClosed, isTrue);
    raw.destroy();
  });

  test(
    'a replayed frame is rejected after the original is delivered',
    () async {
      final (raw, b, cipher) = await _rawToChannel();
      final frame = _messageFrame(cipher, 'once');
      raw
        ..add(frame)
        ..add(frame);
      await expectLater(
        b.messages,
        emitsInOrder([
          isA<LanSyncMessage>().having((m) => m.type, 'type', 'once'),
          emitsError(_channelError(LanSyncChannelError.authenticationFailed)),
          emitsDone,
        ]),
      );
      raw.destroy();
    },
  );

  test('reordered frames are rejected', () async {
    final (raw, b, cipher) = await _rawToChannel();
    final first = _messageFrame(cipher, 'first');
    final second = _messageFrame(cipher, 'second');
    raw
      ..add(second)
      ..add(first);
    await expectLater(
      b.messages,
      emitsInOrder([
        emitsError(_channelError(LanSyncChannelError.authenticationFailed)),
        emitsDone,
      ]),
    );
    raw.destroy();
  });

  test('an oversized frame header is a protocol error', () async {
    final (raw, b, _) = await _rawToChannel();
    raw.add([0x00, 0x10, 0x00, 0x00]); // 1 MiB
    await expectLater(
      b.done,
      throwsA(_channelError(LanSyncChannelError.protocolError)),
    );
    raw.destroy();
  });

  test('a connection ending without a close frame is reported', () async {
    final (raw, b, cipher) = await _rawToChannel();
    raw.add(_messageFrame(cipher, 'last words'));
    await raw.flush();
    raw.destroy();
    await expectLater(
      b.messages,
      emitsInOrder([
        isA<LanSyncMessage>(),
        emitsError(_channelError(LanSyncChannelError.connectionLost)),
        emitsDone,
      ]),
    );
  });

  test(
    'streams a 20 MB blob with backpressure while messages interleave',
    () async {
      const total = 20 * 1024 * 1024;
      final (client, server) = await loopbackPair();
      _clampKernelBuffers(client);
      _clampKernelBuffers(server);
      final a = _channelOn(client, initiator: true);
      final b = _channelOn(server, initiator: false);

      final sentDigest = _DigestSink();
      final sentHash = sha256.startChunkedConversion(sentDigest);
      var produced = 0;
      var received = 0;
      final receivedAtMessage = <String, int>{};
      final messagesDone = b.messages.take(2).forEach((message) {
        receivedAtMessage[message.type] = received;
      });

      Stream<List<int>> source() async* {
        final random = Random(42);
        var midwaySent = false;
        while (produced < total) {
          // 故意用与帧不对齐的块长，覆盖发送端的重新分帧。
          final n = min(40000 + random.nextInt(50000), total - produced);
          final chunk = Uint8List(n);
          for (var i = 0; i < n; i++) {
            chunk[i] = random.nextInt(256);
          }
          sentHash.add(chunk);
          produced += n;
          if (!midwaySent && produced >= total ~/ 2) {
            midwaySent = true;
            unawaited(a.send(LanSyncMessage('midway')));
          }
          yield chunk;
        }
        sentHash.close();
      }

      final sending = a.sendBlob(7, source(), total);
      unawaited(a.send(LanSyncMessage('right-after-start')));

      final blob = await b.blobs.first;
      expect(blob.id, 7);
      expect(blob.length, total);
      final receivedDigest = _DigestSink();
      final receivedHash = sha256.startChunkedConversion(receivedDigest);
      final finished = Completer<void>();
      late final StreamSubscription<Uint8List> subscription;
      var paused = false;
      var leadWhilePaused = 0;
      subscription = blob.data.listen(
        (chunk) {
          received += chunk.length;
          receivedHash.add(chunk);
          if (!paused && received > 1024 * 1024) {
            paused = true;
            subscription.pause();
            // 停顿期间发送方只能把有限的字节塞进缓冲：多等不会让断言更容易失败，
            // 只有背压失效（整块读入内存）时领先量才会逼近 20 MB。
            Future<void>.delayed(const Duration(milliseconds: 300), () {
              leadWhilePaused = produced - received;
              subscription.resume();
            });
          }
        },
        onDone: () {
          receivedHash.close();
          finished.complete();
        },
        onError: finished.completeError,
      );
      await finished.future;
      await sending;
      await messagesDone;

      expect(received, total);
      expect(receivedDigest.value, sentDigest.value);
      expect(paused, isTrue);
      expect(leadWhilePaused, lessThan(Platform.isLinux ? 4 << 20 : 16 << 20));
      expect(receivedAtMessage['right-after-start'], lessThan(total));
      expect(receivedAtMessage['midway'], lessThan(total));
      await a.close();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a short blob is aborted on both sides and the channel survives',
    () async {
      final (a, b) = await _channelPair();
      final blobs = b.blobs.first;
      await expectLater(
        a.sendBlob(1, Stream.value(List<int>.filled(10, 1)), 20),
        throwsArgumentError,
      );
      final blob = await blobs;
      await expectLater(
        blob.data,
        emitsInOrder([
          isA<Uint8List>(),
          emitsError(_channelError(LanSyncChannelError.blobAborted)),
          emitsDone,
        ]),
      );
      final next = b.messages.first;
      await a.send(LanSyncMessage('still-alive'));
      expect((await next).type, 'still-alive');
      await a.close();
    },
  );

  test('a cancelled blob is skipped without stalling later messages', () async {
    final (a, b) = await _channelPair();
    final next = b.messages.first;
    final blobs = b.blobs.listen((blob) => blob.data.listen(null).cancel());
    final payload = List<int>.filled(300 * 1024, 9);
    await a.sendBlob(2, Stream.value(payload), payload.length);
    await a.send(LanSyncMessage('after-blob'));
    expect((await next).type, 'after-blob');
    await blobs.cancel();
    await a.close();
  });

  test('closing mid-blob ends the incoming blob with an error', () async {
    final (a, b) = await _channelPair();
    final gate = Completer<void>();
    Stream<List<int>> slow() async* {
      yield List<int>.filled(1000, 1);
      await gate.future;
    }

    final sending = a.sendBlob(3, slow(), 5000);
    final blob = await b.blobs.first;
    // 发送端攒满一帧才写出，这 1000 字节还在发送端：接收方只看到开始与关闭。
    final data = expectLater(
      blob.data,
      emitsInOrder([
        emitsError(_channelError(LanSyncChannelError.closed)),
        emitsDone,
      ]),
    );
    await a.close();
    await data;
    gate.complete();
    await expectLater(sending, throwsA(isA<LanSyncChannelException>()));
  });

  test('frame cipher binds the direction prefix', () {
    final sealer = LanSyncFrameCipher(key: _i2r, sender: LanSyncRole.initiator);
    final frame = sealer.seal(utf8.encode('payload'));
    final body = Uint8List.sublistView(frame, 4);
    final wrongDirection = LanSyncFrameCipher(
      key: _i2r,
      sender: LanSyncRole.responder,
    );
    expect(
      () => wrongDirection.open(body),
      throwsA(isA<LanSyncAuthenticationException>()),
    );
    final right = LanSyncFrameCipher(key: _i2r, sender: LanSyncRole.initiator);
    expect(utf8.decode(right.open(body)), 'payload');
  });
}
