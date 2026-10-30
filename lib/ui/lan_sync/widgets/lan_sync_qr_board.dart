// 二维码面板的底板与倒计时胶囊（DESIGN.md §5.27“二维码面板”）。
//
// 底板配色（为什么暗色主题下改用浅色配色）见 lan_sync_qr_sheet.dart 文件头。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/launch_brand_mark.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/seeded_theme_cache.dart';
import '../../app_surface/widgets/on_glass.dart';
import '../../diaries/providers/diary_preview_style_provider.dart';
import '../../widgets/expressive_loading_indicator.dart';
import '../models/lan_sync_qr_matrix.dart';
import '../models/lan_sync_qr_ticket.dart';
import 'lan_sync_qr_painter.dart';
import 'lan_sync_well_color.dart';

/// 底板的尺寸档：窄面板 264dp 32 圆角底板 + 216dp 码；内容区宽度 ≥ 480 的
/// 宽面板（桌面、平板，面板最宽 640）放大为 320dp 36 圆角底板 + 272dp 码，
/// 让每个模块在 1× 缩放的显示器上也有 3dp 以上，手机扫屏幕更稳。品牌块
/// 始终 40dp，挖空的模块数按所选码的边长换算（见 lan_sync_qr_matrix.dart）。
@immutable
class LanSyncQrBoardMetrics {
  const LanSyncQrBoardMetrics._(this.boardExtent, this.codeExtent, this.radius);

  static const LanSyncQrBoardMetrics compact = LanSyncQrBoardMetrics._(
    264,
    216,
    32,
  );
  static const LanSyncQrBoardMetrics wide = LanSyncQrBoardMetrics._(
    320,
    272,
    36,
  );

  /// 用宽档的最小内容区宽度。
  static const double wideMinWidth = 480;

  /// 按面板内容区的实际可用宽度（LayoutBuilder）取尺寸档。
  static LanSyncQrBoardMetrics forWidth(double width) =>
      width >= wideMinWidth ? wide : compact;

  final double boardExtent;
  final double codeExtent;
  final double radius;
}

/// 底板 + 二维码 + 中心 40dp 品牌块；尺寸见 [LanSyncQrBoardMetrics]，配色见
/// 文件头注释。
///
/// [pending]（准备中的占位码，见 `LanSyncQrTicket.pending`）时底板里不画码，
/// 居中显示加载与“正在准备二维码…”；真码到来时经 [AnimatedSwitcher] 交叉
/// 淡入（`ExpressiveMotion.fast`）。两种内容都放在同一个码区里，底板尺寸
/// 不变，面板不跳动。换成下一张真码时不淡入（同一个 key），直接重绘。
class LanSyncQrBoard extends ConsumerWidget {
  const LanSyncQrBoard({
    super.key,
    required this.matrix,
    this.metrics = LanSyncQrBoardMetrics.compact,
    this.pending = false,
  });

  final LanSyncQrMatrix? matrix;
  final LanSyncQrBoardMetrics metrics;
  final bool pending;

  /// 中心品牌块的边长（两档相同）。
  static const double markExtent = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = Theme.of(context);
    final glass = OnGlass.of(context);
    final boardTheme = appTheme.brightness == Brightness.light
        ? appTheme
        : SeededThemeCache.of(
            ref.watch(appThemeSeedColorProvider),
            Brightness.light,
            reduceMotion: ExpressiveMotion.reduceMotion(context),
          );
    final colors = boardTheme.colorScheme;
    final Color board;
    if (glass) {
      board = Color.alphaBlend(
        OnGlass.wellColor(colors),
        colors.surfaceContainerLowest,
      );
    } else if (appTheme.brightness == Brightness.light) {
      board = colors.surfaceContainerLow;
    } else {
      board = colors.surfaceContainerLowest;
    }
    final matrix = this.matrix;
    return Theme(
      data: boardTheme,
      child: Semantics(
        image: !pending,
        label: pending ? null : context.l10n.lanSyncQrSemantics,
        child: Container(
          width: metrics.boardExtent,
          height: metrics.boardExtent,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: board,
            borderRadius: BorderRadius.circular(metrics.radius),
          ),
          child: SizedBox.square(
            dimension: metrics.codeExtent,
            child: AnimatedSwitcher(
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.fast,
              ),
              switchInCurve: ExpressiveMotion.effects,
              switchOutCurve: ExpressiveMotion.exit,
              // 默认布局用宽松约束的 Stack，码会缩成品牌块大小；这里让新旧
              // 两层都铺满码区。
              layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
                fit: StackFit.expand,
                children: <Widget>[...previous, ?current],
              ),
              child: pending
                  ? _LanSyncQrPreparing(
                      key: const ValueKey<String>('preparing'),
                      textColor: colors.onSurfaceVariant,
                    )
                  : matrix == null
                  ? const SizedBox.expand(key: ValueKey<String>('code'))
                  : Stack(
                      key: const ValueKey<String>('code'),
                      alignment: Alignment.center,
                      children: <Widget>[
                        Positioned.fill(
                          child: CustomPaint(
                            painter: LanSyncQrPainter(
                              matrix: matrix,
                              dotColor: colors.onSurface,
                              finderColor: colors.primary,
                            ),
                          ),
                        ),
                        Container(
                          width: LanSyncQrBoard.markExtent,
                          height: LanSyncQrBoard.markExtent,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const SizedBox(
                            height: 24,
                            child: FittedBox(child: LaunchBrandMark()),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 准备中：40dp 加载 + 一行 13 号灰字“正在准备二维码…”。
class _LanSyncQrPreparing extends StatelessWidget {
  const _LanSyncQrPreparing({super.key, required this.textColor});

  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          ExpressiveLoadingIndicator(semanticLabel: l10n.lanSyncQrPreparing),
          const SizedBox(height: 12),
          Text(
            l10n.lanSyncQrPreparing,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 13, color: textColor),
          ),
        ],
      ),
    );
  }
}

/// 倒计时胶囊：20dp 环形进度 +“m:ss 后换一张新码”。
class LanSyncQrCountdownPill extends StatelessWidget {
  const LanSyncQrCountdownPill({
    super.key,
    required this.ticket,
    required this.now,
  });

  final LanSyncQrTicket ticket;
  final DateTime now;

  /// 剩余时间按整秒向上取整，“0:00”只在真正到期时出现。
  static String format(Duration remaining) {
    final seconds = (remaining.inMilliseconds + 999) ~/ 1000;
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final remaining = ticket.remainingAt(now);
    final lifetime = ticket.lifetime.inMilliseconds;
    final progress = lifetime <= 0 ? 0.0 : remaining.inMilliseconds / lifetime;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
      decoration: BoxDecoration(
        color: lanSyncWellColor(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox.square(
            dimension: 20,
            child: CustomPaint(
              painter: LanSyncCountdownRingPainter(
                progress: progress,
                color: colors.primary,
                trackColor: colors.outlineVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.lanSyncQrCountdown(format(remaining)),
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
