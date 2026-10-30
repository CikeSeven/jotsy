import 'package:flutter/foundation.dart';

import '../../../core/database/diary_blocks/diary_link_target.dart';
import '../../notebooks/viewmodels/notebook_view.dart';

/// 正文里能不能插入日记链接，以及插入时排除哪一篇。
///
/// 挂在 [DiaryEditorController.linkSource] 上：编辑页（新建与编辑）给出，
/// 模板编辑页与只读正文不给（模板白名单本就会丢掉日记链接，不让它出现在
/// 候选里）。[diaryId] 为正在编辑的这篇（新建时为 null），不出现在候选里。
@immutable
class DiaryLinkSource {
  const DiaryLinkSource({this.diaryId});

  final String? diaryId;
}

/// `@` 菜单与链接对话框里的一个候选。
///
/// [label] 是插入正文的链接文字与卡片的标题快照（见 `diaryLinkLabel`）；
/// 日记带写下的时间与缩略图来源（未解封的胶囊不带），日记本带书架上的那一份
/// （小封面）。
@immutable
class DiaryLinkCandidate {
  const DiaryLinkCandidate.diary({
    required this.target,
    required this.label,
    required DateTime this.createdAt,
    this.cover,
    this.sealed = false,
  }) : notebook = null;

  DiaryLinkCandidate.notebook(NotebookView this.notebook)
    : target = DiaryLinkTarget.notebook(notebook.id),
      label = notebook.name,
      createdAt = null,
      cover = null,
      sealed = false;

  final DiaryLinkTarget target;
  final String label;
  final DateTime? createdAt;

  /// 缩略图来源（正文图片或封面路径）；没有图或未解封时为 null。
  final String? cover;

  /// 未解封的时间胶囊：只显示标题与日期。
  final bool sealed;
  final NotebookView? notebook;

  DiaryLinkKind get kind => target.kind;
}
