import 'dart:math' as math;
import 'dart:ui' show ImageFilter, TileMode;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/qweather_icon.dart';
import '../../models/diary_card_style/diary_card_style.dart';
import '../../models/time_capsule.dart';
import '../../viewmodels/diary_card_appearance.dart';
import '../../viewmodels/diary_card_resolved_style.dart';
import '../../viewmodels/diary_card_view_data.dart';
import '../energy_battery_indicator.dart';
import 'diary_card_cover.dart';

/// 未解封时间胶囊卡片的内容：标题、心情/天气/精力胶囊与封存的正文区。
///
/// 只渲染“占位条 + 低清模糊封面”，不绘制真实正文：
/// 1) 隐私：真实文字即使被模糊，也会进入语义树被读屏读出；
/// 2) 性能：原先每张卡一个 BackdropFilter，需回读背景再模糊，屏上有多张
///    时滚动卡顿；改为只对封面自身做 ImageFiltered，且封面按极小尺寸解码。
///
/// 自定义样式只影响这里的内边距、内层圆角与标题颜色（随卡片圆角与表面
/// 色），区块顺序、标签与摘要等内容类选项一律不适用，封存内容不外露。
class DiaryCardLockedContent extends StatelessWidget {
  const DiaryCardLockedContent({
    super.key,
    required this.diary,
    required this.title,
    required this.previewCover,
    required this.capsuleState,
    required this.resolved,
    required this.appearance,
  });

  final DiaryWithTags diary;
  final String title;
  final String? previewCover;
  final TimeCapsuleState capsuleState;
  final DiaryCardResolvedStyle resolved;
  final DiaryCardAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final compact = resolved.compact;
    final colorScheme = Theme.of(context).colorScheme;
    final viewData = DiaryCardViewData.of(diary.diary);
    final mood = viewData.moodEmoji;
    final weather = viewData.weather;
    final weatherIconCode = viewData.weatherIconCode;
    final rawEnergy = viewData.energyLevel;
    final energy = rawEnergy == null
        ? null
        : EnergyBatteryIndicator.normalizeValue(rawEnergy);
    final countdown = _countdownLabel(context, capsuleState);

    // 内边距与内层圆角随样式变化：以改版前的写死值（列表 16/12、瀑布流
    // 12/12、内层圆角 14/12）为基准，加上用户相对默认值的增减，默认样式下
    // 与原来完全一致。
    final m = resolved.modeStyle;
    final defaults = DiaryCardModeStyle.defaultsFor(resolved.mode);
    final paddingH = math.max(
      4.0,
      (compact ? 12.0 : 16.0) + (resolved.paddingH - defaults.paddingH),
    );
    final paddingV = math.max(4.0, 12.0 + (m.paddingV - defaults.paddingV));
    final innerRadius = (compact ? 12.0 : 14.0) * resolved.cornerRadius / 24.0;

    final clearMeta = Wrap(
      spacing: 8,
      runSpacing: 6,
      children: <Widget>[
        if (mood != null && mood.isNotEmpty) _CapsuleMetaPill(label: mood),
        if (weather != null && weather.isNotEmpty)
          _CapsuleMetaPill(
            label: weather,
            leading: QWeatherIcon(
              iconCode: weatherIconCode,
              weatherText: weather,
              size: 13,
            ),
          ),
        if (energy != null)
          _CapsuleMetaPill(
            label: EnergyBatteryIndicator.descriptionForValue(
              energy,
              context.l10n,
            ),
            leading: EnergyBatteryIndicator(value: energy, iconSize: 16),
          ),
      ],
    );

    final cover = previewCover;
    final blurredBody = ClipRRect(
      borderRadius: BorderRadius.circular(innerRadius),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (cover != null)
                // clamp 采样边缘像素，避免模糊在封面四周采到透明而出现光晕；
                // ClipRect 防止模糊结果溢出到下方占位区。
                ClipRect(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: 6,
                      sigmaY: 6,
                      tileMode: TileMode.clamp,
                    ),
                    child: DiaryCardCoverImage(
                      source: cover,
                      width: double.infinity,
                      height: compact ? 126 : 140,
                      radius: 0,
                      lowResolution: true,
                    ),
                  ),
                ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: colorScheme.surfaceContainerHighest,
                child: _SealedTextPlaceholder(lineCount: compact ? 4 : 3),
              ),
            ],
          ),
          Positioned.fill(
            child: ColoredBox(
              color: colorScheme.surface.withValues(alpha: 0.48),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: ShapeDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.82),
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: <Widget>[
                    FaIcon(
                      FontAwesomeIcons.lock,
                      size: 13,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        countdown,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontSize: 11,
                          height: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        paddingH + resolved.accentStartInset,
        paddingV + resolved.accentTopInset,
        paddingH,
        paddingV,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: appearance.titleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FaIcon(
                FontAwesomeIcons.clock,
                size: 14,
                color: appearance.accentColor,
              ),
            ],
          ),
          if (clearMeta.children.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            clearMeta,
          ],
          const SizedBox(height: 10),
          blurredBody,
        ],
      ),
    );
  }

  String _countdownLabel(BuildContext context, TimeCapsuleState state) {
    final hours = state.remainingDuration.inHours;
    if (hours > 0 && hours < 24) {
      return context.l10n.timeCapsuleCountdownHours(hours.toString());
    }
    return context.l10n.timeCapsuleCountdownDays(
      state.remainingDays.toString(),
    );
  }
}

/// 封存正文占位：用长短不一的圆角条示意“这里有文字”，不渲染任何真实内容。
class _SealedTextPlaceholder extends StatelessWidget {
  const _SealedTextPlaceholder({required this.lineCount});

  final int lineCount;

  @override
  Widget build(BuildContext context) {
    final barColor = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.16);
    const widthFactors = <double>[1, 0.88, 0.94, 0.62];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var line = 0; line < lineCount; line++) ...<Widget>[
          if (line > 0) const SizedBox(height: 9),
          FractionallySizedBox(
            widthFactor: line == lineCount - 1
                ? widthFactors.last
                : widthFactors[line % (widthFactors.length - 1)],
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(5),
              ),
              child: const SizedBox(height: 10),
            ),
          ),
        ],
      ],
    );
  }
}

class _CapsuleMetaPill extends StatelessWidget {
  const _CapsuleMetaPill({required this.label, this.leading});

  final String label;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: ShapeDecoration(
        color: colorScheme.surfaceContainerHighest,
        shape: const StadiumBorder(),
      ),
      // 瀑布流窄列 + 大字号时“精力”说明会比单元格宽：文字省略而不是溢出，
      // 放得下时与原来一致。
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (leading != null) ...<Widget>[leading!, const SizedBox(width: 5)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}
