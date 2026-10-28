import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/diaries/widgets/diary_comments/diary_search_comment_hit.dart';

/// 留言在列表上的两处痕迹：卡片底栏的留言数与搜索结果下方命中的留言。
void main() {
  DiaryWithTags diary(String id) {
    final now = DateTime(2026, 10, 5, 14, 30);
    return DiaryWithTags(
      diary: Diary(
        id: id.hashCode,
        diaryId: id,
        title: 'Title $id',
        content: '[{"insert":"Hello\\n"}]',
        contentText: 'Hello',
        metadata: '{}',
        createdAt: now,
        updatedAt: now,
        isArchived: false,
        isPinned: false,
        isDeleted: false,
      ),
      tags: const <Tag>[],
    );
  }

  Future<void> pumpList(
    WidgetTester tester, {
    required List<DiaryWithTags> diaries,
    Map<String, int> commentCounts = const <String, int>{},
    DiaryCardStyle cardStyle = DiaryCardStyle.defaults,
    Widget? Function(BuildContext, DiaryWithTags)? below,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: const MaterialTheme(TextTheme()).light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: CustomScrollView(
            slivers: <Widget>[
              DiariesListSection(
                diaries: diaries,
                commentCounts: commentCounts,
                belowCardBuilder: below,
                cardStyle: cardStyle,
                layoutMode: DiaryLayoutMode.list,
                selectedDiaryIds: const <String>{},
                isSelectionMode: false,
                maxVisibleTags: 3,
                onCreate: () {},
                onOpenEditor: (_, _) {},
                onToggleSelection: (_, _) {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  final commentIcon = find.byIcon(FontAwesomeIcons.comment.data);

  testWidgets('a card shows its comment count only when it has comments', (
    tester,
  ) async {
    await pumpList(
      tester,
      diaries: <DiaryWithTags>[diary('a'), diary('b')],
      commentCounts: const <String, int>{'a': 3},
    );
    expect(commentIcon, findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('the card style can hide the comment count', (tester) async {
    final style = DiaryCardStyle.defaults.copyWith(
      meta: DiaryCardStyle.defaults.meta.copyWith(showComments: false),
    );
    await pumpList(
      tester,
      diaries: <DiaryWithTags>[diary('a')],
      commentCounts: const <String, int>{'a': 3},
      cardStyle: style,
    );
    expect(commentIcon, findsNothing);
  });

  testWidgets('the search hit sits under its card with the keyword marked', (
    tester,
  ) async {
    await pumpList(
      tester,
      diaries: <DiaryWithTags>[diary('a'), diary('b')],
      below: (context, item) => item.diary.diaryId == 'a'
          ? const DiarySearchCommentHit(
              content: 'Years later I went back to the LIGHTHOUSE again',
              keyword: 'lighthouse',
            )
          : null,
    );
    expect(find.byType(DiarySearchCommentHit), findsOneWidget);
    // 图标也是一段 RichText，按文字挑出留言那一段。
    final rich = tester.widget<RichText>(
      find.descendant(
        of: find.byType(DiarySearchCommentHit),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('LIGHTHOUSE'),
        ),
      ),
    );
    final spans = <String>[];
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text != null) spans.add(span.text!);
      return true;
    });
    // 命中处前面只留一段，关键词单独成段（按原文大小写）。
    expect(spans.first, startsWith('…'));
    expect(spans, contains('LIGHTHOUSE'));
  });

  test('only a comment-only match needs the hint', () {
    expect(
      DiarySearchCommentHit.matchesOnlyComment(
        title: 'Sea',
        contentText: 'waves',
        keyword: 'Gull',
      ),
      isTrue,
    );
    expect(
      DiarySearchCommentHit.matchesOnlyComment(
        title: 'Seagull',
        contentText: 'waves',
        keyword: 'gull',
      ),
      isFalse,
    );
    expect(
      DiarySearchCommentHit.matchesOnlyComment(
        title: 'Sea',
        contentText: 'a GULL flew',
        keyword: 'gull',
      ),
      isFalse,
    );
  });
}
