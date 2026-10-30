import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_qr_payload.dart';

void main() {
  final token = LanSyncQrToken.generate().value;
  final fingerprint = 'ab' * 32;

  LanSyncQrPayload payload({
    List<String> hosts = const ['192.168.1.20', 'fe80::1'],
    int port = 24562,
    String name = '书房的电脑',
  }) {
    return LanSyncQrPayload(
      hosts: hosts,
      port: port,
      deviceId: '0f8fad5b-d9cb-469f-a165-70867728950e',
      fingerprint: fingerprint,
      token: token,
      name: name,
    );
  }

  /// 直接拼载荷 JSON（绕过编码端的校验），测试解码端的拒绝路径。
  String rawCode(
    Map<String, Object?> json, {
    String prefix = kLanSyncQrPrefix,
  }) {
    final body = base64Url.encode(utf8.encode(jsonEncode(json)));
    return '$prefix${body.replaceAll('=', '')}';
  }

  Map<String, Object?> validJson() => {
    'fp': fingerprint,
    'h': ['10.0.0.2'],
    'id': 'device-1',
    'n': 'Pixel',
    'p': 24562,
    't': token,
  };

  Matcher rejects(LanSyncQrError error) => throwsA(
    isA<LanSyncQrFormatException>().having((e) => e.error, 'error', error),
  );

  test('round-trips with canonical sorted-key JSON', () {
    final code = payload().encode();
    expect(code, startsWith('jotsy-lan:v1:'));
    expect(code, isNot(contains('=')));
    final json = utf8.decode(
      base64Url.decode(base64Url.normalize(code.substring(13))),
    );
    expect(json, startsWith('{"fp":'));
    expect(json, isNot(contains(' ')));
    final decoded = LanSyncQrPayload.decode(code);
    expect(decoded.hosts, ['192.168.1.20', 'fe80::1']);
    expect(decoded.port, 24562);
    expect(decoded.fingerprint, fingerprint);
    expect(decoded.token, token);
    expect(decoded.name, '书房的电脑');
    expect(decoded.encode(), code);
  });

  test('rejects other prefixes and versions', () {
    expect(
      () => LanSyncQrPayload.decode('https://example.com'),
      rejects(LanSyncQrError.notLanSync),
    );
    expect(
      () => LanSyncQrPayload.decode(
        rawCode(validJson(), prefix: 'jotsy-lan:v2:'),
      ),
      rejects(LanSyncQrError.unsupportedVersion),
    );
  });

  test('rejects malformed bodies and fields', () {
    final cases = <Map<String, Object?>>[
      {...validJson()}..remove('t'),
      {...validJson(), 'extra': 1},
      {...validJson(), 'p': 0},
      {...validJson(), 'p': 65536},
      {...validJson(), 'p': '24562'},
      {...validJson(), 'h': <String>[]},
      {
        ...validJson(),
        'h': ['not-an-ip'],
      },
      {...validJson(), 'h': List.filled(9, '10.0.0.1')},
      {...validJson(), 'fp': 'AB' * 32},
      {...validJson(), 'fp': 'ab' * 8},
      {...validJson(), 't': 'short'},
      {...validJson(), 'n': ''},
      {...validJson(), 'n': 'x' * 101},
      {...validJson(), 'id': 'bad id with spaces'},
    ];
    for (final json in cases) {
      expect(
        () => LanSyncQrPayload.decode(rawCode(json)),
        rejects(LanSyncQrError.malformed),
        reason: '$json',
      );
    }
    expect(
      () => LanSyncQrPayload.decode('$kLanSyncQrPrefix%%%'),
      rejects(LanSyncQrError.malformed),
    );
    expect(
      () => LanSyncQrPayload.decode('$kLanSyncQrPrefix${'A' * 4000}'),
      rejects(LanSyncQrError.malformed),
    );
  });

  test('refuses to encode a payload it could not decode', () {
    expect(() => payload(port: 0).encode(), throwsArgumentError);
    expect(() => payload(hosts: const []).encode(), throwsArgumentError);
    expect(() => payload(name: 'x' * 101).encode(), throwsArgumentError);
  });

  group('one-time token', () {
    test('is 128-bit url-safe text', () {
      final value = LanSyncQrToken.generate().value;
      expect(value, matches(RegExp(r'^[A-Za-z0-9_-]{22}$')));
      expect(LanSyncQrToken.generate().value, isNot(value));
    });

    test('can be consumed once, within two minutes', () {
      final created = DateTime(2026, 10, 1, 12);
      final qr = LanSyncQrToken.generate(now: created);
      final soon = created.add(const Duration(seconds: 30));
      expect(qr.consume('wrong', now: soon), isFalse);
      expect(qr.isValidAt(soon), isTrue);
      expect(qr.consume(qr.value, now: soon), isTrue);
      expect(qr.consume(qr.value, now: soon), isFalse);
    });

    test('expires and ignores clocks set before it was made', () {
      final created = DateTime(2026, 10, 1, 12);
      final qr = LanSyncQrToken.generate(now: created);
      expect(
        qr.consume(qr.value, now: created.add(LanSyncQrToken.validity)),
        isFalse,
      );
      expect(
        qr.consume(qr.value, now: created.subtract(const Duration(seconds: 1))),
        isFalse,
      );
      expect(qr.isUsed, isFalse);
    });
  });
}
