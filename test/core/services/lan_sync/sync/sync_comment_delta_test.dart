import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/rich_text/inline_rich_text.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_canonical_misc.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';

/// 留言格式在同步记录里的形状：只在有格式时出现，没有格式的留言与格式
/// 版本 3 的规范值相同；对不上文字的格式不同步。
void main() {
  SyncRawComment raw({String content = '加粗 链接', String? delta}) =>
      SyncRawComment(
        localId: 1,
        commentId: 'c-1',
        diaryId: 'd-1',
        content: content,
        mood: null,
        createdAt: 1700000000,
        editedAt: null,
        delta: delta,
      );

  final delta = encodeDiaryCommentDelta(const <InlineTextRun>[
    InlineTextRun('加粗', InlineTextMarks(bold: true)),
    InlineTextRun(' '),
    InlineTextRun('链接', InlineTextMarks(href: 'jotsy://notebook/n-1')),
  ]);

  Map<String, Object?> mainOf(SyncRecord record) =>
      record.facets[SyncFacet.main]! as Map<String, Object?>;

  test('a plain comment has no delta field', () {
    expect(mainOf(syncCommentRecord(raw())).containsKey('delta'), isFalse);
  });

  test('a formatted comment carries the parsed delta and writes it back', () {
    final record = syncCommentRecord(raw(delta: delta));
    expect(mainOf(record)['delta'], jsonDecode(delta!));
    final columns = SyncCommentColumns.fromRecord(record, dataRoot: '/r');
    expect(columns.delta, delta);
    expect(
      decodeDiaryCommentRuns(columns.delta, columns.content).last.marks.href,
      'jotsy://notebook/n-1',
    );
  });

  test('a delta that does not match the text is not synced', () {
    final record = syncCommentRecord(raw(content: '改过的字', delta: delta));
    expect(mainOf(record).containsKey('delta'), isFalse);
  });

  test('a record whose delta does not match is written without it', () {
    final record = syncCommentRecord(raw(delta: delta));
    final mismatched = SyncRecord(record.key, <String, Object?>{
      SyncFacet.main: <String, Object?>{...mainOf(record), 'content': '别的字'},
    });
    expect(
      SyncCommentColumns.fromRecord(mismatched, dataRoot: '/r').delta,
      isNull,
    );
  });
}
