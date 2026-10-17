import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_share_channel.dart';
import 'package:node_diary/ui/diaries/controllers/diary_share_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_share_target.dart';
import 'package:path/path.dart' as p;

class _FakeChannel extends DiaryShareChannel {
  _FakeChannel({this.installed = const <String>{}, this.launches = true});

  final Set<String> installed;
  final bool launches;
  final List<({String packageName, String? text, List<String> images})> calls =
      [];

  @override
  Future<Set<String>> installedPackages(Iterable<String> packageNames) async =>
      packageNames.where(installed.contains).toSet();

  @override
  Future<bool> shareToPackage({
    required String packageName,
    String? text,
    List<String> imagePaths = const <String>[],
    String? chooserTitle,
  }) async {
    // 拉起时目标应用读取图片，此刻暂存文件必须存在。
    for (final path in imagePaths) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
    calls.add((packageName: packageName, text: text, images: imagePaths));
    return launches;
  }
}

void main() {
  late Directory cache;
  late Directory media;
  late List<String> clipboard;
  late List<({List<String> images, String? text})> systemShares;

  setUp(() async {
    cache = await Directory.systemTemp.createTemp('share_cache_');
    media = await Directory.systemTemp.createTemp('share_media_');
    clipboard = <String>[];
    systemShares = [];
  });

  tearDown(() async {
    await cache.delete(recursive: true);
    await media.delete(recursive: true);
  });

  Future<String> image(String name) async {
    final file = File(p.join(media.path, name));
    await file.writeAsBytes(<int>[1, 2, 3]);
    return file.path;
  }

  DiaryShareController controller(_FakeChannel channel) {
    return DiaryShareController(
      channel: channel,
      cacheDirectory: () async => cache,
      writeClipboard: (String text) async => clipboard.add(text),
      systemShare: ({required List<String> imagePaths, String? text}) async =>
          systemShares.add((images: imagePaths, text: text)),
    );
  }

  test(
    'sharing images to Weibo copies the text and sends staged copies',
    () async {
      final channel = _FakeChannel();
      final sources = <String>[await image('IMG 1.jpg'), await image('b.PNG')];

      final result = await controller(
        channel,
      ).share(DiaryShareTarget.weibo, text: '  春日小记\n#旅行#  ', images: sources);

      expect(result.outcome, DiaryShareOutcome.shared);
      expect(result.textCopied, isTrue);
      expect(clipboard, <String>['春日小记\n#旅行#']);
      final call = channel.calls.single;
      expect(call.packageName, 'com.sina.weibo');
      // 带图时文字只走剪贴板，避免目标应用读到 EXTRA_TEXT 后重复一遍。
      expect(call.text, isNull);
      expect(call.images.map(p.basename), <String>[
        'jotsy_01.jpg',
        'jotsy_02.png',
      ]);
      for (final path in call.images) {
        expect(
          p.isWithin(
            p.join(cache.path, DiaryShareController.stagingDirectoryName),
            path,
          ),
          isTrue,
        );
      }
    },
  );

  test(
    'text-only shares go straight to the app without the clipboard',
    () async {
      final channel = _FakeChannel();
      final result = await controller(
        channel,
      ).share(DiaryShareTarget.wechat, text: '只有文字', images: const []);

      expect(result.outcome, DiaryShareOutcome.shared);
      expect(result.textCopied, isFalse);
      expect(clipboard, isEmpty);
      expect(channel.calls.single.text, '只有文字');
      expect(channel.calls.single.images, isEmpty);
    },
  );

  test('caps app targets at nine images and reports unreadable ones', () async {
    final channel = _FakeChannel();
    final sources = <String>[
      for (var i = 0; i < 10; i++) await image('$i.jpg'),
      p.join(media.path, 'deleted.jpg'),
    ];
    // 第 2 张已被删除：在上限之内，计入 missing；第 10、11 张超出上限。
    await File(sources[1]).delete();

    final result = await controller(
      channel,
    ).share(DiaryShareTarget.qq, text: '', images: sources);

    expect(result.outcome, DiaryShareOutcome.shared);
    expect(result.trimmedImages, 2);
    expect(result.missingImages, 1);
    expect(channel.calls.single.images, hasLength(8));
    expect(clipboard, isEmpty);
  });

  test('stages data URI images and clears the previous staging run', () async {
    final channel = _FakeChannel();
    final share = controller(channel);
    await share.share(
      DiaryShareTarget.weibo,
      text: '',
      images: <String>[await image('first.jpg')],
    );
    final firstRun = channel.calls.single.images.single;

    await share.share(
      DiaryShareTarget.weibo,
      text: '',
      images: <String>[
        'data:image/png;base64,${base64Encode(<int>[7, 8])}',
      ],
    );

    final staged = File(channel.calls.last.images.single);
    expect(p.basename(staged.path), 'jotsy_01.png');
    expect(await staged.readAsBytes(), <int>[7, 8]);
    expect(File(firstRun).existsSync(), isFalse);
  });

  test(
    'reports nothing to share when no image survives and text is empty',
    () async {
      final channel = _FakeChannel();
      final result = await controller(channel).share(
        DiaryShareTarget.weibo,
        text: ' ',
        images: <String>[p.join(media.path, 'missing.jpg')],
      );

      expect(result.outcome, DiaryShareOutcome.nothingToShare);
      expect(result.missingImages, 1);
      expect(channel.calls, isEmpty);
    },
  );

  test('Xiaohongshu refuses a text-only share', () async {
    final channel = _FakeChannel();
    final result = await controller(
      channel,
    ).share(DiaryShareTarget.xiaohongshu, text: '文字', images: const []);

    expect(result.outcome, DiaryShareOutcome.nothingToShare);
    expect(channel.calls, isEmpty);
    expect(clipboard, isEmpty);
  });

  test('reports an app that cannot take the share', () async {
    final channel = _FakeChannel(launches: false);
    final result = await controller(channel).share(
      DiaryShareTarget.weibo,
      text: '文字',
      images: <String>[await image('a.jpg')],
    );

    expect(result.outcome, DiaryShareOutcome.appUnavailable);
    expect(result.textCopied, isTrue);
  });

  test('the system sheet gets both text and every selected image', () async {
    final channel = _FakeChannel();
    final sources = <String>[
      for (var i = 0; i < 12; i++) await image('$i.jpg'),
    ];
    final result = await controller(
      channel,
    ).share(DiaryShareTarget.system, text: '文字', images: sources);

    expect(result.outcome, DiaryShareOutcome.shared);
    expect(result.trimmedImages, 0);
    expect(systemShares.single.text, '文字');
    expect(systemShares.single.images, hasLength(12));
    expect(clipboard, <String>['文字']);
    expect(channel.calls, isEmpty);
  });

  test('lists only installed app targets', () async {
    final channel = _FakeChannel(
      installed: const <String>{'com.tencent.mm', 'com.example.other'},
    );
    expect(await controller(channel).availableTargets(), <DiaryShareTarget>{
      DiaryShareTarget.wechat,
    });
  });

  test('copying text trims it and ignores empty text', () async {
    final share = controller(_FakeChannel());
    expect((await share.copyText('  内容 ')).outcome, DiaryShareOutcome.copied);
    expect(
      (await share.copyText('  ')).outcome,
      DiaryShareOutcome.nothingToShare,
    );
    expect(clipboard, <String>['内容']);
  });
}
