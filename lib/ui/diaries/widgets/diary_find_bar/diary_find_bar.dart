import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/app_breakpoints.dart';
import '../../../../app/theme/expressive_motion.dart';
import '../../../../app/theme/expressive_surfaces.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_glass_scope.dart';
import '../../../app_surface/widgets/app_glass_surface.dart';
import '../../../app_surface/widgets/app_page_backdrop.dart';
import '../../../widgets/search_pill_field.dart';
import '../../controllers/diary_find_replace.dart';
import 'diary_find_bar_rows.dart';

/// 编辑页的查找栏：打开查找与替换时顶栏换成它（`Scaffold.appBar`），关掉
/// 换回原来的顶栏。只做界面，查找、跳转与替换都经 [DiaryFindReplace]。
///
/// 版式同搜索页顶栏（DESIGN.md §5.33 / §5.6）：
/// - 第一行：返回（关闭查找）+ 胶囊查找框（行尾“第几处 / 共几处”、没有
///   结果或正则写错时换成提示）+ 上一个 / 下一个；
/// - 第二行：一排选项胶囊（正则表达式、区分大小写、全词匹配、替换），可
///   横向滚动；
/// - 第三行（点“替换”胶囊展开，`medium` 补间高度）：替换框 + “替换”与
///   “全部替换”。
///
/// 材质与原顶栏一致：顶栏为玻璃时整条是一片玻璃，否则为实色（[background]，
/// 没给时取页面的实色栏底色）。栏高随内容（Scaffold 按实际高度排正文），
/// [preferredSize] 只是上限。
///
/// 焦点：打开时查找框自动取得焦点并全选原有文字；键盘的搜索键跳到下一处、
/// 焦点不离开。桌面上 Shift + Enter 为上一处，F3 / Shift + F3 同下一处 / 上
/// 一处，Esc 经页面的返回链路先关掉查找。页面经 [DiaryFindBarState.focusFind]
/// / [DiaryFindBarState.focusReplace] 把焦点交回来（Ctrl / ⌘ + F、H）。
class DiaryFindBar extends StatefulWidget implements PreferredSizeWidget {
  const DiaryFindBar({
    super.key,
    required this.find,
    required this.onClose,
    required this.onReplacedAll,
    this.focusReplaceOnOpen = false,
    this.background,
  });

  final DiaryFindReplace find;
  final VoidCallback onClose;

  /// 全部替换之后（换掉的处数），页面弹出带撤销的提示条。
  final ValueChanged<int> onReplacedAll;

  /// 打开时焦点给替换框而不是查找框（经替换的快捷键打开）。
  final bool focusReplaceOnOpen;

  /// 经典材质的底色；null 时取页面的实色栏底色。
  final Color? background;

  /// 实际高度的上限（含展开的替换一行与放大字号的余量）。
  @override
  Size get preferredSize => const Size.fromHeight(280);

  @override
  State<DiaryFindBar> createState() => DiaryFindBarState();
}

class DiaryFindBarState extends State<DiaryFindBar> {
  late final TextEditingController _findText = TextEditingController(
    text: widget.find.query.text,
  );
  late final TextEditingController _replaceText = TextEditingController(
    text: widget.find.replacement,
  );
  final FocusNode _findFocus = FocusNode(debugLabel: 'diary-find');
  final FocusNode _replaceFocus = FocusNode(debugLabel: 'diary-replace');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.focusReplaceOnOpen ? focusReplace() : focusFind();
    });
  }

  @override
  void dispose() {
    _findText.dispose();
    _replaceText.dispose();
    _findFocus.dispose();
    _replaceFocus.dispose();
    super.dispose();
  }

  /// 焦点交给查找框并全选：接着打字即换掉原来的查找文字。查找文字由会话
  /// 换过（选中一段正文后再按 Ctrl / ⌘ + F）时先同步过来。
  void focusFind() {
    final text = widget.find.query.text;
    if (_findText.text != text) _findText.text = text;
    _findText.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _findText.text.length,
    );
    _findFocus.requestFocus();
  }

  /// 展开替换一行并把焦点交给替换框。
  void focusReplace() {
    widget.find.setReplaceVisible(true);
    _replaceText.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _replaceText.text.length,
    );
    _replaceFocus.requestFocus();
  }

  void _replaceAll() {
    final count = widget.find.replaceAll();
    if (count > 0) widget.onReplacedAll(count);
  }

  @override
  Widget build(BuildContext context) {
    final glass = AppGlass.of(context);
    final content = SafeArea(
      bottom: false,
      child: CenteredContent(
        maxWidth: AppContentWidth.editor,
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.enter, shift: true):
                widget.find.previous,
            const SingleActivator(LogicalKeyboardKey.f3): widget.find.next,
            const SingleActivator(LogicalKeyboardKey.f3, shift: true):
                widget.find.previous,
          },
          child: ListenableBuilder(
            listenable: widget.find,
            builder: (BuildContext context, Widget? _) => _buildRows(context),
          ),
        ),
      ),
    );
    if (glass.isGlass(AppGlassComponent.topBars)) {
      return AppGlassSurface(
        component: AppGlassComponent.topBars,
        showBorder: false,
        bottomHairline: glass.hairline,
        child: content,
      );
    }
    return ColoredBox(
      color: widget.background ?? AppPageBackdrop.solidBarColorOf(context),
      child: content,
    );
  }

  Widget _buildRows(BuildContext context) {
    final l10n = context.l10n;
    final find = widget.find;
    final scheme = Theme.of(context).colorScheme;
    final fill = scheme.brightness == Brightness.light
        ? ExpressiveSurfaces.cardColor(scheme)
        : scheme.surfaceContainerHigh;
    final outline = ExpressiveSurfaces.cardBorderColor(scheme);
    final hasMatches = find.matches.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(
            children: <Widget>[
              IconButton(
                tooltip: l10n.diaryFindClose,
                onPressed: widget.onClose,
                icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: SearchPillField(
                  key: const ValueKey<String>('diary-find-field'),
                  controller: _findText,
                  focusNode: _findFocus,
                  hintText: l10n.diaryFindHint,
                  fill: fill,
                  idleOutline: outline,
                  keepFocusOnSubmit: true,
                  onChanged: find.setText,
                  onSubmitted: (_) => find.next(),
                  onClear: () {
                    _findText.clear();
                    find.setText('');
                    _findFocus.requestFocus();
                  },
                  trailing: DiaryFindCount(find: find),
                ),
              ),
              IconButton(
                key: const ValueKey<String>('diary-find-previous'),
                tooltip: l10n.diaryFindPrevious,
                onPressed: hasMatches ? find.previous : null,
                icon: const FaIcon(FontAwesomeIcons.angleUp, size: 18),
              ),
              IconButton(
                key: const ValueKey<String>('diary-find-next'),
                tooltip: l10n.diaryFindNext,
                onPressed: hasMatches ? find.next : null,
                icon: const FaIcon(FontAwesomeIcons.angleDown, size: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        DiaryFindOptionsRow(find: find),
        AnimatedSize(
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
          curve: ExpressiveMotion.effects,
          alignment: Alignment.topCenter,
          child: find.replaceVisible
              ? DiaryFindReplaceRow(
                  find: find,
                  controller: _replaceText,
                  focusNode: _replaceFocus,
                  fill: fill,
                  idleOutline: outline,
                  onReplaceAll: _replaceAll,
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
