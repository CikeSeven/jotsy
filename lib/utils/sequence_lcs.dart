/// 两个序列的最长公共子序列（Myers O(ND) 差分），返回配上的下标对。
///
/// 用途：智能体改日记正文时，按行对照改动前后（没动的行原样保留），以及
/// 宽松匹配时把模型没改的字换回原文的写法（`ai_diary_markdown_edit.dart`）。
///
/// - 先去掉相同的开头与结尾，只对中间做差分；
/// - 差分步数超过 [maxEdits] 时放弃中间部分（只配上开头与结尾）：两段几乎
///   完全不同时省下 O(ND) 的时间与轨迹内存，调用方把中间当作整段替换即可；
/// - 轨迹每步只存用得到的对角线窗口（第 d 步 2d−1 个），内存 O(D²)。
library;

/// [a] 与 [b] 的公共子序列，按顺序给出配对 `(a 的下标, b 的下标)`。
List<(int, int)> longestCommonSubsequence<T>(
  List<T> a,
  List<T> b, {
  int maxEdits = 2000,
}) {
  var start = 0;
  while (start < a.length && start < b.length && a[start] == b[start]) {
    start++;
  }
  var endA = a.length;
  var endB = b.length;
  while (endA > start && endB > start && a[endA - 1] == b[endB - 1]) {
    endA--;
    endB--;
  }
  return <(int, int)>[
    for (var i = 0; i < start; i++) (i, i),
    ..._myers(a, b, start, endA - start, endB - start, maxEdits),
    for (var i = 0; i < a.length - endA; i++) (endA + i, endB + i),
  ];
}

/// `a[offset, offset + n)` 与 `b[offset, offset + m)` 的公共子序列；步数超过
/// [maxEdits] 时为空。
List<(int, int)> _myers<T>(
  List<T> a,
  List<T> b,
  int offset,
  int n,
  int m,
  int maxEdits,
) {
  if (n == 0 || m == 0) return const [];
  final max = n + m;
  // v[k + max]：第 d 步时对角线 k（x − y）上走得最远的 x。
  final v = List<int>.filled(2 * max + 2, 0);
  // trace[d]：第 d 步开始前（第 d − 1 步之后）对角线 −(d−1)…d−1 上的 v。
  final trace = <List<int>>[];
  for (var d = 0; d <= max && d <= maxEdits; d++) {
    trace.add([for (var k = -(d - 1); k <= d - 1; k++) v[k + max]]);
    for (var k = -d; k <= d; k += 2) {
      final down = k == -d || (k != d && v[k - 1 + max] < v[k + 1 + max]);
      var x = down ? v[k + 1 + max] : v[k - 1 + max] + 1;
      var y = x - k;
      while (x < n && y < m && a[offset + x] == b[offset + y]) {
        x++;
        y++;
      }
      v[k + max] = x;
      if (x >= n && y >= m) return _backtrack(trace, d, n, m, offset);
    }
  }
  return const [];
}

List<(int, int)> _backtrack(
  List<List<int>> trace,
  int steps,
  int n,
  int m,
  int offset,
) {
  final pairs = <(int, int)>[];
  var x = n;
  var y = m;
  for (var d = steps; d > 0; d--) {
    final window = trace[d];
    int at(int k) => window[k + d - 1];
    final k = x - y;
    final previousK = k == -d || (k != d && at(k - 1) < at(k + 1))
        ? k + 1
        : k - 1;
    final previousX = at(previousK);
    final previousY = previousX - previousK;
    while (x > previousX && y > previousY) {
      x--;
      y--;
      pairs.add((offset + x, offset + y));
    }
    x = previousX;
    y = previousY;
  }
  while (x > 0 && y > 0) {
    x--;
    y--;
    pairs.add((offset + x, offset + y));
  }
  return pairs.reversed.toList();
}
