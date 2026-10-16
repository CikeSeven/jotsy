import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/style_library/saved_style.dart';
import 'package:node_diary/ui/diaries/models/style_library/style_code.dart';

/// 通用样式库：保存项列表操作与按 scheme 区分的样式码。
void main() {
  StyleCodeFormat<Map<String, Object?>> format(String scheme) =>
      StyleCodeFormat<Map<String, Object?>>(
        scheme: scheme,
        version: 1,
        fromJson: (Object? json) => Map<String, Object?>.from(json! as Map),
        toJson: (Map<String, Object?> style) => style,
      );

  test('a style code only decodes under its own scheme', () {
    final cards = format('jotsy-card');
    final reader = format('jotsy-reader');
    final code = cards.encode(<String, Object?>{'a': 1}, name: '海边');

    final decoded = cards.decode('看看这个：$code 好用');
    expect(decoded.status, StyleCodeStatus.ok);
    expect(decoded.style, <String, Object?>{'a': 1});
    expect(decoded.name, '海边');

    expect(reader.decode(code).status, StyleCodeStatus.invalid);
    expect(reader.decode('  ').status, StyleCodeStatus.empty);
  });

  test('saved style lists cap, rename, remove and restore in place', () {
    var saved = const <SavedStyle<int>>[];
    for (var i = 0; i < SavedStyles.maxItems; i++) {
      saved = SavedStyles.add(saved, '样式 $i', i, now: DateTime(2026, 1, 1))!;
    }
    // 同一时间戳生成的 id 仍各不相同。
    expect(saved.map((item) => item.id).toSet(), hasLength(saved.length));
    expect(SavedStyles.add(saved, '再来一个', 99), isNull);

    final renamed = SavedStyles.rename(saved, saved[3].id, '  新   名字 ')!;
    expect(renamed[3].name, '新 名字');
    expect(SavedStyles.rename(saved, saved[3].id, '   '), isNull);

    final removed = SavedStyles.remove(saved, saved[3].id);
    expect(removed, hasLength(SavedStyles.maxItems - 1));
    final restored = SavedStyles.restore(removed, saved[3], 3)!;
    expect(restored, saved);
    expect(SavedStyles.restore(saved, saved[3], 3), isNull);

    expect(SavedStyles.matching(saved, 5)?.name, '样式 5');
    expect(
      SavedStyles.decode(
        SavedStyles.encode(saved, (int style) => style),
        (Object? json) => json! as int,
      ),
      saved,
    );
  });
}
