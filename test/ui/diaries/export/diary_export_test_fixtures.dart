import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/ui/diaries/export/diary_export_entry.dart';

/// 导出写出器测试共用的固定文案与日记。
final DiaryExportLabels testExportLabels = DiaryExportLabels(
  untitled: '无标题',
  mood: '心情',
  energy: '精力',
  weather: '天气',
  location: '地点',
  tags: '标签',
  date: '日期',
  time: '时间',
  title: '标题',
  content: '正文',
  wordCount: '字数',
  updated: '最后编辑',
  image: '图片',
  audio: '录音',
  video: '视频',
  attachment: '附件',
  formatDateTime: (DateTime value) =>
      '${value.year}年${value.month}月${value.day}日 '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
  formatDate: (DateTime value) => '${value.year}-${value.month}-${value.day}',
  exportedBy: '由 Jotsy 导出',
);

const String testMetadata =
    '{"context":{"moodEmoji":"😊","weather":"晴","location":"杭州西湖","energyLevel":4}}';

/// 覆盖各类块的一篇日记：标题、行内样式、有序/无序/待办、引用、代码、
/// 图片与录音、视频、附件。[image] 为正文图片来源。
DiaryExportEntry richEntry({
  String title = '春日 *小记*',
  String? image,
  String? cover,
  String? attachmentPath,
}) {
  return DiaryExportEntry.parse(
    diaryId: 'd1',
    title: title,
    createdAt: DateTime(2026, 4, 3, 9, 5),
    updatedAt: DateTime(2026, 4, 4, 10, 30),
    tagNames: const <String>['旅行', '美食'],
    cover: cover,
    metadata: testMetadata,
    deltaOps: <dynamic>[
      <String, dynamic>{'insert': '今天'},
      <String, dynamic>{
        'insert': '很开心',
        'attributes': <String, dynamic>{'bold': true},
      },
      <String, dynamic>{'insert': '，去了'},
      <String, dynamic>{
        'insert': '西湖',
        'attributes': <String, dynamic>{'link': 'https://example.com/a b'},
      },
      <String, dynamic>{'insert': ' <3 & 1+1\n# 不是标题\n'},
      <String, dynamic>{'insert': '小标题'},
      <String, dynamic>{
        'insert': '\n',
        'attributes': <String, dynamic>{'header': 2},
      },
      <String, dynamic>{'insert': '第一'},
      <String, dynamic>{
        'insert': '\n',
        'attributes': <String, dynamic>{'list': 'ordered'},
      },
      <String, dynamic>{'insert': '子项'},
      <String, dynamic>{
        'insert': '\n',
        'attributes': <String, dynamic>{'list': 'bullet', 'indent': 1},
      },
      <String, dynamic>{'insert': '第二'},
      <String, dynamic>{
        'insert': '\n',
        'attributes': <String, dynamic>{'list': 'ordered'},
      },
      <String, dynamic>{'insert': '买花'},
      <String, dynamic>{
        'insert': '\n',
        'attributes': <String, dynamic>{'list': 'checked'},
      },
      <String, dynamic>{'insert': '一句话'},
      <String, dynamic>{
        'insert': '\n',
        'attributes': <String, dynamic>{'blockquote': true},
      },
      <String, dynamic>{'insert': 'print(1)'},
      <String, dynamic>{
        'insert': '\n',
        'attributes': <String, dynamic>{'code-block': true},
      },
      if (image != null) ...<dynamic>[
        <String, dynamic>{
          'insert': <String, dynamic>{'image': image},
        },
        <String, dynamic>{'insert': '\n'},
      ],
      <String, dynamic>{
        'insert': <String, dynamic>{
          diaryAudioEmbedType: const DiaryAudioAttachment(
            path: '/private/rec.m4a',
            duration: Duration(seconds: 75),
            name: '晨间录音',
          ).encode(),
        },
      },
      <String, dynamic>{'insert': '\n'},
      <String, dynamic>{
        'insert': <String, dynamic>{
          diaryAttachmentEmbedType: DiaryFileAttachment(
            path: attachmentPath ?? '/private/files/report.pdf',
            name: '报告.pdf',
          ).encode(),
        },
      },
      <String, dynamic>{'insert': '\n结尾\n'},
    ],
  );
}
