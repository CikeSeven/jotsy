import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_network.dart';

LanSyncInterfaceInfo _iface(String name, List<String> addresses) =>
    LanSyncInterfaceInfo(name, [for (final a in addresses) InternetAddress(a)]);

List<String> _rank(List<LanSyncInterfaceInfo> interfaces) => [
  for (final address in rankLanSyncAddresses(interfaces)) address.address,
];

/// 在默认测试信使上挂一个假通道，测试结束时摘掉。
void _mockChannel(
  MethodChannel channel,
  Future<Object?> Function(MethodCall call) handler,
) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, handler);
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('rankLanSyncAddresses', () {
    test('只保留私有 IPv4', () {
      expect(
        _rank([
          _iface('wlan0', [
            '192.168.1.20',
            '8.8.8.8',
            '172.15.0.1',
            '172.16.0.1',
            '172.31.255.1',
            '172.32.0.1',
            '10.0.0.5',
            '169.254.3.4',
            '127.0.0.1',
          ]),
        ]),
        ['192.168.1.20', '172.16.0.1', '172.31.255.1', '10.0.0.5'],
      );
    });

    test('Wi-Fi / 以太网在前、VPN 在后、虚拟网桥与蜂窝排除', () {
      expect(
        _rank([
          _iface('tun0', ['10.8.0.2']),
          _iface('docker0', ['172.17.0.1']),
          _iface('br-1a2b3c', ['172.18.0.1']),
          _iface('veth12ab', ['172.19.0.1']),
          _iface('rmnet_data0', ['10.120.3.4']),
          _iface('usb0', ['192.168.42.129']),
          _iface('enp3s0', ['192.168.1.10']),
          _iface('wlan0', ['192.168.1.11']),
          _iface('ztabcdef', ['10.147.17.5']),
        ]),
        [
          '192.168.1.10',
          '192.168.1.11',
          '192.168.42.129',
          '10.8.0.2',
          '10.147.17.5',
        ],
      );
    });

    test('认得 Windows 的友好名，排除 Hyper-V 与 VMware 虚拟网卡', () {
      expect(
        _rank([
          _iface('vEthernet (WSL)', ['172.20.0.1']),
          _iface('VMware Network Adapter VMnet8', ['192.168.80.1']),
          _iface('以太网 2', ['192.168.0.8']),
          _iface('Wi-Fi', ['192.168.0.9']),
          _iface('OpenVPN TAP-Windows6', ['10.9.0.2']),
        ]),
        ['192.168.0.8', '192.168.0.9', '10.9.0.2'],
      );
    });

    test('重复地址只留第一次出现', () {
      expect(
        _rank([
          _iface('wlan0', ['192.168.1.11']),
          _iface('eth0', ['192.168.1.11']),
        ]),
        ['192.168.1.11'],
      );
    });

    test('IPv6 不算私有 IPv4', () {
      expect(isLanSyncPrivateIPv4(InternetAddress('fd00::1')), isFalse);
    });

    test('真实接口列表不抛错', () async {
      final addresses = await lanSyncLocalAddresses();
      expect(addresses.every(isLanSyncPrivateIPv4), isTrue);
    });
  });

  group('设备名', () {
    test('主机名去掉域后缀并截断', () {
      expect(
        cleanLanSyncHostname('Johns-MacBook-Pro.local'),
        'Johns-MacBook-Pro',
      );
      expect(cleanLanSyncHostname('  pc.corp.example  '), 'pc');
      expect(
        cleanLanSyncHostname('a' * 60).length,
        kLanSyncDeviceNameMaxLength,
      );
    });

    test('桌面取主机名，取不到时用平台名', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final channel = LanSyncNativeChannel(isAndroid: false);
      expect(
        await lanSyncDefaultDeviceName(
          channel: channel,
          hostname: () => 'desk.lan',
        ),
        'desk',
      );
      expect(
        await lanSyncDefaultDeviceName(channel: channel, hostname: () => ''),
        'Linux',
      );
      expect(
        await lanSyncDefaultDeviceName(
          channel: channel,
          hostname: () => throw const OSError('no host'),
        ),
        'Linux',
      );
    });

    test('Android 取原生设备名，取不到时用平台名', () async {
      const methodChannel = MethodChannel('test/lan_sync_name');
      String? nativeName = '  小米 14  ';
      _mockChannel(methodChannel, (call) async {
        return call.method == 'deviceName' ? nativeName : null;
      });
      final channel = LanSyncNativeChannel(
        channel: methodChannel,
        isAndroid: true,
      );
      expect(await lanSyncDefaultDeviceName(channel: channel), '小米 14');
      nativeName = null;
      expect(await lanSyncDefaultDeviceName(channel: channel), 'Android');
    });
  });

  group('LanSyncNativeChannel', () {
    test('非 Android 时不调用通道', () async {
      const methodChannel = MethodChannel('test/lan_sync_off');
      var calls = 0;
      _mockChannel(methodChannel, (call) async {
        calls++;
        return true;
      });
      final channel = LanSyncNativeChannel(
        channel: methodChannel,
        isAndroid: false,
      );
      expect(channel.isAvailable, isFalse);
      expect(await channel.acquireMulticastLock(), isFalse);
      await channel.releaseMulticastLock();
      expect(await channel.deviceName(), isNull);
      expect(await channel.noBackupDirectory(), isNull);
      expect(calls, 0);
    });

    test('宿主机上的默认实例是空操作', () async {
      // 测试在桌面宿主机上运行，运行时 Platform 不是 Android。
      final channel = LanSyncNativeChannel();
      expect(channel.isAvailable, isFalse);
      expect(await channel.acquireMulticastLock(), isFalse);
      expect(await channel.noBackupDirectory(), isNull);
    });

    test('Android 上通道缺失或原生报错当作不可用', () async {
      final missing = LanSyncNativeChannel(
        channel: const MethodChannel('test/lan_sync_missing'),
        isAndroid: true,
      );
      expect(await missing.acquireMulticastLock(), isFalse);
      await missing.releaseMulticastLock();
      expect(await missing.deviceName(), isNull);
      expect(await missing.noBackupDirectory(), isNull);

      const failing = MethodChannel('test/lan_sync_error');
      _mockChannel(failing, (call) async {
        throw PlatformException(code: 'boom');
      });
      final erroring = LanSyncNativeChannel(channel: failing, isAndroid: true);
      expect(await erroring.acquireMulticastLock(), isFalse);
      expect(await erroring.noBackupDirectory(), isNull);
    });

    test('Android 上返回原生结果', () async {
      const methodChannel = MethodChannel('test/lan_sync_on');
      final calls = <String>[];
      _mockChannel(methodChannel, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'acquireMulticastLock' => true,
          'noBackupDirectory' => '/data/user/0/com.jotsy.diary/no_backup',
          _ => null,
        };
      });
      final channel = LanSyncNativeChannel(
        channel: methodChannel,
        isAndroid: true,
      );
      expect(await channel.acquireMulticastLock(), isTrue);
      await channel.releaseMulticastLock();
      expect(
        await channel.noBackupDirectory(),
        '/data/user/0/com.jotsy.diary/no_backup',
      );
      expect(calls, [
        'acquireMulticastLock',
        'releaseMulticastLock',
        'noBackupDirectory',
      ]);
    });
  });
}
