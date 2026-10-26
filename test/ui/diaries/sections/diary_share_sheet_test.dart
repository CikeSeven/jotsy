import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_share_content.dart';
import 'package:node_diary/ui/diaries/models/diary_share_options.dart';
import 'package:node_diary/ui/diaries/models/diary_share_target.dart';
import 'package:node_diary/ui/diaries/sections/diary_share_sheet.dart';
import 'package:node_diary/ui/diaries/widgets/diary_share_widgets.dart';

import '../../../support/expressive_test_theme.dart';

DiaryShareContent _content({int imageCount = 2}) {
  return DiaryShareContent.parse(
    title: '春日小记',
    deltaOps: <dynamic>[
      <String, dynamic>{'insert': '今天去看花。\n'},
      for (var i = 0; i < imageCount; i++) ...<dynamic>[
        <String, dynamic>{
          'insert': <String, dynamic>{'image': '/missing/$i.jpg'},
        },
        <String, dynamic>{'insert': '\n'},
      ],
    ],
    cover: null,
    metadata: '{"context":{"weather":"晴"}}',
    tagNames: const <String>['旅行'],
    createdAt: DateTime(2026, 4, 3),
  );
}

/// 打开面板并返回一个读取结果的函数；面板关闭后结果才可用。
Future<DiaryShareRequest? Function()> _openSheet(
  WidgetTester tester, {
  required DiaryShareContent content,
  Set<DiaryShareTarget> installed = const <DiaryShareTarget>{},
  DiaryShareOptions options = DiaryShareOptions.defaults,
  List<DiaryShareOptions>? changes,
  Brightness brightness = Brightness.light,
}) async {
  DiaryShareRequest? result;
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(brightness),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                result = await showDiaryShareSheet(
                  context,
                  content: content,
                  initialOptions: options,
                  onOptionsChanged: (next) => changes?.add(next),
                  availableTargets: Future<Set<DiaryShareTarget>>.value(
                    installed,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => result;
}

void main() {
  testWidgets(
    'sharing to Weibo returns topic-style tags and the selected images',
    (tester) async {
      final result = await _openSheet(
        tester,
        content: _content(),
        installed: const <DiaryShareTarget>{DiaryShareTarget.weibo},
      );

      expect(find.text('分享日记'), findsOneWidget);
      // 没有地点、心情的日记不显示对应开关；预览用通用的 #标签 写法。
      expect(find.widgetWithText(FilterChip, '地点'), findsNothing);
      expect(find.widgetWithText(FilterChip, '心情与天气'), findsOneWidget);
      expect(find.textContaining('#旅行'), findsOneWidget);
      expect(find.text('已选 2/2 张'), findsOneWidget);
      // 未安装的应用不出现。
      expect(find.text('微信'), findsNothing);

      await tester.tap(find.bySemanticsLabel('第 1 张图片'));
      await tester.pumpAndSettle();
      expect(find.text('已选 1/2 张'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('微博'));
      await tester.pumpAndSettle();

      final request = result()!;
      expect(request.action, DiaryShareAction.target);
      expect(request.target, DiaryShareTarget.weibo);
      expect(request.images, <String>['/missing/1.jpg']);
      expect(request.text, endsWith('#旅行#'));
      expect(request.text, startsWith('春日小记\n\n今天去看花。'));
    },
  );

  testWidgets('turning images off hides the strip and disables Xiaohongshu', (
    tester,
  ) async {
    final changes = <DiaryShareOptions>[];
    final result = await _openSheet(
      tester,
      content: _content(),
      installed: const <DiaryShareTarget>{DiaryShareTarget.xiaohongshu},
      changes: changes,
    );

    expect(find.byType(DiaryShareImagePicker), findsOneWidget);
    expect(find.text('带图分享时文字会自动复制，在发布页粘贴即可。'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, '图片'));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryShareImagePicker), findsNothing);
    expect(changes.single.includeImages, isFalse);
    expect(find.text('小红书需要至少一张图片'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('小红书'));
    await tester.pumpAndSettle();
    // 置灰的按钮点了不关闭面板。
    expect(find.text('分享日记'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('复制文字'));
    await tester.pumpAndSettle();
    final request = result()!;
    expect(request.action, DiaryShareAction.copyText);
    expect(request.text, contains('#旅行'));
  });

  testWidgets('Moments and Qzone appear when installed and share images', (
    tester,
  ) async {
    final result = await _openSheet(
      tester,
      content: _content(),
      installed: const <DiaryShareTarget>{
        DiaryShareTarget.xiaohongshu,
        DiaryShareTarget.wechatMoments,
        DiaryShareTarget.qzone,
      },
    );

    expect(find.bySemanticsLabel('QQ空间'), findsOneWidget);

    // 两个目标都必须带图时，说明不再点名其中一个。
    await tester.tap(find.widgetWithText(FilterChip, '图片'));
    await tester.pumpAndSettle();
    expect(find.text('置灰的应用需要至少一张图片'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('朋友圈'));
    await tester.pumpAndSettle();
    expect(find.text('分享日记'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, '图片'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('朋友圈'));
    await tester.pumpAndSettle();
    final request = result()!;
    expect(request.target, DiaryShareTarget.wechatMoments);
    // 面板只负责挑选，按目标截断交给执行链路。
    expect(request.images, hasLength(2));
  });

  testWidgets('with nothing selected every target is disabled', (tester) async {
    await _openSheet(
      tester,
      content: _content(imageCount: 0),
      options: const DiaryShareOptions(
        includeTitle: false,
        includeBody: false,
        includeDate: false,
        includeMoodWeather: false,
        includeTags: false,
      ),
    );

    expect(find.text('未选择文字内容，将只分享图片'), findsOneWidget);
    expect(find.text('先选择要分享的内容'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, '图片'), findsNothing);
    await tester.tap(find.bySemanticsLabel('更多应用'));
    await tester.pumpAndSettle();
    expect(find.text('分享日记'), findsOneWidget);
  });

  testWidgets('the long-image entry closes the sheet with its request', (
    tester,
  ) async {
    final result = await _openSheet(
      tester,
      content: _content(),
      brightness: Brightness.dark,
    );

    // 面板内另有横向图片条，滚动对象取面板自身的纵向滚动。
    await tester.scrollUntilVisible(
      find.text('分享为长图'),
      120,
      scrollable: find
          .descendant(
            of: find.byType(DiaryShareSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('分享为长图'));
    await tester.pumpAndSettle();
    expect(result()!.action, DiaryShareAction.longImage);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Linux offers copy text and save images instead of the system share',
    (tester) async {
      final result = await _openSheet(tester, content: _content());

      expect(find.bySemanticsLabel('更多应用'), findsNothing);
      expect(find.bySemanticsLabel('复制文字'), findsOneWidget);
      // 带图时“文字已复制”的说明只对分享成立，保存图片不动剪贴板。
      expect(find.textContaining('剪贴板'), findsNothing);

      await tester.tap(find.bySemanticsLabel('保存图片…'));
      await tester.pumpAndSettle();
      final request = result()!;
      expect(request.action, DiaryShareAction.saveImages);
      expect(request.images, <String>['/missing/0.jpg', '/missing/1.jpg']);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets('Linux disables saving images when none are selected', (
    tester,
  ) async {
    await _openSheet(tester, content: _content(imageCount: 0));
    final save = tester.widget<DiaryShareTargetButton>(
      find.widgetWithText(DiaryShareTargetButton, '保存图片…'),
    );
    expect(save.onTap, isNull);
    // 桌面的长图生成后保存到文件。
    expect(find.text('保存为长图…', skipOffstage: false), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('Windows keeps the system share target', (tester) async {
    await _openSheet(tester, content: _content());
    expect(find.bySemanticsLabel('更多应用'), findsOneWidget);
    expect(find.bySemanticsLabel('保存图片…'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
