import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/file_open_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_image_fallback.dart';
import 'package:path/path.dart' as p;

import '../../../support/expressive_test_theme.dart';

const List<int> heicBytes = [
  0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, // size, "ftyp"
  0x68, 0x65, 0x69, 0x63, 0, 0, 0, 0, // "heic", minor version
  0x6D, 0x69, 0x66, 0x31, 0x68, 0x65, 0x69, 0x63, // "mif1", "heic"
];

class _RecordingOpenService extends FileOpenService {
  final opened = <String>[];

  @override
  Future<FileOpenFailure?> open(String source) async {
    opened.add(source);
    return null;
  }
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_image_fallback_test_');
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await root.delete(recursive: true);
  });

  Future<void> pumpFallback(
    WidgetTester tester,
    String source,
    FileOpenService service,
    Brightness brightness,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(brightness),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DiaryImageFallback(source: source, openService: service),
        ),
      ),
    );
    // 读文件头是真实 IO（open → read → close），每一步都要先在 runAsync
    // 里让真实事件循环完成，再 pump 冲掉测试 zone 里排着的后续。
    for (var step = 0; step < 6; step++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'desktop explains a HEIC photo and opens it elsewhere ($brightness)',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        final heic = File(p.join(root.path, 'IMG_1.HEIC'));
        await tester.runAsync(() => heic.writeAsBytes(heicBytes));
        final service = _RecordingOpenService();

        await pumpFallback(tester, heic.path, service, brightness);

        expect(find.text('这台电脑显示不了 HEIC 格式的图片'), findsOneWidget);
        expect(find.textContaining('在手机上打开 Jotsy'), findsOneWidget);
        expect(find.text('图片文件不存在或无法加载'), findsNothing);
        await tester.tap(find.text('用其他应用打开'));
        await tester.pump();
        expect(service.opened, [heic.path]);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  testWidgets('desktop keeps the generic message for missing files', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await pumpFallback(
      tester,
      p.join(root.path, 'gone.heic'),
      _RecordingOpenService(),
      Brightness.light,
    );
    expect(find.text('图片文件不存在或无法加载'), findsOneWidget);
    expect(find.text('用其他应用打开'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('phones keep the generic message even for HEIC files', (
    tester,
  ) async {
    final heic = File(p.join(root.path, 'IMG_2.heic'));
    await tester.runAsync(() => heic.writeAsBytes(heicBytes));
    await pumpFallback(
      tester,
      heic.path,
      _RecordingOpenService(),
      Brightness.light,
    );
    expect(find.text('图片文件不存在或无法加载'), findsOneWidget);
    expect(find.text('用其他应用打开'), findsNothing);
  });
}
