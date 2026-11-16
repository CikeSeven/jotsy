/// 导图的结构、连线、间距、节点形状与字号档位（文档里只存 id 原文）。
///
/// 每个枚举都有 [id] 与容错的 `resolve`：认不出的 id（更新的版本写出的）
/// 按缺省显示，但文档里的原文不改写（见 mind_map_document.dart）。
library;

/// 导图结构（布局方式）。
enum MindMapStructure {
  /// 思维导图：根在中间，分支左右平衡。
  mindMap('mind_map'),

  /// 逻辑图：向右展开。
  logicRight('logic_right'),

  /// 左向逻辑图。
  logicLeft('logic_left'),

  /// 组织结构图：向下展开。
  orgDown('org_down'),

  /// 树形目录：缩进式，向右下展开。
  treeRight('tree_right'),

  /// 时间线：一级主题排在一条横轴上。
  timeline('timeline'),

  /// 鱼骨图：鱼头在右。
  fishbone('fishbone');

  const MindMapStructure(this.id);

  final String id;

  static const MindMapStructure fallback = MindMapStructure.mindMap;

  static MindMapStructure resolve(String? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return fallback;
  }
}

/// 连线样式。
enum MindMapLineStyle {
  /// 曲线：三次贝塞尔，根部较粗、逐级变细。
  curve('curve'),

  /// 直线。
  straight('straight'),

  /// 直角折线。
  elbow('elbow'),

  /// 圆角折线。
  rounded('rounded');

  const MindMapLineStyle(this.id);

  final String id;

  /// 文档没有指定时为 null（跟随主题与结构的缺省）。
  static MindMapLineStyle? tryResolve(String? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }
}

/// 节点间距档位。
enum MindMapSpacing {
  compact('compact', 0.72),
  standard('standard', 1),
  loose('loose', 1.38);

  const MindMapSpacing(this.id, this.factor);

  final String id;

  /// 各档间距相对标准档的倍数。
  final double factor;

  static MindMapSpacing resolve(String? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return MindMapSpacing.standard;
  }
}

/// 节点外形。
enum MindMapNodeShape {
  /// 圆角矩形。
  rounded('rounded'),

  /// 胶囊。
  pill('pill'),

  /// 小圆角矩形。
  rect('rect'),

  /// 椭圆。
  ellipse('ellipse'),

  /// 只有一条下划线（文字之下与连线相接）。
  underline('underline'),

  /// 只有文字。
  plain('plain');

  const MindMapNodeShape(this.id);

  final String id;

  /// 是否画成闭合的框（有填充或描边）。
  bool get boxed =>
      this != MindMapNodeShape.underline && this != MindMapNodeShape.plain;

  static MindMapNodeShape? tryResolve(Object? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }
}

/// 节点字号档位（相对该层级的缺省字号）。
enum MindMapTextSize {
  small('s', 0.86),
  medium('m', 1),
  large('l', 1.2),
  huge('xl', 1.45);

  const MindMapTextSize(this.id, this.scale);

  final String id;
  final double scale;

  static MindMapTextSize resolve(Object? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return MindMapTextSize.medium;
  }
}
