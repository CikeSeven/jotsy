import 'package:flutter_test/flutter_test.dart';

import '../../tool/cloud_backup_keys.dart';

void main() {
  const valid = <String, String>{
    'JOTSY_GOOGLE_CLIENT_ID': '123-abc.apps.googleusercontent.com',
    'JOTSY_GOOGLE_CLIENT_SECRET': 'GOCSPX-a_b-c',
    'JOTSY_DROPBOX_APP_KEY': 'abc123',
    'JOTSY_MICROSOFT_CLIENT_ID': '01234567-89ab-cdef-0123-456789abcdef',
    'JOTSY_BAIDU_APP_KEY': 'Key1',
    'JOTSY_BAIDU_SECRET_KEY': 'Secret1',
    'JOTSY_BAIDU_APP_DIR': 'Jotsy 日记',
    'JOTSY_ALIYUN_CLIENT_ID': 'abc',
    'UNRELATED': 'ignored',
  };

  test('keeps configured keys and warns about the missing ones', () {
    final keys = readCloudBackupKeys(valid);
    expect(keys.values.keys, <String>[
      'JOTSY_GOOGLE_CLIENT_ID',
      'JOTSY_GOOGLE_CLIENT_SECRET',
      'JOTSY_DROPBOX_APP_KEY',
      'JOTSY_MICROSOFT_CLIENT_ID',
      'JOTSY_BAIDU_APP_KEY',
      'JOTSY_BAIDU_SECRET_KEY',
      'JOTSY_BAIDU_APP_DIR',
      'JOTSY_ALIYUN_CLIENT_ID',
    ]);
    expect(keys.values['JOTSY_BAIDU_APP_DIR'], 'Jotsy 日记');
    expect(keys.warnings, isEmpty);
  });

  test('nothing configured is allowed, with a warning per drive', () {
    final keys = readCloudBackupKeys(const <String, String>{
      'JOTSY_DROPBOX_APP_KEY': '',
    });
    expect(keys.values, isEmpty);
    expect(keys.warnings, hasLength(5));
  });

  test('fails on malformed, multi-line or padded values without the value', () {
    for (final (name, value) in <(String, String)>[
      ('JOTSY_DROPBOX_APP_KEY', 'UPPER'),
      ('JOTSY_GOOGLE_CLIENT_SECRET', 'GOCSPX-ok\nsecond'),
      ('JOTSY_ALIYUN_CLIENT_ID', ' abc'),
      ('JOTSY_BAIDU_APP_DIR', 'a/b'),
    ]) {
      expect(
        () => readCloudBackupKeys(<String, String>{...valid, name: value}),
        throwsA(
          isA<CloudBackupKeysException>()
              .having((e) => e.message, 'message', contains(name))
              .having((e) => e.message, 'message', isNot(contains(value))),
        ),
        reason: name,
      );
    }
  });

  test('pairs must be configured together', () {
    expect(
      () => readCloudBackupKeys(<String, String>{
        ...valid,
        'JOTSY_BAIDU_SECRET_KEY': '',
      }),
      throwsA(isA<CloudBackupKeysException>()),
    );
  });
}
