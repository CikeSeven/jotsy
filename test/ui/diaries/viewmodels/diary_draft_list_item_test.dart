import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_draft_list_item.dart';

DiaryDraftRow _row({
  String title = '',
  String contentText = '',
  Object? payload = const <String, Object?>{},
}) {
  final at = DateTime(2026, 10, 18, 9);
  return DiaryDraftRow(
    id: 1,
    draftId: 'draft-${title.hashCode}-${contentText.hashCode}',
    title: title,
    contentText: contentText,
    payload: payload is String ? payload : jsonEncode(payload),
    createdAt: at,
    updatedAt: at,
  );
}

void main() {
  test('a titled draft shows its title and the whole body as snippet', () {
    final item = DiaryDraftListItem.of(
      _row(title: '  周末\n去爬山 ', contentText: '早上出发\n\n山顶有雾'),
    );
    expect(item.displayTitle, '周末 去爬山');
    expect(item.snippet, '早上出发 山顶有雾');
  });

  test('an untitled draft promotes its first line and skips it below', () {
    final item = DiaryDraftListItem.of(
      _row(contentText: '\n  今天下雨了  \n一整天没出门\n'),
    );
    expect(item.displayTitle, '今天下雨了');
    expect(item.snippet, '一整天没出门');
  });

  test('a draft with no text at all has no display title', () {
    final item = DiaryDraftListItem.of(_row());
    expect(item.displayTitle, isNull);
    expect(item.snippet, isEmpty);
    expect(item.wordCount, 0);
  });

  test('long snippets are cut before layout', () {
    final item = DiaryDraftListItem.of(
      _row(title: 't', contentText: '字' * 500),
    );
    expect(item.snippet.length, DiaryDraftListItem.snippetMaxLength);
  });

  group('thumbnail', () {
    test('prefers the cover over body images', () {
      final item = DiaryDraftListItem.of(
        _row(
          payload: {
            'cover': ' /docs/diary_covers/c.jpg ',
            'contentDocJson': jsonEncode([
              {
                'insert': {'image': '/docs/diary_images/media_1/a.jpg'},
              },
            ]),
          },
        ),
      );
      expect(item.thumbnail, '/docs/diary_covers/c.jpg');
    });

    test('falls back to the first image in the body', () {
      final item = DiaryDraftListItem.of(
        _row(
          payload: {
            'cover': '',
            'contentDocJson': jsonEncode([
              {'insert': '文字\n'},
              {
                'insert': {'image': '/docs/diary_images/media_1/a.jpg'},
              },
              {
                'insert': {'image': '/docs/diary_images/media_1/b.jpg'},
              },
            ]),
          },
        ),
      );
      expect(item.thumbnail, '/docs/diary_images/media_1/a.jpg');
    });

    test('is null for text-only or broken payloads', () {
      expect(
        DiaryDraftListItem.of(
          _row(payload: {'contentDocJson': '[{"insert":"text\\n"}]'}),
        ).thumbnail,
        isNull,
      );
      expect(DiaryDraftListItem.of(_row(payload: '{broken')).thumbnail, isNull);
      expect(DiaryDraftListItem.of(_row(payload: '[1, 2]')).thumbnail, isNull);
    });
  });
}
