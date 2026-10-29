// 配对面板的静态区块：顶部插图与安全说明块（DESIGN.md §5.27“配对面板”）。
// 只负责画与转发点按；阶段切换与按钮在 lan_sync_pairing_sheet.dart。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../models/lan_sync_platform.dart';
import 'lan_sync_labels.dart';
import 'lan_sync_well_color.dart';

/// 顶部插图：本机与对方两枚 56dp 20 圆角图标块，中间 36dp `primary` 圆底
/// 锁（`onPrimary`），两侧各一段 28dp `primary` 40% 点线。纯装饰，读屏不读。
class LanSyncPairingIllustration extends StatelessWidget {
  const LanSyncPairingIllustration({
    super.key,
    required this.localPlatform,
    required this.peerPlatform,
  });

  final LanSyncPlatform localPlatform;
  final LanSyncPlatform peerPlatform;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final well = lanSyncWellColor(context);
    Widget device(LanSyncPlatform platform) => Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: well,
        borderRadius: BorderRadius.circular(20),
      ),
      child: FaIcon(
        lanSyncPlatformIcon(platform),
        size: 24,
        color: colors.onSurfaceVariant,
      ),
    );
    final dots = CustomPaint(
      size: const Size(28, 4),
      painter: _DottedLinePainter(colors.primary.withValues(alpha: 0.4)),
    );
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          device(localPlatform),
          const SizedBox(width: 6),
          dots,
          const SizedBox(width: 6),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
            child: FaIcon(
              FontAwesomeIcons.lock,
              size: 15,
              color: colors.onPrimary,
            ),
          ),
          const SizedBox(width: 6),
          dots,
          const SizedBox(width: 6),
          device(peerPlatform),
        ],
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  const _DottedLinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const radius = 1.5;
    const gap = 6.0;
    final y = size.height / 2;
    for (var x = radius; x <= size.width - radius + 0.01; x += gap) {
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_DottedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 安全说明块：凹槽色（[lanSyncWellColor]）16 圆角，`shieldHalved` 18 + 双向合并与
/// 加密说明；下面一枚文本按钮“先导出完整备份”（[onExportBackup] 为 null 时
/// 不显示，例如成功之后）。
class LanSyncPairingSafetyNote extends StatelessWidget {
  const LanSyncPairingSafetyNote({super.key, this.onExportBackup});

  final VoidCallback? onExportBackup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final onExportBackup = this.onExportBackup;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: lanSyncWellColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: FaIcon(
                  FontAwesomeIcons.shieldHalved,
                  size: 18,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.lanSyncPairSafetyNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    height: 1.45,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (onExportBackup != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: onExportBackup,
                child: Text(l10n.lanSyncPairExportBackup),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}
