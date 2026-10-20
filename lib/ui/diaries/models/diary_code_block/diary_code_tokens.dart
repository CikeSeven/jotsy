import 'package:flutter/foundation.dart';
import 'package:highlight/highlight_core.dart';

import 'diary_code_theme.dart';

// 高亮结果的 UTF-16 区间模型，以及 highlight 节点树到区间的无损转换。
// 只计算偏移与角色，不解析语言、不缓存，也不依赖编辑器节点。
//
// 叶子依次拼接等于解析输入（HTML 转义只在库的 toHtml 中发生）。最内层的
// 着色角色覆盖外层，subst 等无角色节点继承；class/function 声明包装只提供
// 上下文，class 里的 title 归为类型名，避免括号与声明空白被涂成函数色。

/// 一段需要着色的区间 `[start, end)`。
@immutable
class DiaryCodeToken {
  const DiaryCodeToken(this.start, this.end, this.role);

  final int start;
  final int end;
  final DiaryCodeTokenRole role;

  @override
  bool operator ==(Object other) =>
      other is DiaryCodeToken &&
      other.start == start &&
      other.end == end &&
      other.role == role;

  @override
  int get hashCode => Object.hash(start, end, role);

  @override
  String toString() => 'DiaryCodeToken($start, $end, ${role.name})';
}

/// 一段文本的高亮结果。
@immutable
class DiaryCodeTokens {
  const DiaryCodeTokens(this.tokens, {this.hasFullContext = true});

  /// 不高亮（纯文本）。
  static const DiaryCodeTokens empty = DiaryCodeTokens(<DiaryCodeToken>[]);

  /// 按起点排好、互不重叠，只含着色区间；区间之间的空隙按正文色显示。
  final List<DiaryCodeToken> tokens;

  /// 逐行容错结果不能作为增量解析的基准：单行与整块的匹配上下文不同，
  /// 拼接窗口可能认出原本不会识别的跨换行记号，必须先恢复整块解析。
  final bool hasFullContext;

  bool get isEmpty => tokens.isEmpty;

  /// 与 `[start, end)` 相交的区间（二分查找起点）。
  Iterable<DiaryCodeToken> overlapping(int start, int end) sync* {
    if (start >= end) {
      return;
    }
    var low = 0;
    var high = tokens.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (tokens[mid].end <= start) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    for (var i = low; i < tokens.length && tokens[i].start < end; i++) {
      yield tokens[i];
    }
  }
}

/// 把 highlight 的节点树展平为着色区间。
class DiaryCodeTokenFlattener {
  /// [offset] 从这段文本在原文中的起点开始（逐行回退时为行首）。
  DiaryCodeTokenFlattener(this.offset);

  final List<DiaryCodeToken> tokens = [];
  final StringBuffer source = StringBuffer();
  int offset;

  /// [inherited]：外层节点的角色；[inClass]：是否在 `class` 声明包装内。
  void walk(List<Node> nodes, DiaryCodeTokenRole? inherited, bool inClass) {
    for (final node in nodes) {
      var role = inherited;
      var childInClass = inClass;
      final className = node.className;
      // noPrefix 节点是子语言的包装（className 为语言名，如 xml 里的
      // css），不代表记号，直接继承外层。
      if (className != null && className.isNotEmpty && !node.noPrefix) {
        if (className == 'class') {
          childInClass = true;
        } else if (className == 'function') {
          childInClass = false;
        } else {
          final own = diaryCodeTokenRoleFor(className);
          if (own == DiaryCodeTokenRole.function &&
              inClass &&
              className.startsWith('title')) {
            role = DiaryCodeTokenRole.type;
          } else if (own != null) {
            role = own;
          }
        }
      }
      final value = node.value;
      if (value != null) {
        _emit(value, role);
      }
      final children = node.children;
      if (children != null) {
        walk(children, role, childInClass);
      }
    }
  }

  void _emit(String value, DiaryCodeTokenRole? role) {
    if (value.isEmpty) {
      return;
    }
    final start = offset;
    offset += value.length;
    source.write(value);
    if (role == null) {
      return;
    }
    if (tokens.isNotEmpty) {
      final last = tokens.last;
      if (last.end == start && last.role == role) {
        tokens[tokens.length - 1] = DiaryCodeToken(last.start, offset, role);
        return;
      }
    }
    tokens.add(DiaryCodeToken(start, offset, role));
  }
}
