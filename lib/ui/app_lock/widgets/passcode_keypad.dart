import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../app_surface/widgets/app_glass_field.dart';

/// 应用内数字键盘（DESIGN.md §5.31）：3×4 圆形键，最下一行左边是可选的
/// [leading]（指纹键），右边是删除键（长按清空）。
///
/// - 数字键：`surfaceContainerHighest` 底（玻璃小控件时为玻璃填充 + 描边，经
///   [AppGlassField]，不模糊），数字用 `headlineMedium`；按下时水波纹并缩到
///   0.92（`fast`），轻触觉 `selectionClick`；
/// - 删除键无底色，没有输入时淡出（仍占位，键位不跳）；
/// - [enabled] 为 false（核对中、等待中）时整块降到 38% 不透明度，不接受点按。
///   键底只是半透明填充、没有模糊，放进 Opacity 不违反玻璃规则。
///
/// 不弹系统键盘：这是锁屏本身的输入方式，不是输入框（与“输入框用普通键盘”
/// 的约定不冲突）。桌面的实体键盘输入由外层 `PasscodeInput` 处理。
class PasscodeKeypad extends StatelessWidget {
  const PasscodeKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.enabled,
    required this.showBackspace,
    this.leading,
    this.keySize = defaultKeySize,
  });

  static const double defaultKeySize = 76;
  static const double minKeySize = 56;

  /// 键与键的横向、纵向间距（随键的大小缩放）。
  static double gapX(double keySize) => keySize * 0.37;
  static double gapY(double keySize) => keySize * 0.21;

  /// 整块键盘的高度。
  static double heightFor(double keySize) => keySize * 4 + gapY(keySize) * 3;

  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final bool enabled;
  final bool showBackspace;
  final Widget? leading;
  final double keySize;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = <List<Widget>>[
      for (final row in const <List<int>>[
        <int>[1, 2, 3],
        <int>[4, 5, 6],
        <int>[7, 8, 9],
      ])
        <Widget>[
          for (final digit in row)
            _DigitKey(
              digit: digit,
              size: keySize,
              onTap: enabled ? () => onDigit(digit) : null,
            ),
        ],
      <Widget>[
        SizedBox.square(dimension: keySize, child: leading),
        _DigitKey(
          digit: 0,
          size: keySize,
          onTap: enabled ? () => onDigit(0) : null,
        ),
        AnimatedOpacity(
          opacity: showBackspace ? 1 : 0,
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
          curve: ExpressiveMotion.effects,
          child: PasscodeIconKey(
            icon: FontAwesomeIcons.deleteLeft,
            size: keySize,
            semanticLabel: l10n.passcodeDelete,
            onTap: enabled && showBackspace ? onBackspace : null,
            onLongPress: enabled && showBackspace ? onClear : null,
          ),
        ),
      ],
    ];
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.38,
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      curve: ExpressiveMotion.effects,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var r = 0; r < rows.length; r++) ...<Widget>[
            if (r > 0) SizedBox(height: gapY(keySize)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var c = 0; c < rows[r].length; c++) ...<Widget>[
                  if (c > 0) SizedBox(width: gapX(keySize)),
                  rows[r][c],
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 圆形数字键。
class _DigitKey extends StatelessWidget {
  const _DigitKey({required this.digit, required this.size, this.onTap});

  final int digit;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final glass = AppGlassField.of(context);
    final style = theme.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w500,
      color: scheme.onSurface,
      fontSize:
          (theme.textTheme.headlineMedium?.fontSize ?? 28) *
          (size / PasscodeKeypad.defaultKeySize),
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    return _PressableKey(
      size: size,
      color: glass?.fill ?? scheme.surfaceContainerHighest,
      side: glass?.border ?? BorderSide.none,
      semanticLabel: '$digit',
      onTap: onTap,
      child: Text('$digit', style: style, textScaler: TextScaler.noScaling),
    );
  }
}

/// 无底色的图标键：删除键、指纹键。
class PasscodeIconKey extends StatelessWidget {
  const PasscodeIconKey({
    super.key,
    required this.icon,
    required this.size,
    required this.semanticLabel,
    this.onTap,
    this.onLongPress,
    this.color,
  });

  final FaIconData icon;
  final double size;
  final String semanticLabel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 图标颜色；默认 `onSurfaceVariant`（指纹键传 `primary`）。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _PressableKey(
      size: size,
      color: scheme.surface.withValues(alpha: 0),
      side: BorderSide.none,
      semanticLabel: semanticLabel,
      onTap: onTap,
      onLongPress: onLongPress,
      child: FaIcon(
        icon,
        size: size * 0.32,
        color: color ?? scheme.onSurfaceVariant,
      ),
    );
  }
}

/// 圆形可点按键：墨水波纹 + 按下缩放 + 触觉。
class _PressableKey extends StatefulWidget {
  const _PressableKey({
    required this.size,
    required this.color,
    required this.side,
    required this.semanticLabel,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  final double size;
  final Color color;
  final BorderSide side;
  final String semanticLabel;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<_PressableKey> createState() => _PressableKeyState();
}

class _PressableKeyState extends State<_PressableKey> {
  bool _pressed = false;

  void _handleTap() {
    HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  void _handleLongPress() {
    HapticFeedback.mediumImpact();
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      excludeSemantics: true,
      onTap: widget.onTap == null ? null : _handleTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
        curve: ExpressiveMotion.effects,
        child: SizedBox.square(
          dimension: widget.size,
          child: Material(
            color: widget.color,
            shape: CircleBorder(side: widget.side),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              canRequestFocus: false,
              onTap: enabled ? _handleTap : null,
              onLongPress: widget.onLongPress == null ? null : _handleLongPress,
              onHighlightChanged: (bool value) {
                if (value != _pressed) setState(() => _pressed = value);
              },
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
