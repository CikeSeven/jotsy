import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/models/tag_picker_sort.dart';
import 'package:node_diary/ui/diaries/viewmodels/tag_picker_view.dart';

List<Tag> _tags(List<String> names) => <Tag>[
  for (var i = 0; i < names.length; i++)
    Tag(id: i + 1, name: names[i], color: 0xff2196f3),
];

List<String?> _letters(TagPickerView view) => <String?>[
  for (final section in view.sections) section.letter,
];

List<String> _names(TagPickerView view) => <String>[
  for (final section in view.sections)
    for (final tag in section.tags) tag.name,
];

/// 标签子页的显示数据：检索筛选、默认顺序或按字母分组、能否以检索词新建。
void main() {
  final tags = _tags(['生活', 'Work', '爱好', '2024', '摄影']);

  test('the default order keeps the given order in one untitled group', () {
    final view = TagPickerView.of(tags, sort: TagPickerSort.custom, query: '');
    expect(_letters(view), [null]);
    expect(_names(view), ['生活', 'Work', '爱好', '2024', '摄影']);
    expect(view.letters, isEmpty);
    expect(view.createName, isNull);
  });

  test('alphabetical groups by letter and keeps # last', () {
    final view = TagPickerView.of(
      tags,
      sort: TagPickerSort.alphabetical,
      query: '',
    );
    expect(view.letters, ['A', 'S', 'W', '#']);
    expect(_names(view), ['爱好', '摄影', '生活', 'Work', '2024']);
  });

  test('a search filters within the chosen order', () {
    final custom = TagPickerView.of(
      tags,
      sort: TagPickerSort.custom,
      query: ' sh ',
    );
    expect(custom.query, 'sh');
    expect(_names(custom), ['生活', '摄影']);

    final alphabetical = TagPickerView.of(
      tags,
      sort: TagPickerSort.alphabetical,
      query: 'sh',
    );
    expect(_names(alphabetical), ['摄影', '生活']);
    expect(alphabetical.letters, ['S']);
  });

  test('a new name can be created only when no tag has it already', () {
    final missing = TagPickerView.of(
      tags,
      sort: TagPickerSort.custom,
      query: '跑步',
    );
    expect(missing.isEmpty, isTrue);
    expect(missing.createName, '跑步');

    // 同名（忽略大小写与全角）时不提议新建，但仍列出匹配的标签。
    for (final query in ['work', 'ＷＯＲＫ']) {
      final existing = TagPickerView.of(
        tags,
        sort: TagPickerSort.custom,
        query: query,
      );
      expect(existing.createName, isNull);
      expect(_names(existing), ['Work']);
    }
  });
}
