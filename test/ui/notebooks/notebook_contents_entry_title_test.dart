import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_view_data.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_contents_entry_title.dart';

/// 目录行标题的口径（#291）：写了标题用标题，没写标题取正文第一行，正文
/// 没有文字或胶囊未解封时为“无标题”。
void main() {
  const untitled = '无标题';

  NotebookContentsEntry entry({String title = '', String leadingText = ''}) =>
      NotebookContentsEntry(
        diaryId: 'd',
        title: title,
        createdAt: DateTime(2026, 11, 16),
        updatedAt: DateTime(2026, 11, 16),
        isArchived: false,
        chapterId: null,
        leadingText: leadingText,
      );

  NotebookContentsTitle titleOf(
    NotebookContentsEntry entry, {
    bool sealed = false,
  }) => notebookContentsTitle(entry, sealed: sealed, untitled: untitled);

  test('a written title wins over the body', () {
    expect(titleOf(entry(title: '东京', leadingText: '555')), (
      text: '东京',
      fromContent: false,
    ));
  });

  test('an untitled diary takes the first non-blank body line', () {
    expect(titleOf(entry(title: '  ', leadingText: '\n \n  5\t5 5  \n第二行')), (
      text: '5 5 5',
      fromContent: true,
    ));
  });

  test('the borrowed line is capped like the card title', () {
    final title = titleOf(entry(leadingText: '字' * 600));
    expect(title.fromContent, isTrue);
    expect(title.text.length, DiaryCardViewData.previewTextMaxLength);
  });

  test('a body without text falls back to untitled', () {
    expect(titleOf(entry(leadingText: '\n\n')), (
      text: untitled,
      fromContent: false,
    ));
  });

  test('a sealed capsule never shows its body', () {
    expect(titleOf(entry(leadingText: '秘密'), sealed: true), (
      text: untitled,
      fromContent: false,
    ));
    expect(titleOf(entry(title: '给一年后', leadingText: '秘密'), sealed: true), (
      text: '给一年后',
      fromContent: false,
    ));
  });
}
