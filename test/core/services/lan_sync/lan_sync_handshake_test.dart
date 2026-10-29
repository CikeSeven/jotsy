import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_crypto.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_frames.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_handshake.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_identity.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_messages.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_qr_payload.dart';

import 'lan_sync_test_support.dart';

TypeMatcher<LanSyncHandshakeException> failsWith(
  LanSyncHandshakeFailure reason, {
  bool? byPeer,
}) {
  final matcher = isA<LanSyncHandshakeException>().having(
    (e) => e.reason,
    'reason',
    reason,
  );
  return byPeer == null
      ? matcher
      : matcher.having((e) => e.byPeer, 'byPeer', byPeer);
}

void main() {
  late LanSyncIdentity alice;
  late LanSyncIdentity bob;

  setUpAll(() async {
    alice = await LanSyncIdentity.generate();
    bob = await LanSyncIdentity.generate();
  });

  group('trusted sync', () {
    test(
      'establishes a session in either direction and carries messages',
      () async {
        final aliceTrust = TrustList()..add(bob);
        final bobTrust = TrustList()..add(alice);

        for (final aliceInitiates in [true, false]) {
          final (client, server) = await loopbackPair();
          final initiator = aliceInitiates ? alice : bob;
          final responder = aliceInitiates ? bob : alice;
          final initiatorTrust = aliceInitiates ? aliceTrust : bobTrust;
          final responderTrust = aliceInitiates ? bobTrust : aliceTrust;
          final (a, b) = await both(
            testHandshake(initiator, 'I').initiate(
              client,
              LanSyncSyncInitiation(isTrusted: initiatorTrust.check),
            ),
            testHandshake(
              responder,
              'R',
            ).respond(server, syncOnlyPolicy(responderTrust)),
          );
          a as LanSyncHandshakeResult;
          b as LanSyncHandshakeResult;
          expect(a.paired, isFalse);
          expect(b.paired, isFalse);
          expect(a.peer.deviceId, responder.deviceId);
          expect(b.peer.deviceId, initiator.deviceId);
          expect(b.peer.intent, LanSyncIntent.sync);
          expect(b.peer.formatVersion, 1);
          expect(b.peer.publicKey, initiator.publicKey);

          final fromB = b.channel.messages.first;
          final fromA = a.channel.messages.first;
          await a.channel.send(LanSyncMessage('ping', {'n': 1}));
          await b.channel.send(LanSyncMessage('pong', {'n': 2}));
          expect((await fromB).type, 'ping');
          expect((await fromA).fields['n'], 2);
          await a.channel.close();
          await b.channel.done;
        }
      },
    );

    test('derives distinct, deterministic direction keys', () async {
      final shared = List<int>.generate(32, (i) => i + 1);
      final transcript = List<int>.generate(32, (i) => 255 - i);
      final first = await LanSyncSessionKeys.derive(
        sharedSecret: shared,
        transcriptHash: transcript,
      );
      final second = await LanSyncSessionKeys.derive(
        sharedSecret: shared,
        transcriptHash: transcript,
      );
      expect(first.initiatorToResponder, isNot(first.responderToInitiator));
      expect(first.initiatorToResponder, second.initiatorToResponder);
      expect(first.sasCode, second.sasCode);
      expect(
        first.sendKey(LanSyncRole.initiator),
        first.receiveKey(LanSyncRole.responder),
      );
      final other = await LanSyncSessionKeys.derive(
        sharedSecret: shared,
        transcriptHash: [...transcript.skip(1), 0],
      );
      expect(other.initiatorToResponder, isNot(first.initiatorToResponder));
    });

    test('rejects an untrusted initiator on both sides', () async {
      final (client, server) = await loopbackPair();
      final (a, b) = await both(
        testHandshake(alice, 'A').initiate(
          client,
          LanSyncSyncInitiation(isTrusted: (TrustList()..add(bob)).check),
        ),
        testHandshake(bob, 'B').respond(server, syncOnlyPolicy(TrustList())),
      );
      expect(a, failsWith(LanSyncHandshakeFailure.untrusted, byPeer: true));
      expect(b, failsWith(LanSyncHandshakeFailure.untrusted, byPeer: false));
      // 响应方在发出自己的 hello 之前就拒绝：它知道被拒的是谁，发起方本来就知道
      // 自己连的是哪台。
      expect((b as LanSyncHandshakeException).peer?.deviceId, alice.deviceId);
    });

    test('rejects an untrusted responder on both sides', () async {
      final (client, server) = await loopbackPair();
      final (a, b) = await both(
        testHandshake(
          alice,
          'A',
        ).initiate(client, LanSyncSyncInitiation(isTrusted: TrustList().check)),
        testHandshake(
          bob,
          'B',
        ).respond(server, syncOnlyPolicy(TrustList()..add(alice))),
      );
      expect(a, failsWith(LanSyncHandshakeFailure.untrusted, byPeer: false));
      expect(b, failsWith(LanSyncHandshakeFailure.untrusted, byPeer: true));
    });

    test(
      'a device claiming a trusted identity without its key fails',
      () async {
        // 中间人宣称自己是 bob（deviceId 与公钥都是 bob 的），但只能用自己的私钥签名。
        final impostorSeed = lanSyncRandomBytes(32);
        final impostor = LanSyncIdentity(
          deviceId: bob.deviceId,
          signingKey: SimpleKeyPairData(
            impostorSeed,
            publicKey: SimplePublicKey(
              bob.publicKey,
              type: KeyPairType.ed25519,
            ),
            type: KeyPairType.ed25519,
          ),
          createdAt: DateTime.now(),
        );
        final (client, server) = await loopbackPair();
        final (a, b) = await both(
          testHandshake(alice, 'A').initiate(
            client,
            LanSyncSyncInitiation(isTrusted: (TrustList()..add(bob)).check),
          ),
          testHandshake(
            impostor,
            'M',
          ).respond(server, syncOnlyPolicy(TrustList()..add(alice))),
        );
        expect(
          a,
          failsWith(LanSyncHandshakeFailure.badSignature, byPeer: false),
        );
        expect(
          b,
          failsWith(LanSyncHandshakeFailure.badSignature, byPeer: true),
        );
      },
    );

    test('reports a closed connection', () async {
      final (client, server) = await loopbackPair();
      server.destroy();
      await expectLater(
        testHandshake(
          alice,
          'A',
        ).initiate(client, LanSyncSyncInitiation(isTrusted: (_, _) => true)),
        throwsA(failsWith(LanSyncHandshakeFailure.connectionClosed)),
      );
    });

    test('rejects a different protocol version and says which', () async {
      final (client, server) = await loopbackPair();
      final responding = testHandshake(
        bob,
        'B',
      ).respond(server, syncOnlyPolicy(TrustList()));
      final reader = LanSyncFrameReader(client);
      client.add(
        lanSyncPlainFrame(
          utf8.encode(jsonEncode({'type': 'hs.hello', 'v': 2})),
        ),
      );
      await expectLater(
        responding,
        throwsA(
          failsWith(
            LanSyncHandshakeFailure.versionMismatch,
            byPeer: false,
          ).having((e) => e.peerProtocolVersion, 'peer version', 2),
        ),
      );
      final reply = LanSyncMessage.decode(
        (await reader.next(maxLength: kLanSyncHandshakeFrameMax))!,
      );
      expect(reply.type, LanSyncMessageTypes.reject);
      expect(reply.fields['reason'], 'version');
      expect(reply.fields['v'], kLanSyncProtocolVersion);
      client.destroy();
    });
  });

  group('SAS pairing', () {
    test('both sides see the same code and pair after confirming', () async {
      final codes = <String>[];
      final (client, server) = await loopbackPair();
      final (a, b) = await both(
        testHandshake(alice, 'A').initiate(
          client,
          LanSyncSasPairing(
            confirmSas: (code, peer) async {
              expect(peer.deviceId, bob.deviceId);
              codes.add(code);
              return true;
            },
          ),
        ),
        testHandshake(bob, 'B').respond(
          server,
          LanSyncResponderPolicy(
            isTrusted: (_, _) => false,
            confirmSas: (code, peer) async {
              expect(peer.intent, LanSyncIntent.pair);
              codes.add(code);
              return true;
            },
            consumeQrToken: (_) => false,
          ),
        ),
      );
      a as LanSyncHandshakeResult;
      b as LanSyncHandshakeResult;
      expect(codes, hasLength(2));
      expect(codes.first, matches(RegExp(r'^\d{6}$')));
      expect(codes.first, codes.last);
      expect(a.paired && b.paired, isTrue);
      expect(a.pairingMethod, LanSyncPairingMethod.sas);
      expect(a.peer.publicKey, bob.publicKey);
      expect(b.peer.publicKey, alice.publicKey);

      final received = b.channel.messages.first;
      await a.channel.send(LanSyncMessage('after-pairing'));
      expect((await received).type, 'after-pairing');
      await a.channel.close();
    });

    test('one side rejecting fails both without pairing', () async {
      final (client, server) = await loopbackPair();
      final (a, b) = await both(
        testHandshake(
          alice,
          'A',
        ).initiate(client, LanSyncSasPairing(confirmSas: (_, _) async => true)),
        testHandshake(bob, 'B').respond(
          server,
          LanSyncResponderPolicy(
            isTrusted: (_, _) => true,
            confirmSas: (_, _) async => false,
            consumeQrToken: (_) => true,
          ),
        ),
      );
      expect(a, failsWith(LanSyncHandshakeFailure.sasRejected, byPeer: true));
      expect(b, failsWith(LanSyncHandshakeFailure.sasRejected, byPeer: false));
    });

    test('times out when a user never answers', () async {
      final never = Completer<bool>();
      final (client, server) = await loopbackPair();
      final (a, b) = await both(
        testHandshake(
          alice,
          'A',
          sasTimeout: const Duration(seconds: 2),
        ).initiate(client, LanSyncSasPairing(confirmSas: (_, _) async => true)),
        testHandshake(
          bob,
          'B',
          sasTimeout: const Duration(milliseconds: 300),
        ).respond(
          server,
          LanSyncResponderPolicy(
            isTrusted: (_, _) => true,
            confirmSas: (_, _) => never.future,
            consumeQrToken: (_) => false,
          ),
        ),
      );
      expect(b, failsWith(LanSyncHandshakeFailure.timeout, byPeer: false));
      expect(a, failsWith(LanSyncHandshakeFailure.timeout, byPeer: true));
    });

    test('a relaying man-in-the-middle cannot make the codes match', () async {
      final mallory = await LanSyncIdentity.generate();
      final aliceCode = Completer<String>();
      final bobCode = Completer<String>();
      // 中间人分别与两端完成握手（各用自己的密钥），并替两端确认核对码。
      final (aliceSocket, malloryFacingAlice) = await loopbackPair();
      final (malloryFacingBob, bobSocket) = await loopbackPair();
      final results = await Future.wait([
        both(
          testHandshake(alice, 'A').initiate(
            aliceSocket,
            LanSyncSasPairing(
              confirmSas: (code, _) async {
                aliceCode.complete(code);
                return true;
              },
            ),
          ),
          testHandshake(mallory, 'M').respond(
            malloryFacingAlice,
            LanSyncResponderPolicy(
              isTrusted: (_, _) => false,
              confirmSas: (_, _) async => true,
              consumeQrToken: (_) => false,
            ),
          ),
        ),
        both(
          testHandshake(mallory, 'M').initiate(
            malloryFacingBob,
            LanSyncSasPairing(confirmSas: (_, _) async => true),
          ),
          testHandshake(bob, 'B').respond(
            bobSocket,
            LanSyncResponderPolicy(
              isTrusted: (_, _) => false,
              confirmSas: (code, _) async {
                bobCode.complete(code);
                return true;
              },
              consumeQrToken: (_) => false,
            ),
          ),
        ),
      ]);
      // 两端看到的是各自与中间人之间的核对码：几乎必然不同，用户核对即发现。
      expect(await aliceCode.future, isNot(await bobCode.future));
      for (final (x, y) in results) {
        for (final result in [x, y]) {
          if (result is LanSyncHandshakeResult) {
            result.channel.destroy();
          }
        }
      }
    });

    test('rejects a reveal that does not match the commitment', () async {
      final (client, server) = await loopbackPair();
      final responding = testHandshake(bob, 'B').respond(
        server,
        LanSyncResponderPolicy(
          isTrusted: (_, _) => true,
          confirmSas: (_, _) async => true,
          consumeQrToken: (_) => true,
        ),
      );
      // 伪造的发起方：承诺一把临时公钥，看到对方的之后揭示另一把。
      final committed = await X25519().newKeyPair();
      final swapped = await X25519().newKeyPair();
      final nonce = lanSyncRandomBytes(32);
      final hello = LanSyncPeerHello(
        protocolVersion: kLanSyncProtocolVersion,
        formatVersion: 1,
        deviceId: alice.deviceId,
        name: 'A',
        platform: 'linux',
        publicKey: alice.publicKey,
        nonce: nonce,
        intent: LanSyncIntent.pair,
        pairingMethod: LanSyncPairingMethod.sas,
        commitment: lanSyncCommitment(
          (await committed.extractPublicKey()).bytes,
          nonce,
        ),
      );
      final reader = LanSyncFrameReader(client);
      client.add(lanSyncPlainFrame(hello.toMessage().encode()));
      await reader.next(maxLength: kLanSyncHandshakeFrameMax);
      client.add(
        lanSyncPlainFrame(
          LanSyncMessage(LanSyncMessageTypes.reveal, {
            'eph': base64.encode((await swapped.extractPublicKey()).bytes),
          }).encode(),
        ),
      );
      await expectLater(
        responding,
        throwsA(failsWith(LanSyncHandshakeFailure.commitmentMismatch)),
      );
      // 响应方不回应、直接断开。
      expect(await reader.next(maxLength: kLanSyncHandshakeFrameMax), isNull);
      client.destroy();
    });
  });

  group('QR pairing', () {
    Future<(Object, Object)> pairByQr({
      required LanSyncQrToken token,
      required String presented,
      String? fingerprint,
    }) async {
      final (client, server) = await loopbackPair();
      return both(
        testHandshake(alice, 'A').initiate(
          client,
          LanSyncQrPairing(
            fingerprint: fingerprint ?? bob.fingerprint,
            token: presented,
          ),
        ),
        testHandshake(bob, 'B').respond(
          server,
          LanSyncResponderPolicy(
            isTrusted: (_, _) => false,
            confirmSas: (_, _) async => fail('QR pairing must not ask for SAS'),
            consumeQrToken: token.consume,
          ),
        ),
      );
    }

    test('pairs with a valid token and then rejects its reuse', () async {
      final token = LanSyncQrToken.generate();
      final (a, b) = await pairByQr(token: token, presented: token.value);
      a as LanSyncHandshakeResult;
      b as LanSyncHandshakeResult;
      expect(a.pairingMethod, LanSyncPairingMethod.qr);
      expect(b.paired, isTrue);
      expect(b.peer.publicKey, alice.publicKey);
      expect(token.isUsed, isTrue);
      await a.channel.close();

      final (a2, b2) = await pairByQr(token: token, presented: token.value);
      expect(
        a2,
        failsWith(LanSyncHandshakeFailure.tokenRejected, byPeer: true),
      );
      expect(
        b2,
        failsWith(LanSyncHandshakeFailure.tokenRejected, byPeer: false),
      );
    });

    test('rejects a wrong token without spending the real one', () async {
      final token = LanSyncQrToken.generate();
      final (a, b) = await pairByQr(
        token: token,
        presented: LanSyncQrToken.generate().value,
      );
      expect(a, failsWith(LanSyncHandshakeFailure.tokenRejected, byPeer: true));
      expect(b, failsWith(LanSyncHandshakeFailure.tokenRejected));
      expect(token.isUsed, isFalse);
    });

    test('rejects an expired token', () async {
      final token = LanSyncQrToken.generate(
        now: DateTime.now().subtract(const Duration(minutes: 3)),
      );
      final (a, _) = await pairByQr(token: token, presented: token.value);
      expect(a, failsWith(LanSyncHandshakeFailure.tokenRejected, byPeer: true));
    });

    test(
      'aborts before revealing when the fingerprint does not match',
      () async {
        final token = LanSyncQrToken.generate();
        final (a, b) = await pairByQr(
          token: token,
          presented: token.value,
          fingerprint: alice.fingerprint,
        );
        expect(
          a,
          failsWith(LanSyncHandshakeFailure.fingerprintMismatch, byPeer: false),
        );
        expect(
          b,
          failsWith(LanSyncHandshakeFailure.fingerprintMismatch, byPeer: true),
        );
        expect(token.isUsed, isFalse);
      },
    );
  });

  test('times out on a silent responder and closes the connection', () async {
    // 握手失败后连接被关闭：对端的套接字随之结束，不留下悬空连接。
    final (client, server) = await loopbackPair();
    final closed = server.drain<void>().then((_) => true, onError: (_) => true);
    await expectLater(
      testHandshake(
        alice,
        'A',
        stepTimeout: const Duration(milliseconds: 200),
      ).initiate(client, LanSyncSyncInitiation(isTrusted: (_, _) => true)),
      throwsA(failsWith(LanSyncHandshakeFailure.timeout)),
    );
    expect(await closed, isTrue);
    server.destroy();
  });
}
