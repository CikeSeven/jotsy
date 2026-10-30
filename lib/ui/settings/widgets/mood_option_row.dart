import 'package:flutter/material.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../widgets/color_swatch_button.dart';

/// 心情符号页的一个槽位：左侧这个心情的颜色色块（点按换颜色），右侧心情
/// 符号输入框。只负责展示与回调，草稿状态在页面里。
class MoodOptionRow extends StatelessWidget {
  const MoodOptionRow({
    super.key,
    required this.controller,
    required this.index,
    required this.color,
    required this.enabled,
    required this.onPickColor,
  });

  final TextEditingController controller;

  /// 槽位下标（0–9，由低落到高兴）。
  final int index;

  /// 这个心情的颜色（原色，即取色时选的那一个）。
  final Color color;
  final bool enabled;
  final VoidCallback onPickColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final slot = (index + 1).toString();
    final defaultEmoji = SettingsService.defaultMoodOptions[index];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 输入框带浮动标签与帮助文字，色块与输入区对齐而不是与整行居中。
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: ColorSwatchButton(
            color: color,
            selected: false,
            semanticLabel: l10n.settingsMoodOptionsColorLabel(slot),
            onTap: enabled ? onPickColor : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            textAlign: TextAlign.center,
            maxLength: 8,
            style: Theme.of(context).textTheme.headlineSmall,
            decoration: InputDecoration(
              labelText: l10n.settingsMoodOptionsSlotLabel(slot),
              helperText: l10n.settingsMoodOptionsSlotHelper(defaultEmoji),
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }
}
