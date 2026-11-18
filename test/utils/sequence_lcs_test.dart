import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/utils/sequence_lcs.dart';

/// 最长公共子序列：配对按顺序、两边都相等，长度与动态规划的结果相同；
/// 差得太多时只配开头与结尾。
void main() {
  int lcsLength(List<int> a, List<int> b) {
    final table = List.generate(
      a.length + 1,
      (_) => List.filled(b.length + 1, 0),
    );
    for (var i = a.length - 1; i >= 0; i--) {
      for (var j = b.length - 1; j >= 0; j--) {
        table[i][j] = a[i] == b[j]
            ? table[i + 1][j + 1] + 1
            : (table[i + 1][j] > table[i][j + 1]
                  ? table[i + 1][j]
                  : table[i][j + 1]);
      }
    }
    return table[0][0];
  }

  void check(String a, String b) {
    final x = a.codeUnits;
    final y = b.codeUnits;
    final pairs = longestCommonSubsequence(x, y);
    expect(pairs, hasLength(lcsLength(x, y)), reason: '$a / $b');
    var previous = (-1, -1);
    for (final pair in pairs) {
      expect(x[pair.$1], y[pair.$2]);
      expect(pair.$1, greaterThan(previous.$1));
      expect(pair.$2, greaterThan(previous.$2));
      previous = pair;
    }
  }

  test('pairs are ordered, equal and as many as possible', () {
    for (final (a, b) in const [
      ('', ''),
      ('abc', ''),
      ('', 'abc'),
      ('abc', 'abc'),
      ('abcabba', 'cbabac'),
      ('今天去了公园', '昨天去了海边公园'),
      ('xaxbxcx', 'abc'),
      ('aaaa', 'aa'),
      ('kitten', 'sitting'),
    ]) {
      check(a, b);
    }
  });

  test('works on any comparable items', () {
    expect(longestCommonSubsequence(['一', '二', '三'], ['一', '四', '三']), [
      (0, 0),
      (2, 2),
    ]);
  });

  test('gives up on the middle when it differs too much', () {
    final pairs = longestCommonSubsequence(
      'head${'a' * 50}tail'.codeUnits,
      'head${'b' * 50}tail'.codeUnits,
      maxEdits: 10,
    );
    expect(pairs, [
      for (var i = 0; i < 4; i++) (i, i),
      for (var i = 0; i < 4; i++) (54 + i, 54 + i),
    ]);
  });
}
