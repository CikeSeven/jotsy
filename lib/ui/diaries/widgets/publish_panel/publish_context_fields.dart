import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/core/services/app_platform.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_meta_actions.dart';
import 'package:node_diary/ui/diaries/models/diary_location.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/widgets/qweather_icon.dart';
import 'package:node_diary/ui/widgets/value_listenable_selector.dart';

import '../publish_location_precision_picker.dart';
import 'publish_panel_tile.dart';
import 'publish_resolvable_field.dart';

/// “此时此地”：地点（可自动定位）、地址层级、天气（按坐标获取）。
///
/// 输入框直接绑定草稿控制器的文本，打字不重建这里；按钮状态随
/// [DiaryMetaActions] 的进行中标记、层级与天气图标随草稿对应字段局部重建。
/// 地址层级只在有地点时出现：没有地点时它既没有可预览的内容，也只是
/// 下次定位的默认值，定位后再调整会自动按新层级改写地点。
///
/// 自动定位与天气只在 Android 提供（定位解析与高德 / 和风密钥都走 Android
/// 通道）：其他平台点了只会失败，两行都只留手填输入框。
class PublishContextFields extends StatelessWidget {
  const PublishContextFields({
    super.key,
    required this.draft,
    required this.actions,
    required this.busy,
  });

  final DiaryMetaDraftController draft;
  final DiaryMetaActions actions;

  /// 页面忙碌（写库中）时不允许改层级。
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.autoT0167, style: PublishPanelTile.titleStyle(context)),
        const SizedBox(height: 8),
        ValueListenableBuilder<bool>(
          valueListenable: actions.locating,
          builder: (context, locating, _) => PublishResolvableField(
            leading: const FaIcon(FontAwesomeIcons.locationDot, size: 14),
            controller: draft.locationText,
            hintText: l10n.contextLocationInputHint,
            resolveTooltip: l10n.autoT0169,
            resolveIcon: const FaIcon(
              FontAwesomeIcons.locationCrosshairs,
              size: 14,
            ),
            resolving: locating,
            showResolve: AppPlatform.supportsAutoLocation,
            onResolve: () => actions.resolveLocation(context),
          ),
        ),
        ValueListenableSelector<DiaryMetaDraft, bool>(
          valueListenable: draft,
          selector: (value) => value.location != null,
          builder: (context, hasLocation, picker) => AnimatedSize(
            // 减少动画时用 1ms 近似瞬时，0 时长的 AnimatedSize 会断言。
            duration: ExpressiveMotion.durationNonZero(
              context,
              ExpressiveMotion.fast,
            ),
            curve: ExpressiveMotion.effects,
            alignment: Alignment.topCenter,
            child: hasLocation
                ? picker
                : const SizedBox(width: double.infinity),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ValueListenableBuilder<bool>(
              valueListenable: actions.locating,
              builder: (context, locating, _) =>
                  ValueListenableSelector<
                    DiaryMetaDraft,
                    (DiaryLocationPrecision, Map<String, Object?>?)
                  >(
                    valueListenable: draft,
                    selector: (value) =>
                        (value.locationPrecision, value.autoAddressComponent),
                    builder: (context, selection, _) =>
                        PublishLocationPrecisionPicker(
                          precision: selection.$1,
                          locationController: draft.locationText,
                          addressComponent: selection.$2,
                          onChanged: locating || busy
                              ? null
                              : actions.changePrecision,
                        ),
                  ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<bool>(
          valueListenable: actions.weatherLoading,
          builder: (context, loading, _) =>
              ValueListenableSelector<DiaryMetaDraft, (String?, String?)>(
                valueListenable: draft,
                selector: (value) => (value.weatherIconCode, value.weather),
                builder: (context, weather, _) {
                  return PublishResolvableField(
                    leading: QWeatherIcon(
                      iconCode: weather.$1,
                      weatherText: weather.$2 ?? '',
                      size: 14,
                    ),
                    leadingGap: 8,
                    controller: draft.weatherText,
                    hintText: l10n.contextWeatherInputHint,
                    resolveTooltip: l10n.autoT0171,
                    // 与左侧的天气图标区分开：右边是“获取天气”的动作。
                    resolveIcon: const FaIcon(
                      FontAwesomeIcons.cloudArrowDown,
                      size: 14,
                    ),
                    resolving: loading,
                    showResolve: AppPlatform.supportsAutoLocation,
                    onResolve: () => actions.resolveWeather(context),
                  );
                },
              ),
        ),
      ],
    );
  }
}
