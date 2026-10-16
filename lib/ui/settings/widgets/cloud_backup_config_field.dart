import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../widgets/expressive_icon_swap.dart';

/// 备份位置配置表单的输入框。
///
/// prefixIcon 用固定宽度的居中盒子承载：不同 FontAwesome 字形宽度天然不一，
/// 直接作为 prefixIcon 会在多字段列布局中左右漂移；固定盒子让各字段的图标
/// 与输入文本起点对齐。[secret] 为 true 时带显示/隐藏切换。
class CloudBackupConfigField extends StatefulWidget {
  const CloudBackupConfigField({
    super.key,
    required this.controller,
    required this.icon,
    required this.labelText,
    this.hintText,
    this.keyboardType,
    this.secret = false,
  });

  final TextEditingController controller;
  final FaIconData icon;
  final String labelText;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool secret;

  @override
  State<CloudBackupConfigField> createState() => _CloudBackupConfigFieldState();
}

class _CloudBackupConfigFieldState extends State<CloudBackupConfigField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final obscured = widget.secret && _obscured;
    return TextField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: obscured,
      autocorrect: false,
      enableSuggestions: !widget.secret,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        prefixIcon: SizedBox(
          width: 44,
          child: Center(child: FaIcon(widget.icon, size: 16)),
        ),
        // 与上面的固定宽度盒子配套，关闭默认的 48 最小交互尺寸自适应，保证
        // 各字段的图标盒子完全等宽。
        prefixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        suffixIcon: widget.secret
            ? IconButton(
                tooltip: obscured ? l10n.passwordShow : l10n.passwordHide,
                onPressed: () => setState(() => _obscured = !_obscured),
                icon: ExpressiveIconSwap(
                  switchKey: obscured,
                  child: FaIcon(
                    obscured ? FontAwesomeIcons.eyeSlash : FontAwesomeIcons.eye,
                    size: 16,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
