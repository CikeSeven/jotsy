import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_network.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_state_directory.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android 上放在 noBackupFilesDir/lan_sync 并建好目录', () async {
    // flutter_test 默认目标平台即 Android。
    final root = await Directory.systemTemp.createTemp('lan_sync_state_');
    addTearDown(() => root.delete(recursive: true));
    const methodChannel = MethodChannel('test/lan_sync_state');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      return call.method == 'noBackupDirectory' ? root.path : null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(methodChannel, null));

    final directory = await lanSyncStateDirectory(
      channel: LanSyncNativeChannel(channel: methodChannel, isAndroid: true),
    );
    expect(directory.path, p.join(root.path, 'lan_sync'));
    expect(directory.existsSync(), isTrue);
  });
}
