import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';

/// 应用密码输入框（DESIGN.md §5.31）：56dp 高的胶囊，前面钥匙图标、后面
/// 显示 / 隐藏切换。
///
/// - 底色、描边沿用主题的输入框样式（玻璃小控件时由 `AppGlassControlsTheme`
///   换成玻璃底色），只把圆角换成胶囊；[error] 时描边换成 error 色；
/// - 密码框不学习输入、不给建议（`enableSuggestions` / `autocorrect` /
///   `enableIMEPersonalizedLearning` 都关）：输入法不该记住应用密码。系统
///   因此会弹出密码键盘，对真正的密码这是预期行为；
/// - autofillHints 为 null：不让密码管理器保存应用密码；
/// - 显示 / 隐藏只切换遮挡，不清空、不挪光标。
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.readOnly = false,
    this.error = false,
    this.hintText,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;

  /// 核对中只读而不停用：停用会让输入框失去焦点、键盘收起再弹出。
  final bool readOnly;
  final bool error;
  final String? hintText;
  final bool autofocus;
  final VoidCallback? onSubmitted;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscured = true;

  static const double _height = 56;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final input = theme.inputDecorationTheme;
    const radius = BorderRadius.all(Radius.circular(_height / 2));
    InputBorder? pill(InputBorder? border) => border is OutlineInputBorder
        ? border.copyWith(borderRadius: radius)
        : border;
    final focused = pill(input.focusedBorder);
    final errorBorder = pill(input.errorBorder);
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      obscureText: _obscured,
      obscuringCharacter: '•',
      enableSuggestions: false,
      autocorrect: false,
      enableIMEPersonalizedLearning: false,
      // 显式为 null：TextField 默认是空列表，Android 仍会把它当密码框、弹出
      // “保存密码”；null 才让这个输入框不参与自动填充。
      autofillHints: null,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => widget.onSubmitted?.call(),
      contextMenuBuilder: appTextContextMenuBuilder,
      style: theme.textTheme.titleMedium?.copyWith(
        letterSpacing: _obscured ? 2 : 0.2,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        // 占位文字不跟遮挡圆点一起加宽字距。
        hintStyle: theme.textTheme.titleMedium?.copyWith(
          letterSpacing: 0.2,
          color: scheme.onSurfaceVariant,
        ),
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
        border: pill(input.border),
        enabledBorder: widget.error ? errorBorder : pill(input.enabledBorder),
        disabledBorder: pill(input.disabledBorder),
        focusedBorder: widget.error ? pill(input.focusedErrorBorder) : focused,
        // Center：前缀槽给的是“至少 48 高”的约束，图标直接放进去会贴在上沿。
        prefixIcon: Padding(
          padding: const EdgeInsetsDirectional.only(start: 20, end: 12),
          child: Center(
            widthFactor: 1,
            child: FaIcon(
              FontAwesomeIcons.key,
              size: 14,
              color: widget.error ? scheme.error : scheme.onSurfaceVariant,
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minHeight: 48),
        suffixIcon: Padding(
          padding: const EdgeInsetsDirectional.only(end: 4),
          child: IconButton(
            tooltip: _obscured ? l10n.appPasswordShow : l10n.appPasswordHide,
            onPressed: () => setState(() => _obscured = !_obscured),
            icon: FaIcon(
              _obscured ? FontAwesomeIcons.eye : FontAwesomeIcons.eyeSlash,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}

/// [trigger] 每变化一次横向抖动一次（输错密码）：幅度随时间衰减的正弦，
/// 时长取 `standard`。减少动画时不抖（时长为 0，只靠颜色与提示文字说明）。
class AppPasswordShake extends StatefulWidget {
  const AppPasswordShake({
    super.key,
    required this.trigger,
    required this.child,
  });

  final int trigger;
  final Widget child;

  @override
  State<AppPasswordShake> createState() => _AppPasswordShakeState();
}

class _AppPasswordShakeState extends State<AppPasswordShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  /// 最大位移（dp）。
  static const double _amplitude = 10;

  @override
  void didUpdateWidget(AppPasswordShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger == oldWidget.trigger) return;
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.standard,
    );
    if (duration == Duration.zero) return;
    _controller.duration = duration;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final t = _controller.value;
        final dx = t == 0 || t == 1
            ? 0.0
            : math.sin(t * math.pi * 6) * _amplitude * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}

/// 输入框下方固定高度的提示行（解锁视图与设置密码页共用）：居中，与上方
/// 居中的标题、说明对齐；内容变化时淡入淡出，出现、消失都不推动下面的按钮。
/// [error] 为 true 时用 error 色。
class AppPasswordStatusLine extends StatelessWidget {
  const AppPasswordStatusLine({super.key, this.text, this.error = true});

  final String? text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = this.text;
    return SizedBox(
      height: 36,
      child: AnimatedSwitcher(
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
        switchInCurve: ExpressiveMotion.effects,
        switchOutCurve: ExpressiveMotion.exit,
        child: text == null
            ? const SizedBox.shrink()
            : Center(
                key: ValueKey<String>(text),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    text,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: error
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
