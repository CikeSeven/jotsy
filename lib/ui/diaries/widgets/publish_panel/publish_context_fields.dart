import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
            onResolve: () => actions.resolveLocation(context),
          ),
        ),
        Padding(
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
        const SizedBox(height: 8),
        ValueListenableBuilder<bool>(
          valueListenable: actions.weatherLoading,
          builder: (context, loading, _) =>
              ValueListenableSelector<DiaryMetaDraft, (String?, String?)>(
                valueListenable: draft,
                selector: (value) => (value.weatherIconCode, value.weather),
                builder: (context, weather, _) {
                  final icon = QWeatherIcon(
                    iconCode: weather.$1,
                    weatherText: weather.$2 ?? '',
                    size: 14,
                  );
                  return PublishResolvableField(
                    leading: icon,
                    leadingGap: 8,
                    controller: draft.weatherText,
                    hintText: l10n.contextWeatherInputHint,
                    resolveTooltip: l10n.autoT0171,
                    resolveIcon: icon,
                    resolving: loading,
                    onResolve: () => actions.resolveWeather(context),
                  );
                },
              ),
        ),
      ],
    );
  }
}
