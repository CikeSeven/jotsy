import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/style_library/saved_style.dart';
import '../../../home/widgets/home_hint_visibility_scope.dart';
import '../../../widgets/app_modal/app_dialog.dart';
import '../../controllers/style_draft_controller.dart';

// 样式编辑页（卡片样式、预览页样式、代码块样式）各标签页共用的外壳、预览
// 明暗按钮、撤销提示与命名对话框。

/// 预览工具条右端的明暗切换：只换预览的明暗（[StyleDraftController.
/// previewBrightness]），不改应用主题；图标显示点按后会切到的那一种。
class StylePreviewBrightnessButton extends StatelessWidget {
  const StylePreviewBrightnessButton({
    super.key,
    required this.controller,
    this.inAppBar = false,
  });

  final StyleDraftController<Object?, Object?> controller;

  /// 放在标题栏里（`StyleEditorScaffold.actionsBuilder`）：用标题栏的普通
  /// 图标按钮，图标 18 与返回键一致；否则是预览工具条上的色调按钮。
  final bool inAppBar;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brightness =
        controller.previewBrightness ?? Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;
    final tooltip = isLight
        ? l10n.styleEditorPreviewDark
        : l10n.styleEditorPreviewLight;
    void toggle() => controller.previewBrightness = isLight
        ? Brightness.dark
        : Brightness.light;
    final icon = isLight ? FontAwesomeIcons.moon : FontAwesomeIcons.sun;
    if (inAppBar) {
      return IconButton(
        tooltip: tooltip,
        onPressed: toggle,
        icon: FaIcon(icon, size: 18),
      );
    }
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: toggle,
      icon: FaIcon(icon, size: 16),
    );
  }
}

/// 标签页内容：分组卡片之间留 16 的竖向间距，底部让出系统手势区。
class StyleEditorTabList extends StatelessWidget {
  const StyleEditorTabList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(0, 16, 0, 24 + bottomInset),
      children: <Widget>[
        for (var i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 16),
          children[i],
        ],
      ],
    );
  }
}

/// 可撤销的操作提示（套用、重置、导入、删除）。经
/// [HomeHintVisibilityScope.showTrackedSnackBar] 展示，`persist: false` 让它
/// 到时关闭（读屏等场景也一样），与日记列表的撤销提示一致。
Future<void> showStyleEditorUndoSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) async {
  const duration = Duration(seconds: 4);
  var undone = false;
  final reason = await HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(
      content: Text(message),
      duration: duration,
      persist: false,
      action: SnackBarAction(
        label: context.l10n.commonUndo,
        onPressed: () {
          undone = true;
        },
      ),
    ),
  );
  if (undone || reason == SnackBarClosedReason.action) {
    onUndo();
  }
}

/// 普通提示（复制成功、导入失败等）。
void showStyleEditorMessage(BuildContext context, String message) {
  HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(content: Text(message)),
  );
}

/// 输入样式名称；取消或名字为空时返回 null。
Future<String?> showStyleEditorNameDialog(
  BuildContext context, {
  required String title,
  required String initialName,
}) {
  return showAppDialog<String>(
    context: context,
    builder: (BuildContext context) =>
        _StyleNameDialog(title: title, initialName: initialName),
  );
}

/// 命名对话框：TextField 的 controller 跟随对话框生命周期释放，关闭动画期间
/// 仍可能重建，不能在 showDialog 返回后立刻 dispose。
class _StyleNameDialog extends StatefulWidget {
  const _StyleNameDialog({required this.title, required this.initialName});

  final String title;
  final String initialName;

  @override
  State<_StyleNameDialog> createState() => _StyleNameDialogState();
}

class _StyleNameDialogState extends State<_StyleNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initialName.length,
        );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = SavedStyles.normalizeName(_controller.text);
    if (name.isEmpty) {
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: SavedStyles.maxNameLength,
        decoration: InputDecoration(labelText: l10n.styleEditorNameLabel),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurfaceVariant,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
          onPressed: _submit,
          child: Text(l10n.commonConfirm),
        ),
      ],
    );
  }
}
