import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_cloud_envelope.dart';
import 'package:node_diary/core/services/journal_import_cloud_http.dart';

import '../../support/cloud_test_keys.dart';

void main() {
  final pair = cloudTestKeys;

  test('parses the vendors\' published RSA public keys', () {
    for (final pem in [oppoPublicKeyPem, vivoPublicKeyPem]) {
      final key = rsaPublicKeyFromPem(pem);
      expect(key.modulus!.bitLength, 2048);
      expect(key.exponent, BigInt.from(65537));
    }
  });

  test('OPPO envelope: the server can unwrap it and reply with the key', () {
    final envelope = OppoEnvelope(
      {'pageNo': 1, 'name': '笔记'},
      publicKey: pair.publicKey,
      random: Random(7),
    );
    final payload = envelope.payload;

    // 服务端：私钥解出 32 个十六进制字符的 AES-256 会话密钥。
    final key = unwrapCloudTestKey(base64.decode(payload['key']!));
    expect(ascii.decode(key), matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(payload['iv'], matches(RegExp(r'^[0-9a-f]{16}$')));
    final request = aesCbc(
      key,
      ascii.encode(payload['iv']!),
      base64.decode(payload['encryptContent']!),
      false,
    );
    expect(jsonDecode(utf8.decode(request)), {'pageNo': 1, 'name': '笔记'});

    // 响应用同一把密钥、另一个 IV 加密。
    const iv = 'fedcba9876543210';
    final reply = base64.encode(
      aesCbc(key, ascii.encode(iv), utf8.encode('{"code":0,"data":[1]}'), true),
    );
    expect(envelope.decrypt({'iv': iv, 'encryptContent': reply}), {
      'code': 0,
      'data': [1],
    });
    expect(
      () => envelope.decrypt({'iv': iv, 'encryptContent': 'AAAA'}),
      throwsA(isA<CloudNoteException>()),
    );
  });

  test('vivo envelope: header layout, round trip and checksum', () {
    final envelope = VivoEnvelope(publicKey: pair.publicKey, random: Random(3));
    final encoded = envelope.encrypt('{"a":"你好"}');
    expect(encoded, isNot(contains('=')));

    final raw = base64Url.decode(
      encoded + '=' * ((4 - encoded.length % 4) % 4),
    );
    final data = ByteData.sublistView(raw);
    expect(data.getUint16(10), 32);
    expect(data.getUint16(12), 203);
    expect(raw[17], 'com.android.notes'.length);
    expect(ascii.decode(raw.sublist(18, 35)), 'com.android.notes');
    final iv = ascii.decode(raw.sublist(35, 51));
    expect(iv, matches(RegExp(r'^[0-9A-Z]{16}$')));
    final keySize = data.getUint16(51);
    final key = unwrapCloudTestKey(raw.sublist(53, 53 + keySize));
    expect(ascii.decode(key), matches(RegExp(r'^[0-9A-Z]{16}$')));
    expect(data.getUint16(0), 53 + keySize);

    // 服务端回复沿用同样的头部与密钥。
    expect(envelope.decrypt(encoded), '{"a":"你好"}');
    final tampered = Uint8List.fromList(raw)..[20] ^= 1;
    expect(
      () => envelope.decrypt(base64Url.encode(tampered)),
      throwsA(isA<CloudNoteException>()),
    );
  });
}
