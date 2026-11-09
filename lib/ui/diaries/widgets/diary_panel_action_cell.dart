import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';

const double _kIconSize = 16;
const double _kIconGap = 4;
const double _kLabelSize = 11;
const double _kCellRadius = 12;

/// 面板里的一格操作（表格面板、段落操作栏的面板共用）：图标在上、短标签
/// 在下（两行以内）；选中时垫 primaryContainer 圆角方块，经
/// [ExpressiveStateBlend] 补间；停用时变淡（38%）；危险操作（删除表格）用
/// 错误色。只是按钮，不请求焦点——面板在工具栏卡片里，抢走焦点会收起
/// 键盘。
class DiaryPanelActionCell extends StatelessWidget {
  const DiaryPanelActionCell({
    super.key,
    required this.icon,
    required this.label,
    required this.enabled,
    this.selected = false,
    this.destructive = false,
    required this.onTap,
  });

  final FaIconData icon;
  final String label;
  final bool enabled;
  final bool selected;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_kCellRadius),
    );
    final base = destructive ? colors.error : colors.onSurface;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: ExpressiveStateBlend(
        active: selected,
        builder: (BuildContext context, double t, Widget? child) {
          final foreground = Color.lerp(
            base,
            colors.onPrimaryContainer,
            t,
          )!.withValues(alpha: enabled ? 1 : 0.38);
          return Material(
            color: colors.primaryContainer.withValues(alpha: t),
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onTap : null,
              customBorder: shape,
              canRequestFocus: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    FaIcon(icon, size: _kIconSize, color: foreground),
                    const SizedBox(height: _kIconGap),
                    Text(
                      label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: _kLabelSize,
                        height: 1.2,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
