import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../models/notebook_icon.dart';

/// 界面用的日记本：数据库行 + 解析好的 payload 与枚举，以及它在嵌套结构里
/// 的位置（[parentId]、[depth]、[effectiveVisibility]）。
///
/// 只在 provider 里由行转换一次（经 `NotebookTree`，层级信息随之算好），
/// 书架、管理页、编辑页与各类选择器都读它，组件不自己解析 JSON
/// （`parsedPayload` 每次调用都会重新解码）。单独由一行构造时（不知道其他
/// 本子）按顶层处理：[parentId] 为空、生效可见性只看自己——涉及上锁判断的
/// 地方须从书架列表（`notebookTreeProvider`）取这本。
@immutable
class NotebookView {
  NotebookView(
    this.row, {
    this.parentId,
    this.depth = 1,
    this.hasChildren = false,
    NotebookVisibility? effectiveVisibility,
  }) : payload = row.parsedPayload,
       kind = row.notebookKind,
       visibility = row.notebookVisibility,
       effectiveVisibility =
           effectiveVisibility ??
           (row.acceptsManualEntries
               ? row.notebookVisibility
               : NotebookVisibility.normal);

  final NotebookRow row;
  final NotebookPayload payload;
  final NotebookKind kind;

  /// 本子自己设的可见性（编辑页的“隐私”一项）。
  final NotebookVisibility visibility;

  /// 生效可见性：自己与全部上级里最严格的一档（上级上锁，子本同样要验证）。
  /// 是否要验证、是否算私密都看它，不看 [visibility]。
  final NotebookVisibility effectiveVisibility;

  /// 有效上级的业务 id；顶层为 null（坏链接同样当作顶层，见
  /// `NotebookHierarchy`）。
  final String? parentId;

  /// 层数，顶层为 1。
  final int depth;

  /// 是否有子本。
  final bool hasChildren;

  /// 业务 id（`notebookId`）。
  String get id => row.notebookId;
  String get name => row.name;
  bool get isPinned => row.isPinned;
  bool get isClosed => row.isClosed;
  bool get isSmart => kind == NotebookKind.smart;

  /// 是否接受手动收录（只认列里的原始值，见 `acceptsManualEntries`）。
  bool get isManual => row.acceptsManualEntries;

  /// 生效可见性不是 normal：本子里的日记不出现在全部日记里。
  bool get isPrivate => effectiveVisibility != NotebookVisibility.normal;

  /// 隐私来自上级（自己是 normal、上级私密）。
  bool get inheritsPrivacy =>
      effectiveVisibility != NotebookVisibility.normal &&
      (!isManual || visibility.index < effectiveVisibility.index);

  /// 还能不能在它下面建子本：手动本，且没到最深一层。
  bool get canHaveChildren => isManual && depth < kNotebookMaxDepth;

  /// 封面版式、纹理与取景。
  NotebookCoverStyle get coverStyle => payload.coverStyle;

  NotebookIcon get icon => NotebookIcon.fromName(payload.icon);

  /// 强调色种子（ARGB）；null 跟随主题色。
  int? get color => payload.color;
  String? get coverPath => payload.coverPath;

  @override
  bool operator ==(Object other) =>
      other is NotebookView &&
      other.row == row &&
      other.parentId == parentId &&
      other.depth == depth &&
      other.hasChildren == hasChildren &&
      other.effectiveVisibility == effectiveVisibility;

  @override
  int get hashCode =>
      Object.hash(row, parentId, depth, hasChildren, effectiveVisibility);
}

/// 书架与管理页共用的分组：每组保持书架顺序（置顶在前，再按手动顺序）。
///
/// 分组只看顶层的本子（子本跟着上级，在上级的头部与管理页的树里出现）；
/// 置顶例外：置顶是快捷入口，不论哪一层都列在“置顶”里。
@immutable
class NotebookShelfGroups {
  NotebookShelfGroups(List<NotebookView> notebooks)
    : pinned = List<NotebookView>.unmodifiable(
        notebooks.where((n) => n.isPinned && !n.isClosed),
      ),
      manual = List<NotebookView>.unmodifiable(
        notebooks.where((n) => n.parentId == null && !n.isSmart && !n.isClosed),
      ),
      smart = List<NotebookView>.unmodifiable(
        notebooks.where((n) => n.parentId == null && n.isSmart && !n.isClosed),
      ),
      closed = List<NotebookView>.unmodifiable(
        notebooks.where((n) => n.parentId == null && n.isClosed),
      );

  /// 置顶且没合上的（书架“置顶”分组，不论哪一层）。
  final List<NotebookView> pinned;

  /// 没合上的顶层普通日记本，含置顶的（管理页“我的日记本”）。
  final List<NotebookView> manual;

  /// 没合上的顶层智能日记本，含置顶的。
  final List<NotebookView> smart;

  /// 已合上的顶层日记本（不论类型、是否置顶）。
  final List<NotebookView> closed;

  /// 书架“我的日记本”：没置顶、没合上的顶层普通日记本（置顶的已在上面单列）。
  List<NotebookView> get shelfManual =>
      manual.where((n) => !n.isPinned).toList(growable: false);

  /// 书架“智能日记本”：没置顶的顶层智能本（置顶的同样已在上面单列）。
  List<NotebookView> get shelfSmart =>
      smart.where((n) => !n.isPinned).toList(growable: false);
}
