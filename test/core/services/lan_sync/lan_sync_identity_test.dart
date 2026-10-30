import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_crypto.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_identity.dart';

void main() {
  late Directory stateDir;

  setUp(() async {
    stateDir = await Directory.systemTemp.createTemp('lan_sync_identity_');
  });

  tearDown(() async {
    await stateDir.delete(recursive: true);
  });

  File identityFile() => File('${stateDir.path}/identity.json');

  test('creates an identity once and reloads the same one', () async {
    final store = LanSyncIdentityStore(stateDir);
    final first = await store.loadOrCreate();
    expect(first.created, isTrue);
    expect(
      first.identity.deviceId,
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-')),
    );
    expect(first.identity.fingerprint, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(
      first.identity.shortFingerprint,
      first.identity.fingerprint.substring(0, 16),
    );
    expect(File('${identityFile().path}.tmp').existsSync(), isFalse);

    final second = await LanSyncIdentityStore(stateDir).loadOrCreate();
    expect(second.created, isFalse);
    expect(second.identity.deviceId, first.identity.deviceId);
    expect(second.identity.publicKey, first.identity.publicKey);
  });

  test('signatures verify against the stored public key', () async {
    final identity = (await LanSyncIdentityStore(
      stateDir,
    ).loadOrCreate()).identity;
    final message = utf8.encode('jotsy');
    final signature = await identity.sign(message);
    final valid = await Ed25519().verify(
      message,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(
          identity.publicKey,
          type: KeyPairType.ed25519,
        ),
      ),
    );
    expect(valid, isTrue);
    expect(lanSyncFingerprint(identity.publicKey), identity.fingerprint);
  });

  test('regenerates a corrupt file and reports it as new', () async {
    final first = await LanSyncIdentityStore(stateDir).loadOrCreate();
    final corruptions = [
      'not json',
      '{"v":1}',
      jsonEncode({
        'v': 1,
        'deviceId': first.identity.deviceId,
        'ed25519Seed': base64.encode([1, 2, 3]),
        'createdAt': 0,
      }),
      jsonEncode({
        'v': 2,
        'deviceId': first.identity.deviceId,
        'ed25519Seed': base64.encode(List.filled(32, 1)),
        'createdAt': 0,
      }),
    ];
    for (final content in corruptions) {
      await identityFile().writeAsString(content);
      final reloaded = await LanSyncIdentityStore(stateDir).loadOrCreate();
      expect(reloaded.created, isTrue, reason: content);
      expect(reloaded.identity.deviceId, isNot(first.identity.deviceId));
      final again = await LanSyncIdentityStore(stateDir).loadOrCreate();
      expect(again.created, isFalse);
      expect(again.identity.deviceId, reloaded.identity.deviceId);
    }
  });

  test(
    'stores the device id and Ed25519 seed only (no static X25519)',
    () async {
      await LanSyncIdentityStore(stateDir).loadOrCreate();
      final json =
          jsonDecode(await identityFile().readAsString())
              as Map<String, Object?>;
      expect(
        json.keys,
        unorderedEquals(['v', 'deviceId', 'ed25519Seed', 'createdAt']),
      );
      expect(base64.decode(json['ed25519Seed']! as String), hasLength(32));
    },
  );

  group('crypto helpers', () {
    test('SAS codes are six zero-padded digits', () {
      expect(lanSyncSasCode(List.filled(8, 0)), '000000');
      // 0x0f4240 = 1 000 000 → 取模后为 0；0x0f423f = 999 999。
      expect(lanSyncSasCode([0, 0, 0, 0x0f, 0x42, 0x40, 9, 9]), '000000');
      expect(lanSyncSasCode([0, 0, 0, 0x0f, 0x42, 0x3f, 9, 9]), '999999');
      expect(lanSyncSasCode([0, 0, 0, 0, 0, 7, 0, 0]), '000007');
    });

    test('commitments bind both the key and the nonce', () {
      final key = List<int>.filled(32, 1);
      final nonce = List<int>.filled(32, 2);
      final commitment = lanSyncCommitment(key, nonce);
      expect(lanSyncCommitment(key, nonce), commitment);
      expect(lanSyncCommitment(List.filled(32, 3), nonce), isNot(commitment));
      expect(lanSyncCommitment(key, List.filled(32, 3)), isNot(commitment));
    });
  });
}
