import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_discovery.dart';

LanSyncBeacon _beacon({String name = '书房的电脑'}) => LanSyncBeacon(
  deviceId: '6f1c2b8e-1d2a-4e5f-9a0b-1c2d3e4f5a6b',
  name: name,
  platform: 'linux',
  port: 47562,
  fingerprint: '0123456789abcdef',
  formatVersion: 1,
);

List<int> _bytes(Map<String, Object?> json) => utf8.encode(jsonEncode(json));

void main() {
  test('信标编码后可原样解码', () {
    final beacon = _beacon();
    final decoded = LanSyncBeacon.decode(beacon.encode());
    expect(decoded, beacon);
    expect(jsonDecode(utf8.decode(beacon.encode())), {
      'j': 'jotsy-lan',
      'v': 1,
      'id': beacon.deviceId,
      'n': '书房的电脑',
      'p': 'linux',
      'port': 47562,
      'fp': '0123456789abcdef',
      'f': 1,
    });
  });

  test('过长的名称按字符截断且不切开代理对', () {
    final beacon = _beacon(name: '😀' * 100);
    expect(beacon.name.runes.length, 40);
    expect(LanSyncBeacon.decode(beacon.encode())!.name, beacon.name);
  });

  test('忽略未知的额外字段', () {
    final json = {..._beacon().toJson(), 'extra': true};
    expect(LanSyncBeacon.decode(_bytes(json)), _beacon());
  });

  group('拒绝不合规的包', () {
    final valid = _beacon().toJson();
    final cases = <String, Map<String, Object?>>{
      '魔数不对': {...valid, 'j': 'other-app'},
      '版本不对': {...valid, 'v': 2},
      '版本是字符串': {...valid, 'v': '1'},
      '缺少 id': {...valid}..remove('id'),
      '缺少名称': {...valid}..remove('n'),
      '名称为空白': {...valid, 'n': '   '},
      '缺少端口': {...valid}..remove('port'),
      '端口越界': {...valid, 'port': 70000},
      '端口为 0': {...valid, 'port': 0},
      '指纹长度不对': {...valid, 'fp': 'abcd'},
      '指纹含大写': {...valid, 'fp': '0123456789ABCDEF'},
      '平台含非法字符': {...valid, 'p': 'Linux OS'},
      '缺少格式版本': {...valid}..remove('f'),
      'id 含非法字符': {...valid, 'id': 'a b'},
    };
    for (final entry in cases.entries) {
      test(entry.key, () {
        expect(LanSyncBeacon.decode(_bytes(entry.value)), isNull);
      });
    }

    test('超过 1 KiB', () {
      final json = {...valid, 'pad': 'x' * 1100};
      expect(LanSyncBeacon.decode(_bytes(json)), isNull);
    });

    test('不是 JSON 或不是对象', () {
      expect(LanSyncBeacon.decode(utf8.encode('hello')), isNull);
      expect(LanSyncBeacon.decode(utf8.encode('[1,2]')), isNull);
      expect(LanSyncBeacon.decode(const [0xff, 0xfe, 0x00]), isNull);
      expect(LanSyncBeacon.decode(const []), isNull);
    });
  });
}
