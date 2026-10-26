import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_platform.dart';
import '../../../l10n/app_localizations.dart';

/// 编辑页正文的拖放区（桌面）：把系统文件管理器里的文件拖到正文上方时显示
/// 高亮，松开后把文件路径交给 [onDropFiles]（编辑页经媒体导入链路插入光标
/// 处）。
///
/// 输入：[enabled]（保存中、录音面板开着等不接收时为 false）、[onDropFiles]；
/// 输出：[child] 加一层不参与命中测试的高亮，没有其他副作用。手机上原样
/// 返回 [child]。
///
/// 高亮：铺满正文区、与正文列同宽居中（最宽 760）的圆角框——2dp `primary`
/// 描边、`primaryContainer` 12% 底色，中间一行“松开以插入”；显隐淡入淡出
/// （fast / effects，减少动画时直接切换）。高亮是普通的不透明度过渡，不碰
/// 任何玻璃表面。
class DiaryEditorDropTarget extends StatefulWidget {
  const DiaryEditorDropTarget({
    super.key,
    required this.enabled,
    required this.onDropFiles,
    required this.child,
  });

  /// 高亮层（测试据此找到它）。
  static const Key highlightKey = ValueKey<String>(
    'diary_editor_drop_highlight',
  );

  final bool enabled;
  final ValueChanged<List<String>> onDropFiles;
  final Widget child;

  @override
  State<DiaryEditorDropTarget> createState() => DiaryEditorDropTargetState();
}

/// 公开状态只为测试：[debugHover] 模拟拖入 / 拖出，[handleDrop] 模拟松开
/// （原生拖放事件走插件的平台通道，测试里不经过它）。
class DiaryEditorDropTargetState extends State<DiaryEditorDropTarget> {
  bool _hovering = false;

  void _setHovering(bool value) {
    if (_hovering == value || !mounted) return;
    setState(() => _hovering = value);
  }

  @visibleForTesting
  void debugHover(bool value) => _setHovering(value);

  /// 松开：收起高亮，丢掉没有路径的项（如从网页拖来的纯文字），其余交给
  /// [DiaryEditorDropTarget.onDropFiles]。
  void handleDrop(List<String> paths) {
    _setHovering(false);
    if (!widget.enabled) return;
    final files = <String>[
      for (final path in paths)
        if (path.trim().isNotEmpty) path,
    ];
    if (files.isNotEmpty) widget.onDropFiles(files);
  }

  @override
  Widget build(BuildContext context) {
    if (!AppPlatform.isDesktop) return widget.child;
    final showHighlight = _hovering && widget.enabled;
    return DropTarget(
      enable: widget.enabled,
      onDragEntered: (_) => _setHovering(true),
      onDragExited: (_) => _setHovering(false),
      onDragDone: (DropDoneDetails details) =>
          handleDrop(<String>[for (final file in details.files) file.path]),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          widget.child,
          IgnorePointer(
            child: AnimatedOpacity(
              key: DiaryEditorDropTarget.highlightKey,
              opacity: showHighlight ? 1 : 0,
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.fast,
              ),
              curve: ExpressiveMotion.effects,
              child: const _DropHighlight(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropHighlight extends StatelessWidget {
  const _DropHighlight();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return CenteredContent(
      maxWidth: AppContentWidth.editor,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: 0.12),
            border: Border.all(color: colors.primary, width: 2),
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Center(
            child: Text(
              context.l10n.diaryEditorDropToInsert,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
