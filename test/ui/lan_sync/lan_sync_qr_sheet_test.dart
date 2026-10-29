import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_qr_payload.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/providers/diary_preview_style_provider.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_qr_matrix.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_qr_ticket.dart';
import 'package:node_diary/ui/lan_sync/widgets/lan_sync_qr_board.dart';
import 'package:node_diary/ui/lan_sync/widgets/lan_sync_qr_painter.dart';
import 'package:node_diary/ui/lan_sync/widgets/lan_sync_qr_sheet.dart';
import 'package:qr/qr.dart';

import '../../support/expressive_test_theme.dart';
import '../../support/fake_lan_sync_controller.dart';
import 'lan_sync_test_harness.dart';

/// 真实大小的载荷：UUID 设备 id、完整指纹、令牌、一个地址与设备名。
String _realisticPayload() => LanSyncQrPayload(
  hosts: <String>['192.168.1.23'],
  port: 47562,
  deviceId: 'b7f3c2a1-9d84-4e6f-a0c5-1e2d3f4a5b6c',
  fingerprint: List<String>.filled(64, 'a').join(),
  token: List<String>.filled(22, 'Q').join(),
  name: 'Pixel 9',
).encode();

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Future<void> _pumpSheet(
  WidgetTester tester,
  FakeLanSyncController controller, {
  required DateTime Function() clock,
  Brightness brightness = Brightness.light,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appThemeSeedColorProvider.overrideWithValue(const Color(0xff1e6586)),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(brightness),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: LanSyncQrSheet(controller: controller, clock: clock),
        ),
      ),
    ),
  );
  await tester.pump();
}

LanSyncQrPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (Widget widget) =>
          widget is CustomPaint && widget.painter is LanSyncQrPainter,
    ),
  );
  return paint.painter! as LanSyncQrPainter;
}

/// 底板是 LanSyncQrBoard 里最外层的 Container。
BoxDecoration _boardDecoration(WidgetTester tester) {
  final board = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(LanSyncQrBoard),
          matching: find.byType(Container),
        )
        .first,
  );
  return board.decoration! as BoxDecoration;
}

Color _boardColor(WidgetTester tester) => _boardDecoration(tester).color!;

void main() {
  group('LanSyncQrMatrix', () {
    test('encodes at level Q with the smallest version that fits', () {
      final payload = _realisticPayload();
      final matrix = LanSyncQrMatrix.encode(payload);
      final reference = QrCode.fromData(
        data: payload,
        errorCorrectLevel: QrErrorCorrectLevel.Q,
      );
      expect(matrix.typeNumber, reference.typeNumber);
      expect(matrix.moduleCount, matrix.typeNumber * 4 + 17);
      // 小一版放不下：确实是 Q 级的最小版本。
      expect(
        () => QrImage(
          QrCode(matrix.typeNumber - 1, QrErrorCorrectLevel.Q)
            ..addData(payload),
        ),
        throwsA(anything),
      );
    });

    test('clears an odd centre square that covers the brand block', () {
      final payload = _realisticPayload();
      final matrix = LanSyncQrMatrix.encode(payload);
      final image = QrImage(
        QrCode.fromData(
          data: payload,
          errorCorrectLevel: QrErrorCorrectLevel.Q,
        ),
      );
      final count = matrix.moduleCount;
      final module = 216 / count;
      expect(matrix.cleared.isOdd, isTrue);
      expect(matrix.cleared, greaterThanOrEqualTo(7));
      expect(matrix.cleared * module, greaterThanOrEqualTo(40 + module));
      // 挖掉的模块远低于 Q 级约 25% 的纠错余量（不到它的三分之一）。
      expect(
        matrix.cleared * matrix.cleared / (count * count),
        lessThan(0.25 / 3),
      );

      for (var row = 0; row < count; row++) {
        for (var col = 0; col < count; col++) {
          if (matrix.isCleared(row, col)) {
            expect(matrix.isDark(row, col), isFalse);
          } else {
            expect(matrix.isDark(row, col), image.isDark(row, col));
          }
        }
      }
      expect(matrix.isFinder(0, 0), isTrue);
      expect(matrix.isFinder(count - 1, count - 1), isFalse);
      expect(matrix.isCleared(count ~/ 2, count ~/ 2), isTrue);
    });

    test('modules stay large enough to scan on both board sizes', () {
      final payload = _realisticPayload();
      final narrow = LanSyncQrMatrix.encode(
        payload,
        codeExtent: LanSyncQrBoardMetrics.compact.codeExtent,
      );
      final wide = LanSyncQrMatrix.encode(
        payload,
        codeExtent: LanSyncQrBoardMetrics.wide.codeExtent,
      );
      expect(
        LanSyncQrBoardMetrics.compact.codeExtent / narrow.moduleCount,
        greaterThanOrEqualTo(2.6),
      );
      expect(
        LanSyncQrBoardMetrics.wide.codeExtent / wide.moduleCount,
        greaterThanOrEqualTo(3.3),
      );
      // 宽档的挖空按 272dp 换算，仍盖得住 40dp 的品牌块。
      final module = LanSyncQrBoardMetrics.wide.codeExtent / wide.moduleCount;
      expect(wide.cleared * module, greaterThanOrEqualTo(40 + module));
      expect(wide.cleared.isOdd, isTrue);
    });
  });

  testWidgets('issues a ticket, counts down and revokes on close', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 29, 12);
    final controller = FakeLanSyncController()..ticketClock = () => now;
    await _pumpSheet(tester, controller, clock: () => now);

    expect(controller.calls, <String>['issueQrTicket']);
    expect(find.text('2:00 后换一张新码'), findsOneWidget);
    expect(find.text('扫码配对'), findsOneWidget);
    expect(find.text('Pixel 9 · 192.168.1.23:47562'), findsOneWidget);
    expect(find.text('二维码只能用一次，扫过即失效'), findsOneWidget);
    expect(find.bySemanticsLabel('配对二维码'), findsOneWidget);

    now = now.add(const Duration(seconds: 36));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1:24 后换一张新码'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    expect(controller.calls.last, 'revokeQrTicket');
  });

  testWidgets('re-issues the code at expiry when the controller has not', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 29, 12);
    final controller = FakeLanSyncController()..ticketClock = () => now;
    await _pumpSheet(tester, controller, clock: () => now);
    final first = _painter(tester).matrix;

    now = now.add(const Duration(minutes: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(controller.qrIssued, 2);
    expect(find.text('2:00 后换一张新码'), findsOneWidget);
    expect(identical(_painter(tester).matrix, first), isFalse);

    // 下一秒不再重复签发。
    await tester.pump(const Duration(seconds: 1));
    expect(controller.qrIssued, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('follows a code the controller swapped in', (tester) async {
    var now = DateTime(2026, 10, 29, 12);
    final controller = FakeLanSyncController()..ticketClock = () => now;
    await _pumpSheet(tester, controller, clock: () => now);

    now = now.add(const Duration(seconds: 50));
    controller.qrTicketNotifier.value = LanSyncQrTicket(
      payload: 'jotsy-lan:v1:swapped',
      issuedAt: now,
      expiresAt: now.add(const Duration(minutes: 2)),
    );
    await tester.pump();
    expect(find.text('2:00 后换一张新码'), findsOneWidget);
    expect(controller.qrIssued, 1);
    await tester.pumpWidget(const SizedBox());
  });

  for (final brightness in Brightness.values) {
    testWidgets('paints a dark-on-light code in ${brightness.name} theme', (
      tester,
    ) async {
      final now = DateTime(2026, 10, 29, 12);
      final controller = FakeLanSyncController()..ticketClock = () => now;
      await _pumpSheet(
        tester,
        controller,
        clock: () => now,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      final painter = _painter(tester);
      final board = _boardColor(tester);
      // ML Kit 不识别反色码：底板必须比圆点亮，且对比度不低于 7:1。
      expect(
        board.computeLuminance(),
        greaterThan(painter.dotColor.computeLuminance()),
      );
      expect(_contrast(board, painter.dotColor), greaterThanOrEqualTo(7));
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('a wide sheet enlarges the board, a narrow one keeps 264', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 29, 12);
    final controller = FakeLanSyncController()..ticketClock = () => now;
    // 内容区 = 宽度 − 左右各 24：600 → 552（≥ 480），500 → 452（< 480）。
    await _pumpSheet(tester, controller, clock: () => now, width: 600);
    expect(tester.getSize(find.byType(LanSyncQrBoard)), const Size(320, 320));
    expect(_boardDecoration(tester).borderRadius, BorderRadius.circular(36));
    expect(
      tester.getSize(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is CustomPaint && widget.painter is LanSyncQrPainter,
        ),
      ),
      const Size(272, 272),
    );
    await tester.pumpWidget(const SizedBox());

    await _pumpSheet(tester, controller, clock: () => now, width: 500);
    expect(tester.getSize(find.byType(LanSyncQrBoard)), const Size(264, 264));
    expect(_boardDecoration(tester).borderRadius, BorderRadius.circular(32));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('“改用核对码配对” closes the sheet and explains what to do', (
    tester,
  ) async {
    final controller = FakeLanSyncController();
    await pumpLanSyncPage(tester, controller);
    await tester.tap(find.text('显示二维码'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('改用核对码配对'));
    await tester.pumpAndSettle();
    expect(find.byType(LanSyncQrSheet), findsNothing);
    expect(controller.calls, contains('revokeQrTicket'));
    expect(find.text('在另一台设备的「附近的设备」里找到「Pixel 9」并点「配对」'), findsOneWidget);
  });
}
