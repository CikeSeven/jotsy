import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_share_content.dart';
import 'package:node_diary/ui/diaries/models/diary_share_options.dart';
import 'package:node_diary/ui/diaries/models/diary_share_target.dart';

DiaryShareContent _content({
  String title = '春日小记',
  List<dynamic>? ops,
  String? cover,
  String metadata =
      '{"context":{"moodEmoji":"😊","weather":"晴 22°C","location":"杭州西湖"}}',
  List<String> tagNames = const <String>['旅行', '美食'],
}) {
  return DiaryShareContent.parse(
    title: title,
    deltaOps:
        ops ??
        <dynamic>[
          <String, dynamic>{'insert': '今天去看花。\n'},
        ],
    cover: cover,
    metadata: metadata,
    tagNames: tagNames,
    createdAt: DateTime(2026, 4, 3, 9),
  );
}

void main() {
  group('DiaryShareBodyFormatter', () {
    test(
      'keeps list, checklist and quote structure as plain-text prefixes',
      () {
        final body = DiaryShareBodyFormatter.format(<dynamic>[
          <String, dynamic>{'insert': '清单'},
          <String, dynamic>{'insert': '\n'},
          <String, dynamic>{'insert': '牛奶'},
          <String, dynamic>{
            'insert': '\n',
            'attributes': <String, dynamic>{'list': 'bullet'},
          },
          <String, dynamic>{'insert': '第一步'},
          <String, dynamic>{
            'insert': '\n',
            'attributes': <String, dynamic>{'list': 'ordered'},
          },
          <String, dynamic>{'insert': '细节'},
          <String, dynamic>{
            'insert': '\n',
            'attributes': <String, dynamic>{'list': 'ordered', 'indent': 1},
          },
          <String, dynamic>{'insert': '第二步'},
          <String, dynamic>{
            'insert': '\n',
            'attributes': <String, dynamic>{'list': 'ordered'},
          },
          <String, dynamic>{'insert': '已完成'},
          <String, dynamic>{
            'insert': '\n',
            'attributes': <String, dynamic>{'list': 'checked'},
          },
          <String, dynamic>{'insert': '未完成'},
          <String, dynamic>{
            'insert': '\n',
            'attributes': <String, dynamic>{'list': 'unchecked'},
          },
          <String, dynamic>{'insert': '一句话'},
          <String, dynamic>{
            'insert': '\n',
            'attributes': <String, dynamic>{'blockquote': true},
          },
        ]);

        expect(
          body.text,
          '清单\n• 牛奶\n1. 第一步\n  1. 细节\n2. 第二步\n☑ 已完成\n☐ 未完成\n> 一句话',
        );
      },
    );

    test('drops inline marks and embeds, collecting images in order', () {
      final body = DiaryShareBodyFormatter.format(<dynamic>[
        <String, dynamic>{
          'insert': '加粗',
          'attributes': <String, dynamic>{'bold': true},
        },
        <String, dynamic>{'insert': '与'},
        <String, dynamic>{
          'insert': '链接',
          'attributes': <String, dynamic>{'link': 'https://example.com'},
        },
        <String, dynamic>{'insert': '\n\n\n'},
        <String, dynamic>{
          'insert': <String, dynamic>{'image': '/a.jpg'},
        },
        <String, dynamic>{'insert': '\n'},
        <String, dynamic>{
          'insert': <String, dynamic>{'audio': '{"path":"/r.m4a"}'},
        },
        <String, dynamic>{'insert': '\n结尾\n'},
        <String, dynamic>{
          'insert': <String, dynamic>{'image': '/b.png'},
        },
        <String, dynamic>{'insert': '\n'},
      ]);

      // 只含嵌入的行整行去掉，连续空行压成一行。
      expect(body.text, '加粗与链接 (https://example.com)\n\n结尾');
      expect(body.images, <String>['/a.jpg', '/b.png']);
    });

    test('returns empty text for an empty document', () {
      final body = DiaryShareBodyFormatter.format(<dynamic>[
        <String, dynamic>{'insert': '\n'},
      ]);
      expect(body.text, isEmpty);
      expect(body.images, isEmpty);
    });
  });

  group('DiaryShareContent', () {
    test('puts the cover first and removes duplicate images', () {
      final content = _content(
        cover: '/cover.jpg',
        ops: <dynamic>[
          <String, dynamic>{
            'insert': <String, dynamic>{'image': '/a.jpg'},
          },
          <String, dynamic>{
            'insert': <String, dynamic>{'image': '/cover.jpg'},
          },
          <String, dynamic>{'insert': '\n'},
        ],
      );
      expect(content.images, <String>['/cover.jpg', '/a.jpg']);
    });

    test(
      'composes title, body, meta line and tags; location off by default',
      () {
        final text = _content().composeText(
          DiaryShareOptions.defaults,
          dateLabel: '2026年4月3日周五',
        );
        expect(text, '春日小记\n\n今天去看花。\n\n2026年4月3日周五 · 晴 22°C · 😊\n#旅行 #美食');
      },
    );

    test('formats tags as Weibo topics and honours every toggle', () {
      final content = _content();
      expect(
        content.composeText(
          const DiaryShareOptions(
            includeTitle: false,
            includeDate: false,
            includeMoodWeather: false,
            includeLocation: true,
          ),
          dateLabel: 'ignored',
          tagStyle: DiaryShareTagStyle.weiboTopic,
        ),
        '今天去看花。\n\n杭州西湖\n#旅行# #美食#',
      );
      expect(
        content.composeText(
          const DiaryShareOptions(
            includeTitle: false,
            includeBody: false,
            includeDate: false,
            includeMoodWeather: false,
            includeTags: false,
          ),
          dateLabel: 'ignored',
        ),
        isEmpty,
      );
    });

    test('treats broken metadata as having no mood, weather or location', () {
      final content = _content(metadata: 'not json', tagNames: const []);
      expect(content.hasMoodWeather, isFalse);
      expect(content.location, isNull);
      expect(
        content.composeText(DiaryShareOptions.defaults, dateLabel: '4月3日'),
        '春日小记\n\n今天去看花。\n\n4月3日',
      );
    });
  });

  group('DiaryShareOptions', () {
    test('round-trips through its raw JSON', () {
      const options = DiaryShareOptions(
        includeTitle: false,
        includeLocation: true,
        includeImages: false,
      );
      expect(DiaryShareOptions.fromRaw(options.toRaw()), options);
    });

    test('falls back per field for missing, mistyped or broken values', () {
      expect(DiaryShareOptions.fromRaw(null), DiaryShareOptions.defaults);
      expect(DiaryShareOptions.fromRaw('{'), DiaryShareOptions.defaults);
      expect(DiaryShareOptions.fromRaw('[1]'), DiaryShareOptions.defaults);
      expect(
        DiaryShareOptions.fromRaw('{"title":false,"tags":"no"}'),
        DiaryShareOptions.defaults.copyWith(includeTitle: false),
      );
    });
  });
}
