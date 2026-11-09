import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/ai/sections/chat/ai_chat_composer.dart';
import 'package:node_diary/ui/ai/sections/chat/ai_chat_composer_images.dart';
import 'package:node_diary/ui/diaries/controllers/diary_comment_images_controller.dart';
import 'package:node_diary/ui/diaries/widgets/diary_comments/diary_comment_image_strip.dart';

/// 输入栏的附图：附图按钮打开选择器（能拍照时先弹菜单），缩略图出现在
/// 输入框上方，只有图片也能发送，复制中不能发送，说明行照传入显示。
void main() {
  final l10n = lookupAppLocalizations(const Locale('zh'));

  DiaryCommentImagesController images({
    Future<List<PlatformFile>?> Function()? picker,
  }) => DiaryCommentImagesController(
    maxImages: kAiMessageMaxImages,
    picker:
        picker ??
        () async => [PlatformFile(name: 'a.jpg', size: 1, path: '/tmp/a.jpg')],
    importer: (file) async => '/data/diary_images/m/${file.name}',
    discarder: (_) async {},
  );

  Future<void> pump(
    WidgetTester tester, {
    required DiaryCommentImagesController controller,
    required VoidCallback onSend,
    VoidCallback? onTakePhoto,
    Widget? note,
    List<Widget> contextChips = const <Widget>[],
    List<AiComposerOption> options = const <AiComposerOption>[],
    Widget? model,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          bottomNavigationBar: AiChatComposer(
            controller: TextEditingController(),
            focusNode: FocusNode(),
            side: 16,
            busy: false,
            enabled: true,
            onSend: onSend,
            onStop: () {},
            images: controller,
            onPickImages: () => controller.pick(),
            onTakePhoto: onTakePhoto,
            note: note,
            contextChips: contextChips,
            options: options,
            model: model,
          ),
        ),
      ),
    );
  }

  IconButton sendButton(WidgetTester tester) => tester.widget<IconButton>(
    find.ancestor(
      of: find.byTooltip(l10n.aiPanelSend),
      matching: find.byType(IconButton),
    ),
  );

  testWidgets('a photo alone can be sent', (tester) async {
    final controller = images();
    addTearDown(controller.dispose);
    var sent = 0;
    await pump(tester, controller: controller, onSend: () => sent++);

    expect(find.byType(DiaryCommentImageStrip), findsNothing);
    expect(sendButton(tester).onPressed, isNull);

    await tester.tap(find.byTooltip(l10n.aiChatAttachImages));
    await tester.pumpAndSettle();
    expect(controller.images, ['/data/diary_images/m/a.jpg']);
    expect(find.byType(DiaryCommentImageStrip), findsOneWidget);
    expect(sendButton(tester).onPressed, isNotNull);
    sendButton(tester).onPressed!();
    expect(sent, 1);
  });

  testWidgets('cannot send while photos are still being copied', (
    tester,
  ) async {
    // 选择器一秒后才返回：这期间算“正在复制”。
    final controller = images(
      picker: () async {
        await Future<void>.delayed(const Duration(seconds: 1));
        return [PlatformFile(name: 'b.jpg', size: 1, path: '/tmp/b.jpg')];
      },
    );
    addTearDown(controller.dispose);
    await pump(tester, controller: controller, onSend: () {});
    await tester.enterText(find.byType(TextField), '有字');
    await tester.pump();
    expect(sendButton(tester).onPressed, isNotNull);

    await tester.tap(find.byTooltip(l10n.aiChatAttachImages));
    await tester.pump();
    expect(controller.isBusy, isTrue);
    expect(sendButton(tester).onPressed, isNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(sendButton(tester).onPressed, isNotNull);
  });

  testWidgets('where photos can be taken the button offers both sources', (
    tester,
  ) async {
    final controller = images();
    addTearDown(controller.dispose);
    var photos = 0;
    await pump(
      tester,
      controller: controller,
      onSend: () {},
      onTakePhoto: () => photos++,
      note: AiComposerNote(text: l10n.aiChatImagesNoVision),
    );
    expect(find.text(l10n.aiChatImagesNoVision), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.aiChatAttachImages));
    await tester.pumpAndSettle();
    expect(find.text(l10n.diaryMediaFromLibrary), findsOneWidget);
    await tester.tap(find.text(l10n.diaryMediaTakePhoto));
    await tester.pumpAndSettle();
    expect(photos, 1);
  });

  testWidgets('the plus menu holds photos, scope and persona; changed '
      'settings show above the input and can be reset', (tester) async {
    final controller = images();
    addTearDown(controller.dispose);
    var scope = 0;
    var cleared = 0;
    var model = 0;
    await pump(
      tester,
      controller: controller,
      onSend: () {},
      options: <AiComposerOption>[
        AiComposerOption(
          icon: FontAwesomeIcons.magnifyingGlass,
          label: l10n.aiChatScope,
          value: l10n.aiChatScopeAuto,
          onPressed: () => scope++,
        ),
        // 生成中不能改：这一行停用。
        AiComposerOption(
          icon: FontAwesomeIcons.masksTheater,
          label: l10n.aiChatPersona,
          value: '树洞',
          onPressed: null,
        ),
      ],
      contextChips: <Widget>[
        AiComposerChip(
          icon: FontAwesomeIcons.magnifyingGlass,
          label: '最近 7 天',
          onPressed: () {},
          onClear: () => cleared++,
        ),
      ],
      model: AiComposerModelButton(
        label: '某模型 · 高',
        tooltip: l10n.aiChatModelSheetTitle,
        onPressed: () => model++,
      ),
    );

    // 只有附图时是附图按钮；有范围 / 人设时是“＋”。
    expect(find.byTooltip(l10n.aiChatAttachImages), findsNothing);
    await tester.tap(find.byTooltip(l10n.aiChatComposerAdd));
    await tester.pumpAndSettle();
    expect(find.text(l10n.diaryMediaFromLibrary), findsOneWidget);
    expect(find.text(l10n.aiChatScopeAuto), findsOneWidget);
    expect(find.text('树洞'), findsOneWidget);
    await tester.tap(find.text(l10n.aiChatPersona));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.aiChatScope));
    await tester.pumpAndSettle();
    expect(scope, 1);

    expect(find.text('最近 7 天'), findsOneWidget);
    await tester.tap(find.byTooltip(l10n.commonReset));
    expect(cleared, 1);

    await tester.tap(find.byTooltip(l10n.aiChatModelSheetTitle));
    expect(model, 1);
    expect(find.text('某模型 · 高'), findsOneWidget);
  });

  testWidgets('fits a narrow phone: a long model name is shortened, the row '
      'does not scroll or overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = images();
    addTearDown(controller.dispose);
    await pump(
      tester,
      controller: controller,
      onSend: () {},
      onTakePhoto: () {},
      options: <AiComposerOption>[
        AiComposerOption(
          icon: FontAwesomeIcons.magnifyingGlass,
          label: l10n.aiChatScope,
          value: l10n.aiChatScopeAuto,
          onPressed: () {},
        ),
      ],
      contextChips: <Widget>[
        AiComposerChip(
          icon: FontAwesomeIcons.magnifyingGlass,
          label: '2026年10月1日 – 2026年11月10日',
          onPressed: () {},
          onClear: () {},
        ),
        AiComposerChip(
          emoji: '🌙',
          label: '一位名字很长很长很长很长的人设',
          onPressed: () {},
          onClear: () {},
        ),
      ],
      model: AiComposerModelButton(
        label: 'a-very-long-model-name-with-many-parts-2026-preview · 高',
        tooltip: l10n.aiChatModelSheetTitle,
        onPressed: () {},
      ),
    );
    expect(tester.takeException(), isNull);
    // 发送按钮仍在屏幕内，模型按钮没有把它挤出去。
    expect(
      tester.getRect(find.byTooltip(l10n.aiPanelSend)).right,
      lessThanOrEqualTo(320),
    );
    expect(
      tester.getRect(find.byTooltip(l10n.aiChatModelSheetTitle)).right,
      lessThan(tester.getRect(find.byTooltip(l10n.aiPanelSend)).left),
    );
  });
}
