import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../models/notebook_icon.dart';

/// 界面用的日记本：数据库行 + 解析好的 payload 与枚举。
///
/// 只在 provider 里由行转换一次，书架、管理页、编辑页与各类选择器都读它，
/// 组件不自己解析 JSON（`parsedPayload` 每次调用都会重新解码）。
@immutable
class NotebookView {
  NotebookView(this.row)
    : payload = row.parsedPayload,
      kind = row.notebookKind,
      visibility = row.notebookVisibility;

  final NotebookRow row;
  final NotebookPayload payload;
  final NotebookKind kind;
  final NotebookVisibility visibility;

  /// 业务 id（`notebookId`）。
  String get id => row.notebookId;
  String get name => row.name;
  bool get isPinned => row.isPinned;
  bool get isClosed => row.isClosed;
  bool get isSmart => kind == NotebookKind.smart;

  /// 是否接受手动收录（只认列里的原始值，见 `acceptsManualEntries`）。
  bool get isManual => row.acceptsManualEntries;

  NotebookIcon get icon => NotebookIcon.fromName(payload.icon);

  /// 强调色种子（ARGB）；null 跟随主题色。
  int? get color => payload.color;
  String? get coverPath => payload.coverPath;

  @override
  bool operator ==(Object other) => other is NotebookView && other.row == row;

  @override
  int get hashCode => row.hashCode;
}

/// 书架与管理页共用的分组：每组保持书架顺序（置顶在前，再按手动顺序）。
@immutable
class NotebookShelfGroups {
  NotebookShelfGroups(List<NotebookView> notebooks)
    : pinned = List<NotebookView>.unmodifiable(
        notebooks.where((n) => n.isPinned && !n.isClosed),
      ),
      manual = List<NotebookView>.unmodifiable(
        notebooks.where((n) => !n.isSmart && !n.isClosed),
      ),
      smart = List<NotebookView>.unmodifiable(
        notebooks.where((n) => n.isSmart && !n.isClosed),
      ),
      closed = List<NotebookView>.unmodifiable(
        notebooks.where((n) => n.isClosed),
      );

  /// 置顶且没合上的（书架“置顶”分组）。
  final List<NotebookView> pinned;

  /// 没合上的普通日记本，含置顶的（管理页“我的日记本”）。
  final List<NotebookView> manual;

  /// 没合上的智能日记本，含置顶的。
  final List<NotebookView> smart;

  /// 已合上的（不论类型、是否置顶）。
  final List<NotebookView> closed;

  /// 书架“我的日记本”：没置顶、没合上的普通日记本（置顶的已在上面单列）。
  List<NotebookView> get shelfManual =>
      manual.where((n) => !n.isPinned).toList(growable: false);

  /// 书架“智能日记本”：没置顶的（置顶的同样已在上面单列）。
  List<NotebookView> get shelfSmart =>
      smart.where((n) => !n.isPinned).toList(growable: false);
}
