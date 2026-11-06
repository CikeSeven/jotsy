import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 验证身份只经 `IdentityVerifier`（`lib/ui/app_lock/`）：它按全局的验证
/// 方式走系统验证或应用密码（数字或图案）。别处直接读
/// `deviceAuthServiceProvider`、调用 `DeviceAuthService.authenticate` 或引入
/// local_auth，切到应用密码后仍会冒出系统验证，Linux 上更是直接打不开
/// （docs/rules/app_lock.md）。
void main() {
  const allowed = <String>[
    'lib/ui/app_lock/',
    'lib/core/services/device_auth_service.dart',
  ];
  final forbidden = <String, RegExp>{
    'deviceAuthServiceProvider': RegExp(r'\bdeviceAuthServiceProvider\b'),
    'DeviceAuthService': RegExp(r'\bDeviceAuthService\b'),
    'local_auth': RegExp(r'package:local_auth'),
  };
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .where((File file) => !file.path.endsWith('.g.dart'))
      .where((File file) {
        final path = file.path.replaceAll(r'\', '/');
        return !allowed.any(path.startsWith);
      })
      .toList();

  test('identity checks outside app_lock go through IdentityVerifier', () {
    expect(files, isNotEmpty);
    final offenders = <String>[];
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // 注释里提到类名不算违规。
        if (line.trimLeft().startsWith('//')) continue;
        for (final entry in forbidden.entries) {
          if (entry.value.hasMatch(line)) {
            offenders.add('${file.path}:${i + 1} uses ${entry.key}');
          }
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
