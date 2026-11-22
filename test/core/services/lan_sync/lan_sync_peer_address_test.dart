import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_messages.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_service.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_session_protocol.dart';

import 'lan_sync_e2e_harness.dart';
import 'lan_sync_fake_timers.dart';
import 'lan_sync_session_harness.dart';

/// 对方的地址（docs/lan_sync.md §9“对方的地址”）：对方换了地址、本机又收
/// 不到它的信标时，对方连进来一次（同步成功或被拒绝都算）本机就记下它
/// 现在的地址与服务端口，之后本机发起也连得上。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('sync.hello 的服务端口', () {
    LanSyncSessionHello hello({int? port}) => LanSyncSessionHello(
      formatVersion: 1,
      appVersion: 'test',
      entities: const {'diary'},
      syncSettings: false,
      restoredPending: false,
      serverPort: port,
    );

    test('带上端口时原样解析回来', () {
      final parsed = LanSyncSessionHello.parse(hello(port: 24562).toMessage());
      expect(parsed.serverPort, 24562);
    });

    test('没在监听时不带这个字段；旧版本不带时解析为 null', () {
      final message = hello().toMessage();
      expect(message.fields.containsKey('port'), isFalse);
      expect(LanSyncSessionHello.parse(message).serverPort, isNull);
    });

    test('端口越界或类型不对：按格式错误拒绝', () {
      for (final bad in <Object>[0, 65536, -1, '24562']) {
        final message = LanSyncMessage(LanSyncSessionMessages.hello, {
          ...hello().toMessage().fields,
          'port': bad,
        });
        expect(
          () => LanSyncSessionHello.parse(message),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });
  });

  group('对方连进来时更新对方的地址', () {
    late FakeTimers timers;
    final devices = <E2eDevice>[];

    setUp(() {
      EditingSessionRegistry.instance.debugReset();
      timers = FakeTimers();
    });

    tearDown(() async {
      for (final d in devices.reversed) {
        await d.dispose();
      }
      devices.clear();
    });

    /// 配对好的手机与电脑。手机收不到电脑的信标（电脑不可被发现、路由器
    /// 不转发广播等），而且手机记下的电脑地址已经过时：电脑原来在
    /// 192.0.2.10:24562，现在在回环上的另一个端口。
    Future<(E2eDevice, E2eDevice)> staleAddress() async {
      final phone = await E2eDevice.create('phone', timers);
      final pc = await E2eDevice.create('pc', timers);
      devices.addAll([phone, pc]);
      await pairDevices(phone, pc);
      // 按地址连接时改道到电脑现在的端口，让手机记下那个旧地址。
      phone.redirectOutgoing = ('127.0.0.1', pc.port!);
      await phone.service.connectManual('192.0.2.10', 24562);
      phone.redirectOutgoing = null;
      // 电脑这一侧的会话也收完尾，之后才能由它发起。
      await pc.event<LanSyncSessionEnded>();
      phone.discovery.lose(pc.id);
      final device = phone.peerState(pc)!;
      expect(device.online, isFalse);
      expect(
        (device.device.lastHost, device.device.lastPort),
        ('192.0.2.10', 24562),
      );
      return (phone, pc);
    }

    Future<void> expectPhoneKnowsPc(E2eDevice phone, E2eDevice pc) async {
      await waitUntil(() => phone.peerState(pc)!.device.lastPort == pc.port);
      final device = phone.peerState(pc)!;
      expect(device.device.lastHost, '127.0.0.1');
      expect(device.address, '127.0.0.1');
      expect(device.online, isFalse);
    }

    test('电脑连进来同步之后，手机按电脑现在的地址发起也连得上', () async {
      final (phone, pc) = await staleAddress();
      await seedDiary(pc.data.db, 'pc1', title: 'PC1');
      final inbound = await pc.service.syncNow(phone.id);
      expect(inbound!.failure, isNull);
      await expectPhoneKnowsPc(phone, pc);

      await seedDiary(pc.data.db, 'pc2', title: 'PC2');
      final outbound = await phone.service.syncNow(pc.id);
      expect(outbound!.failure, isNull);
      expect(await diaryIds(phone.data), {'pc1', 'pc2'});
    });

    test('手机正在编辑、以 busy 拒绝电脑的同步：同样记下电脑现在的地址', () async {
      final (phone, pc) = await staleAddress();
      phone.editing = true;
      final inbound = await pc.service.syncNow(phone.id);
      expect(inbound!.failure, LanSyncFailure.busy);
      await expectPhoneKnowsPc(phone, pc);

      phone.editing = false;
      final outbound = await phone.service.syncNow(pc.id);
      expect(outbound!.failure, isNull);
    });
  });
}
