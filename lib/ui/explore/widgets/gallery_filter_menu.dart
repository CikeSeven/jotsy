import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../notebooks/viewmodels/notebook_tree_rows.dart';
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
  late GalleryNotebookChoice _selected = widget.selected;

  void _select(GalleryNotebookChoice choice) {
    if (_selected == choice) return;
    setState(() => _selected = choice);
    widget.onSelected(choice);
  }

  Widget _item(GalleryNotebookChoice choice, Widget child, {Widget? icon}) {
    return ExpressiveMenuItem(
      closeOnActivate: false,
      selected: _selected == choice,
      leadingIcon: icon,
      onPressed: () => _select(choice),
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
        if (widget.rows.isNotEmpty) const ExpressiveMenuDivider(),
        for (final row in widget.rows)
          _item(
            GalleryNotebookOf(row.notebook.id),
            Text(
              row.notebook.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            icon: Padding(
              padding: EdgeInsetsDirectional.only(start: 12.0 * row.indent),
              child: FaIcon(row.notebook.icon.data),
            ),
          ),
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
