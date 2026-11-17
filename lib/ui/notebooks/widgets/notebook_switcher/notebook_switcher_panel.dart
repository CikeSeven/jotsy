import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../controllers/notebook_switcher_controller.dart';
import '../../pages/notebook_editor_page.dart';
import '../../pages/notebooks_page.dart';
import '../../viewmodels/notebook_deck_entries.dart';
import '../../viewmodels/notebook_deck_layout.dart';
import 'notebook_deck.dart';

/// 卡组面板的内容：顶栏（标题、新建、管理）与卡组，按面板的最终尺寸排版
/// （打开途中由容器裁切露出，不逐帧重排）。
///
/// 面板自带 [ScaffoldMessenger]：长按菜单里删除日记本的撤销提示条显示在
/// 面板里（面板与遮罩盖住了首页，提示条在首页上点不到）。
class NotebookSwitcherPanel extends StatelessWidget {
  const NotebookSwitcherPanel({
    super.key,
    required this.entries,
    required this.layout,
    required this.controller,
    required this.reveal,
    required this.viewportHeight,
    required this.isCurrent,
    required this.onToggle,
  });

  final List<NotebookDeckEntry> entries;
  final NotebookDeckLayout layout;
  final NotebookSwitcherController controller;
  final ValueListenable<double> reveal;
  final double viewportHeight;
  final bool Function(NotebookDeckEntry entry) isCurrent;
  final ValueChanged<NotebookDeckEntry> onToggle;

  static const double headerHeight = 56;

  /// 卡组左右与面板边缘的间距。
  static const double deckPadding = 12;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeLeft: true,
      removeTop: true,
      removeRight: true,
      removeBottom: true,
      child: ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: headerHeight,
                child: _Header(reveal: reveal),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: deckPadding),
                  child: NotebookDeck(
                    entries: entries,
                    layout: layout,
                    controller: controller,
                    reveal: reveal,
                    viewportHeight: viewportHeight,
                    isCurrent: isCurrent,
                    onToggle: onToggle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 顶栏：标题 + 新建 + 管理。随卡组长出在 0.25–0.7 之间从行首淡入。
class _Header extends StatelessWidget {
  const _Header({required this.reveal});

  final ValueListenable<double> reveal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final sign = Directionality.of(context) == TextDirection.ltr ? 1.0 : -1.0;
    final content = Padding(
      padding: const EdgeInsetsDirectional.only(start: 20, end: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              l10n.notebookTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.notebookNew,
            icon: FaIcon(
              FontAwesomeIcons.plus,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            onPressed: () => unawaited(
              Navigator.of(context).push(NotebookEditorPage.route()),
            ),
          ),
          IconButton(
            tooltip: l10n.notebookManage,
            icon: FaIcon(
              FontAwesomeIcons.sliders,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            onPressed: () => unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => const NotebooksPage(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return ValueListenableBuilder<double>(
      valueListenable: reveal,
      child: content,
      builder: (BuildContext context, double value, Widget? child) {
        final t = Curves.easeOutCubic.transform(
          ((value - 0.25) / 0.45).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(-12 * (1 - t) * sign, 0),
            child: child,
          ),
        );
      },
    );
  }
}
