import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../notebooks/viewmodels/notebook_tree_rows.dart';
import '../../notebooks/widgets/notebook_foldable_rows.dart';
import '../../notebooks/widgets/notebook_tree_toggle.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';

/// 媒体画廊“日记本图片”里的一项：全部、未收录或某本日记本。
sealed class GalleryNotebookChoice {
  const GalleryNotebookChoice();

  static const GalleryNotebookChoice all = _GalleryAllChoice();
  static const GalleryNotebookChoice unfiled = _GalleryUnfiledChoice();
}

final class _GalleryAllChoice extends GalleryNotebookChoice {
  const _GalleryAllChoice();
}

final class _GalleryUnfiledChoice extends GalleryNotebookChoice {
  const _GalleryUnfiledChoice();
}

/// 某本日记本（业务 id）。
final class GalleryNotebookOf extends GalleryNotebookChoice {
  const GalleryNotebookOf(this.notebookId);

  final String notebookId;

  @override
  bool operator ==(Object other) =>
      other is GalleryNotebookOf && other.notebookId == notebookId;

  @override
  int get hashCode => notebookId.hashCode;
}

/// “日记本图片”二级菜单的内容：全部、未收录，分隔线下按树序列出日记本
/// （子本缩进）。单选，点了不关菜单，对勾当场移过去。
///
/// 有子本的行在对勾格前多一个展开 / 收起箭头（菜单行的独立小按钮，点它不
/// 选这一本），收起的子孙收到 0 高度（[NotebookFoldableRows]，与管理页共用
/// 收起状态）；当前选中的本子所在的上级打开时按展开排。
///
/// 二级菜单的内容在打开时取定、外面重建不会刷新，所以选中项由这里自己记着。
class GalleryNotebookFilterMenu extends StatefulWidget {
  const GalleryNotebookFilterMenu({
    super.key,
    required this.rows,
    required this.selected,
    required this.onSelected,
  });

  /// 可选的日记本（调用方已排除上锁的本子）。
  final List<NotebookTreeRow> rows;
  final GalleryNotebookChoice selected;
  final ValueChanged<GalleryNotebookChoice> onSelected;

  @override
  State<GalleryNotebookFilterMenu> createState() =>
      _GalleryNotebookFilterMenuState();
}

class _GalleryNotebookFilterMenuState extends State<GalleryNotebookFilterMenu> {
  /// 菜单里每深一层的缩进（菜单行比列表行紧凑，小于列表的 20）。
  static const double _indentStep = 16;

  late GalleryNotebookChoice _selected = widget.selected;

  void _select(GalleryNotebookChoice choice) {
    if (_selected == choice) return;
    setState(() => _selected = choice);
    widget.onSelected(choice);
  }

  Widget _item(
    GalleryNotebookChoice choice,
    Widget child, {
    Widget? icon,
    NotebookRowToggle? toggle,
  }) {
    return ExpressiveMenuItem(
      closeOnActivate: false,
      selected: _selected == choice,
      leadingIcon: icon,
      onPressed: () => _select(choice),
      secondary: toggle == null
          ? null
          : NotebookTreeChevron(expanded: toggle.expanded),
      onSecondaryPressed: toggle?.onToggle,
      secondaryLabel: toggle == null
          ? null
          : toggle.expanded
          ? context.l10n.notebookSubCollapse
          : context.l10n.notebookSubExpand,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListBody(
      children: <Widget>[
        _item(GalleryNotebookChoice.all, Text(l10n.exploreGalleryNotebookAll)),
        _item(
          GalleryNotebookChoice.unfiled,
          Text(l10n.exploreGalleryNotebookUnfiled),
        ),
        if (widget.rows.isNotEmpty) ...<Widget>[
          const ExpressiveMenuDivider(),
          NotebookFoldableRows(
            rows: widget.rows,
            reveal: <String>{
              if (widget.selected case GalleryNotebookOf(:final notebookId))
                notebookId,
            },
            // 缩进整行内容（图标与名称一起）：缩进放进 22 的图标格里会把
            // 图标挤到文字上。行尾的箭头与对勾不缩进，上下对齐成一列；面板
            // 按纵向范围认行，缩进那一段照样点得到。
            itemBuilder: (context, row, toggle) => Padding(
              padding: EdgeInsetsDirectional.only(
                start: _indentStep * row.indent,
              ),
              child: _item(
                GalleryNotebookOf(row.notebook.id),
                Text(
                  row.notebook.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                icon: FaIcon(row.notebook.icon.data),
                toggle: toggle,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// “排序”二级菜单的内容：最新在前（默认）/ 最早在前，单选，点了不关菜单。
class GallerySortMenu extends StatefulWidget {
  const GallerySortMenu({
    super.key,
    required this.newestFirst,
    required this.onChanged,
  });

  final bool newestFirst;
  final ValueChanged<bool> onChanged;

  @override
  State<GallerySortMenu> createState() => _GallerySortMenuState();
}

class _GallerySortMenuState extends State<GallerySortMenu> {
  late bool _newestFirst = widget.newestFirst;

  void _select(bool newestFirst) {
    if (_newestFirst == newestFirst) return;
    setState(() => _newestFirst = newestFirst);
    widget.onChanged(newestFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListBody(
      children: <Widget>[
        ExpressiveMenuItem(
          closeOnActivate: false,
          selected: _newestFirst,
          onPressed: () => _select(true),
          child: Text(l10n.exploreGallerySortNewest),
        ),
        ExpressiveMenuItem(
          closeOnActivate: false,
          selected: !_newestFirst,
          onPressed: () => _select(false),
          child: Text(l10n.exploreGallerySortOldest),
        ),
      ],
    );
  }
}
