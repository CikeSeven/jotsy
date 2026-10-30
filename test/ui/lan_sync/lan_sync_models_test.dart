import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_address_input.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_platform.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_session_view.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_view_state.dart';
import 'package:node_diary/ui/lan_sync/widgets/lan_sync_labels.dart';
import 'package:node_diary/ui/lan_sync/widgets/m3e_cookie_shape.dart';

import 'lan_sync_test_harness.dart';

void main() {
  group('manual address input', () {
    test('accepts IPv4, IPv6 and host names', () {
      expect(normalizeLanSyncHost(' 192.168.1.5 '), '192.168.1.5');
      expect(normalizeLanSyncHost('[fe80::1]'), 'fe80::1');
      expect(normalizeLanSyncHost('My-PC.local'), 'my-pc.local');
    });

    test('rejects incomplete, out-of-range or malformed hosts', () {
      for (final bad in <String>[
        '',
        '192.168.1',
        '192.168.1.256',
        '192.168.01.5',
        '192.168.1.5:24562',
        '-pc',
        'a b',
      ]) {
        expect(normalizeLanSyncHost(bad), isNull, reason: bad);
      }
    });

    test('splits pasted host:port, leaves bare hosts alone', () {
      expect(splitLanSyncHostPort(' 192.168.1.5:38457 '), (
        host: '192.168.1.5',
        port: 38457,
      ));
      expect(splitLanSyncHostPort('My-PC.local:24562'), (
        host: 'my-pc.local',
        port: 24562,
      ));
      expect(splitLanSyncHostPort('[fe80::1]:24562'), (
        host: 'fe80::1',
        port: 24562,
      ));
      for (final keep in <String>[
        '192.168.1.5',
        'fe80::1',
        '192.168.1.5:',
        '192.168.1.5:70000',
        '192.168.1:24562',
        ':24562',
      ]) {
        expect(splitLanSyncHostPort(keep), isNull, reason: keep);
      }
    });

    test('ports must be 1 to 65535', () {
      expect(parseLanSyncPort('24562'), 24562);
      expect(parseLanSyncPort('0'), isNull);
      expect(parseLanSyncPort('65536'), isNull);
      expect(parseLanSyncPort('12a'), isNull);
    });
  });

  test('platform names fall back to unknown', () {
    expect(LanSyncPlatform.fromName('Linux'), LanSyncPlatform.linux);
    expect(LanSyncPlatform.fromName('fuchsia'), LanSyncPlatform.unknown);
    expect(LanSyncPlatform.fromName(null), LanSyncPlatform.unknown);
  });

  test('view state compares by value and derives session and attention', () {
    final a = LanSyncViewState(
      local: lanSyncTestLocal,
      peers: <LanSyncPeerView>[lanSyncTestPeer(lastSyncAt: lanSyncTestNow)],
    );
    final b = LanSyncViewState(
      local: lanSyncTestLocal,
      peers: <LanSyncPeerView>[lanSyncTestPeer(lastSyncAt: lanSyncTestNow)],
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.hasActiveSession, isFalse);
    expect(a.lastSyncAt, lanSyncTestNow);

    final syncing = a.copyWith(
      peers: <LanSyncPeerView>[
        lanSyncTestPeer(
          needsAttention: true,
          session: const LanSyncSessionView(
            peerId: 'peer-1',
            stage: LanSyncSessionStage.merging,
          ),
        ),
      ],
    );
    expect(syncing, isNot(a));
    expect(syncing.hasActiveSession, isTrue);
    expect(syncing.needsAttention, isTrue);
  });

  test('peer display name prefers a non-blank alias', () {
    final peer = lanSyncTestPeer();
    expect(peer.copyWith(alias: () => '  ').displayName, 'ThinkPad');
    expect(peer.copyWith(alias: () => '书房').displayName, '书房');
  });

  test('relative time labels reuse the app wording', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    final now = lanSyncTestNow;
    expect(lanSyncRelativeTime(l10n, now, now), '刚刚');
    expect(
      lanSyncRelativeTime(l10n, now.subtract(const Duration(hours: 2)), now),
      '2小时前',
    );
    // 对方时钟比本机快：按刚刚处理，不出现负数。
    expect(
      lanSyncRelativeTime(l10n, now.add(const Duration(minutes: 5)), now),
      '刚刚',
    );
    expect(lanSyncLastSyncLabel(l10n, null, now), '还没有同步过');
  });

  test('cookie outline stays inside its box with the first lobe on top', () {
    const rect = Rect.fromLTWH(0, 0, 88, 88);
    final bounds = m3eCookiePath(rect, lobes: 9).getBounds();
    expect(bounds.top, closeTo(0, 0.01));
    expect(bounds.left, greaterThanOrEqualTo(-0.01));
    expect(bounds.right, lessThanOrEqualTo(88.01));
    expect(bounds.bottom, lessThanOrEqualTo(88.01));
  });
}
