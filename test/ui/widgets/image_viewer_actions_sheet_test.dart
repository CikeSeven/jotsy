import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_share_target.dart';
import 'package:node_diary/ui/diaries/widgets/diary_share_widgets.dart';
import 'package:node_diary/ui/diaries/widgets/diary_sheet_controls.dart';
import 'package:node_diary/ui/widgets/image_viewer_actions_sheet.dart';

import '../../support/expressive_test_theme.dart';

/// 宿主页：点“open”打开面板，面板关闭后把结果记进 [results]。
Widget _host(
  Brightness brightness, {
  required Future<Set<DiaryShareTarget>> installed,
  Set<DiaryShareTarget>? initial,
  required bool canOpenDiary,
  required List<ImageViewerAction?> results,
}) {
  return MaterialApp(
    theme: expressiveTestTheme(brightness),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              results.add(
                await showImageViewerActionsSheet(
                  context,
                  installedTargets: installed,
                  initialTargets: initial,
                  canOpenDiary: canOpenDiary,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

List<String> _targetLabels(WidgetTester tester) => tester
    .widgetList<DiaryShareTargetButton>(find.byType(DiaryShareTargetButton))
    .map((DiaryShareTargetButton button) => button.label)
    .toList();

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'lists installed apps before more apps and returns the tapped target '
      'in $brightness',
      (tester) async {
        final results = <ImageViewerAction?>[];
        const installed = <DiaryShareTarget>{
          DiaryShareTarget.wechat,
          DiaryShareTarget.weibo,
        };
        await tester.pumpWidget(
          _host(
            brightness,
            installed: Future<Set<DiaryShareTarget>>.value(installed),
            initial: installed,
            canOpenDiary: true,
            results: results,
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pump();
        final l10n = tester.element(find.byType(ImageViewerActionsSheet)).l10n;
        // 检测结果已在手：面板第一帧就排好全部目标，顺序与日记分享面板一致。
        expect(_targetLabels(tester), <String>[
          l10n.diaryShareTargetWeibo,
          l10n.diaryShareTargetWechat,
          l10n.diaryShareTargetSystem,
        ]);
        await tester.pumpAndSettle();
        expect(find.text(l10n.imageViewerSaveToGallery), findsOneWidget);
        expect(find.text(l10n.imageViewerOpenDiary), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text(l10n.diaryShareTargetWechat));
        await tester.pumpAndSettle();
        expect(find.byType(ImageViewerActionsSheet), findsNothing);
        expect(
          results.single,
          isA<ImageViewerShareAction>().having(
            (ImageViewerShareAction action) => action.target,
            'target',
            DiaryShareTarget.wechat,
          ),
        );
      },
    );
  }

  for (final width in <double>[360, 411]) {
    testWidgets('title, share circles and action icons share one edge at '
        '${width.toInt()}dp', (tester) async {
      tester.view
        ..physicalSize = Size(width * 3, 2400)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      const installed = <DiaryShareTarget>{
        DiaryShareTarget.weibo,
        DiaryShareTarget.xiaohongshu,
        DiaryShareTarget.wechat,
        DiaryShareTarget.wechatMoments,
        DiaryShareTarget.qq,
      };
      await tester.pumpWidget(
        _host(
          Brightness.light,
          installed: Future<Set<DiaryShareTarget>>.value(installed),
          initial: installed,
          canOpenDiary: true,
          results: <ImageViewerAction?>[],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      Rect circleOf(int index) => tester.getRect(
        find
            .descendant(
              of: find.byType(DiaryShareTargetButton).at(index),
              matching: find.byType(InkWell),
            )
            .first,
      );
      final sheet = tester.getRect(find.byType(ImageViewerActionsSheet));
      final titleIcon = tester.getRect(
        find.descendant(
          of: find.byType(DiarySheetSectionHeader),
          matching: find.byType(FaIcon),
        ),
      );
      final saveIcon = tester.getRect(
        find.byWidgetPredicate(
          (widget) =>
              widget is FaIcon && widget.icon == FontAwesomeIcons.download.data,
        ),
      );
      final chevron = tester.getRect(
        find.byWidgetPredicate(
          (widget) =>
              widget is FaIcon &&
              widget.icon == FontAwesomeIcons.angleRight.data,
        ),
      );
      // 左边线：标题图标、首列圆形、分组里的行图标。
      expect(titleIcon.left - sheet.left, closeTo(32, 0.5));
      expect(circleOf(0).left, closeTo(titleIcon.left, 0.5));
      expect(saveIcon.left, closeTo(titleIcon.left, 0.5));
      // 第一行排满：末列圆形与行尾箭头落在右边线上；下一行与上一行成列。
      final perRow = width < 400 ? 4 : 5;
      final lastInRow = circleOf(perRow - 1);
      expect(sheet.right - lastInRow.right, closeTo(32, 0.6));
      expect(chevron.right, closeTo(lastInRow.right, 0.6));
      expect(circleOf(perRow).top, greaterThan(lastInRow.bottom));
      expect(circleOf(perRow).left, closeTo(circleOf(0).left, 0.5));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('installed apps join more apps once detection finishes', (
    tester,
  ) async {
    final results = <ImageViewerAction?>[];
    final detection = Completer<Set<DiaryShareTarget>>();
    await tester.pumpWidget(
      _host(
        Brightness.light,
        installed: detection.future,
        canOpenDiary: false,
        results: results,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(ImageViewerActionsSheet)).l10n;
    expect(_targetLabels(tester), <String>[l10n.diaryShareTargetSystem]);
    expect(find.text(l10n.imageViewerOpenDiary), findsNothing);

    detection.complete(<DiaryShareTarget>{DiaryShareTarget.qq});
    await tester.pumpAndSettle();
    expect(_targetLabels(tester), <String>[
      l10n.diaryShareTargetQq,
      l10n.diaryShareTargetSystem,
    ]);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(l10n.imageViewerSaveToGallery));
    await tester.pumpAndSettle();
    expect(results.single, isA<ImageViewerSaveAction>());
  });

  testWidgets('detection failure still leaves more apps and save usable', (
    tester,
  ) async {
    final results = <ImageViewerAction?>[];
    await tester.pumpWidget(
      _host(
        Brightness.dark,
        // 看图页在打开时就监听了检测结果，失败不会成为未处理的异常。
        installed: Future<Set<DiaryShareTarget>>.error(StateError('no'))
          ..ignore(),
        canOpenDiary: true,
        results: results,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(ImageViewerActionsSheet)).l10n;
    expect(_targetLabels(tester), <String>[l10n.diaryShareTargetSystem]);

    await tester.tap(find.text(l10n.imageViewerOpenDiary));
    await tester.pumpAndSettle();
    expect(results.single, isA<ImageViewerOpenDiaryAction>());
  });
}
