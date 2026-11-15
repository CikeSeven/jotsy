import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/core/database/diary_blocks/diary_list_style.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';

import 'diary_export_test_fixtures.dart';

/// 覆盖正文全部块类型的一篇日记，供要求“什么都不能漏”的写出器测试共用
/// （EPUB 逐文件做 XML 解析、网页拆分前后逐字节比对）。
///
/// 内容：全部行内样式（粗斜体、下划线、删除线、行内代码、链接、文字色与
/// 半透明背景色、字号、上下标）、1~6 级标题与对齐、首行缩进三态、嵌套的
/// 有序 / 无序 / 待办列表与列表样式、引用、带语言的代码、普通图片（限宽、
/// 居中）、一排小图、录音 / 视频 / 附件、分隔线、提示块、折叠块与里面的
/// 子块、带表头的表格、日记链接卡片、XML 不允许的控制字符与 emoji；封面、
/// 心情等信息行、标签与两条留言（一条带图）。[image] 是正文与留言用的图片
/// 来源，[cover] 为封面来源。
DiaryExportEntry fullExportEntry({
  required String image,
  String? cover,
  String diaryId = 'full',
  String title = '全部 <块> & “格式”',
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime(2026, 4, 3, 9, 5);
  Map<String, Object?> block(
    String type, {
    List<Map<String, Object?>> delta = const <Map<String, Object?>>[],
    Map<String, Object?> data = const <String, Object?>{},
    List<Map<String, Object?>> children = const <Map<String, Object?>>[],
  }) => <String, Object?>{
    'type': type,
    'data': <String, Object?>{
      if (delta.isNotEmpty) kDiaryBlockDeltaKey: delta,
      ...data,
    },
    if (children.isNotEmpty) 'children': children,
  };
  Map<String, Object?> text(
    String type,
    String value, {
    Map<String, Object?> data = const <String, Object?>{},
    List<Map<String, Object?>> children = const <Map<String, Object?>>[],
  }) => block(
    type,
    delta: <Map<String, Object?>>[
      <String, Object?>{'insert': value},
    ],
    data: data,
    children: children,
  );
  Map<String, Object?> cell(int row, int col, List<String> paragraphs) =>
      <String, Object?>{
        'type': kDiaryBlockTableCell,
        'children': <Map<String, Object?>>[
          for (final value in paragraphs) text(kDiaryBlockParagraph, value),
        ],
        'data': <String, Object?>{
          kDiaryTableRowPositionKey: row,
          kDiaryTableColPositionKey: col,
        },
      };
  Map<String, Object?> picture({bool thumbnail = false, String? align}) =>
      block(
        kDiaryBlockImage,
        data: <String, Object?>{
          kDiaryBlockUrlKey: image,
          if (thumbnail) kDiaryImageThumbnailKey: true,
          'width': ?(thumbnail ? null : 240),
          kDiaryBlockAlignKey: ?align,
        },
      );

  final children = <Map<String, Object?>>[
    block(
      kDiaryBlockParagraph,
      delta: <Map<String, Object?>>[
        <String, Object?>{'insert': '普通 '},
        <String, Object?>{
          'insert': '粗',
          'attributes': <String, Object?>{kDiaryInlineBold: true},
        },
        <String, Object?>{
          'insert': '斜',
          'attributes': <String, Object?>{kDiaryInlineItalic: true},
        },
        <String, Object?>{
          'insert': '下划线',
          'attributes': <String, Object?>{kDiaryInlineUnderline: true},
        },
        <String, Object?>{
          'insert': '删除',
          'attributes': <String, Object?>{kDiaryInlineStrikethrough: true},
        },
        <String, Object?>{
          'insert': 'a<b',
          'attributes': <String, Object?>{kDiaryInlineCode: true},
        },
        <String, Object?>{
          'insert': '链接',
          'attributes': <String, Object?>{
            kDiaryInlineHref: 'https://example.com/?a=1&b="2"',
          },
        },
        <String, Object?>{
          'insert': '坏链接',
          'attributes': <String, Object?>{kDiaryInlineHref: 'javascript:x()'},
        },
        <String, Object?>{
          'insert': '彩色',
          'attributes': <String, Object?>{
            kDiaryInlineTextColor: '#FFD32F2F',
            kDiaryInlineBackgroundColor: '#55FFEB3B',
          },
        },
        <String, Object?>{
          'insert': '大字',
          'attributes': <String, Object?>{kDiaryInlineSize: 'large'},
        },
        <String, Object?>{'insert': 'x'},
        <String, Object?>{
          'insert': '2',
          'attributes': <String, Object?>{
            kDiaryInlineScript: kDiaryScriptSuper,
          },
        },
        <String, Object?>{'insert': 'H'},
        <String, Object?>{
          'insert': '2',
          'attributes': <String, Object?>{kDiaryInlineScript: kDiaryScriptSub},
        },
        // 垂直制表符与退格是 XML 不允许的字符；emoji 与组合 emoji 原样。
        <String, Object?>{'insert': 'O\u000b\u0008 😀👨‍👩‍👧 & <tag>'},
      ],
    ),
    text(kDiaryBlockParagraph, '全局缩进跟随'),
    text(
      kDiaryBlockParagraph,
      '这一段标了缩进',
      data: <String, Object?>{kDiaryParagraphIndentKey: true},
    ),
    text(
      kDiaryBlockParagraph,
      '这一段取消缩进',
      data: <String, Object?>{kDiaryParagraphIndentKey: false},
    ),
    text(
      kDiaryBlockParagraph,
      '居中的一段',
      data: <String, Object?>{kDiaryBlockAlignKey: kDiaryAlignCenter},
    ),
    text(kDiaryBlockParagraph, ''),
    for (var level = 1; level <= 6; level++)
      text(
        kDiaryBlockHeading,
        '标题 $level',
        data: <String, Object?>{
          kDiaryBlockLevelKey: level,
          if (level == 2) kDiaryBlockAlignKey: kDiaryAlignRight,
        },
      ),
    text(
      kDiaryBlockNumberedList,
      '第一',
      data: <String, Object?>{kDiaryListStyleKey: 'circled'},
      children: <Map<String, Object?>>[
        text(kDiaryBlockBulletedList, '子项'),
        text(
          kDiaryBlockBulletedList,
          '星形子项',
          data: <String, Object?>{kDiaryListStyleKey: 'star'},
        ),
      ],
    ),
    text(kDiaryBlockNumberedList, '第二'),
    text(
      kDiaryBlockTodoList,
      '做完了',
      data: <String, Object?>{
        kDiaryBlockCheckedKey: true,
        kDiaryBlockAlignKey: kDiaryAlignCenter,
      },
    ),
    text(
      kDiaryBlockTodoList,
      '还没做',
      data: <String, Object?>{kDiaryBlockCheckedKey: false},
    ),
    text(kDiaryBlockQuote, '一句引用'),
    text(
      kDiaryBlockCode,
      'if (a < b && c) {\n  print("x");\n}',
      data: <String, Object?>{kDiaryBlockLanguageKey: 'dart'},
    ),
    picture(align: kDiaryAlignCenter),
    picture(thumbnail: true),
    picture(thumbnail: true),
    block(
      kDiaryBlockAudio,
      data: <String, Object?>{
        'path': '/private/rec.m4a',
        'durationMs': 75000,
        'name': '晨间录音',
      },
    ),
    block(
      kDiaryBlockVideo,
      data: <String, Object?>{'path': '/private/clip.mp4', 'name': '海边'},
    ),
    block(
      kDiaryBlockAttachment,
      data: <String, Object?>{'path': '/private/report.pdf', 'name': '报告.pdf'},
    ),
    block(kDiaryBlockDivider),
    text(
      kDiaryBlockCallout,
      '记得带伞',
      data: <String, Object?>{
        kDiaryCalloutIconKey: '☔',
        kDiaryCalloutToneKey: kDiaryCalloutToneBlue,
      },
    ),
    text(
      kDiaryBlockToggleList,
      '展开看看',
      data: <String, Object?>{kDiaryToggleCollapsedKey: true},
      children: <Map<String, Object?>>[
        text(kDiaryBlockParagraph, '折叠里的段落'),
        text(kDiaryBlockBulletedList, '折叠里的列表'),
        picture(thumbnail: true),
      ],
    ),
    <String, Object?>{
      'type': kDiaryBlockTable,
      'children': <Map<String, Object?>>[
        cell(0, 0, <String>['姓名']),
        cell(0, 1, <String>['备注']),
        cell(1, 0, <String>['小明']),
        cell(1, 1, <String>['第一段', '第二段']),
      ],
      'data': <String, Object?>{
        kDiaryTableRowsLenKey: 2,
        kDiaryTableColsLenKey: 2,
        kDiaryTableHeaderRowKey: true,
      },
    },
    block(
      kDiaryBlockLinkCard,
      data: <String, Object?>{
        kDiaryLinkCardTargetKey: 'jotsy://diary/other',
        kDiaryLinkCardTitleKey: '另一篇日记',
      },
    ),
    text(kDiaryBlockParagraph, '结尾'),
  ];

  return DiaryExportEntry.parse(
    diaryId: diaryId,
    title: title,
    createdAt: created,
    updatedAt: created,
    tagNames: const <String>['旅行', 'a&b'],
    cover: cover,
    metadata: testMetadata,
    blockDocument: <String, Object?>{
      kDiaryBlocksDocumentKey: <String, Object?>{
        'type': kDiaryBlockPage,
        'children': children,
      },
    },
    comments: <DiaryCommentRow>[
      DiaryCommentRow(
        id: 1,
        commentId: '$diaryId-c1',
        diaryId: diaryId,
        content: '第一条留言\n第二行 <b>',
        mood: '😊',
        createdAt: created.add(const Duration(days: 2)),
        editedAt: created.add(const Duration(days: 3)),
      ),
      DiaryCommentRow(
        id: 2,
        commentId: '$diaryId-c2',
        diaryId: diaryId,
        content: '',
        createdAt: created.add(const Duration(hours: 5)),
        images: encodeDiaryCommentImages(<String>[image, '/missing.png']),
      ),
    ],
  );
}
