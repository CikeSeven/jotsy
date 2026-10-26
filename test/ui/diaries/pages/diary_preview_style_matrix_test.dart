import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_presets.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_settings.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_style.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 内置预设与一套极端样式 × 明暗 × {360dp@1.0, 320dp@1.3}：预览页不溢出。
///
/// 两篇日记：信息齐全的长标题日记（含超长地名与标签），以及没有标题、没有
/// 正文的空白日记。
const _extreme = DiaryPreviewStyle(
  page: DiaryPreviewPageStyle(
    paper: DiaryPreviewPaper.ink,
    horizontalPadding: 48,
    topBar: DiaryPreviewTopBarMode.pinned,
    topBarTitle: DiaryPreviewTopBarTitle.date,
    showShareButton: true,
    progress: DiaryPreviewProgress.line,
    backToTop: true,
  ),
  cover: DiaryPreviewCoverStyle(
    mode: DiaryPreviewCoverMode.inset,
    height: 640,
    fit: DiaryPreviewCoverFit.cover,
    radius: 40,
  ),
  title: DiaryPreviewTitleStyle(scale: 1.8, align: DiaryPreviewAlign.center),
  meta: DiaryPreviewMetaStyle(
    position: DiaryPreviewMetaPosition.aboveTitle,
    layout: DiaryPreviewMetaLayout.card,
    dateFormat: DiaryCardDateFormat.full,
    showWeekday: true,
    showTime: true,
    dateSource: DiaryCardDateSource.updated,
    tagStyle: DiaryCardTagStyle.dot,
  ),
  body: DiaryPreviewBodyStyle(editedFormat: DiaryPreviewEditedFormat.full),
);

class _PendingDetailDatabase extends AppDatabase {
  _PendingDetailDatabase() : super.forTesting(NativeDatabase.memory());

  @override
  Future<DiaryWithTags?> getDiaryWithTagsByDiaryId(String diaryId) =>
      Completer<DiaryWithTags?>().future;
}

DiaryWithTags _diary(int index, {required bool rich}) {
  final created = DateTime(2025, 3, 2, 9, 30);
  return DiaryWithTags(
    diary: Diary(
      id: index,
      diaryId: 'matrix-$index',
      title: rich ? '一个很长很长的标题，用来测试标题在窄屏和大字号下会不会溢出' : '',
      content: rich
          ? '[{"insert":"正文第一段，Some English words in between.\\n"},{"insert":"待办"},{"insert":"\\n","attributes":{"list":"unchecked"}}]'
          : '[{"insert":"\\n"}]',
      contentText: rich ? '正文第一段，Some English words in between.\n待办' : '',
      metadata: rich
          ? '{"context":{"moodEmoji":"😊","energyLevel":2,"location":"上海市黄浦区中山东一路外滩观景平台旁边的一条小路","weather":"雷阵雨转多云","weatherIconCode":"302"}}'
          : '{}',
      createdAt: created,
      updatedAt: created.add(const Duration(hours: 30)),
      isArchived: false,
      isPinned: false,
      isDeleted: false,
    ),
    tags: rich
        ? const <Tag>[
            Tag(id: 1, name: '一个特别特别长的标签名字', color: 0xFF4CAF50),
            Tag(id: 2, name: '日常', color: 0xFF2196F3),
          ]
        : const <Tag>[],
  );
}

void main() {
  final styles = <String, DiaryPreviewStyle>{
    for (final id in DiaryPreviewPresetId.values)
      id.name: DiaryPreviewPresets.styleOf(id),
    'extreme': _extreme,
  };
  const sizes = <(double, double, double)>[(360, 800, 1.0), (320, 640, 1.3)];

  for (final entry in styles.entries) {
    for (final brightness in Brightness.values) {
      for (final (width, height, scale) in sizes) {
        testWidgets('${entry.key} ${brightness.name} ${width.toInt()}dp@$scale '
            'does not overflow', (tester) async {
          tester.view.physicalSize = Size(width, height);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          SharedPreferences.setMockInitialValues(<String, Object>{
            'app.settings.diary_preview_style':
                DiaryPreviewSettings(current: entry.value).encode() ?? '',
          });
          final settings = await SettingsService.create();
          for (final rich in <bool>[true, false]) {
            final database = _PendingDetailDatabase();
            final detail = _diary(rich ? 1 : 2, rich: rich);
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  appDatabaseProvider.overrideWithValue(database),
                  settingsServiceProvider.overrideWith((ref) async => settings),
                ],
                child: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, height),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: MaterialApp(
                    theme: expressiveTestTheme(brightness),
                    locale: const Locale('zh'),
                    localizationsDelegates:
                        const <LocalizationsDelegate<dynamic>>[
                          ...AppLocalizations.localizationsDelegates,
                          quill.AppFlowyEditorLocalizations.delegate,
                        ],
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: DiaryPreviewPage(
                      diaryId: detail.diary.diaryId,
                      initialDetail: detail,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(Duration.zero);
            await database.close();
          }
        });
      }
    }
  }
}
