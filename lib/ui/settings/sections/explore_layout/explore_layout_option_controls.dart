import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../explore/models/explore_module_config.dart';
import '../../../explore/models/explore_module_id.dart';
import '../../../explore/models/explore_option_spec.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/explore_layout_editor_controller.dart';
import '../../widgets/settings_option_tiles.dart';
import 'explore_layout_labels.dart';

/// 一张卡片展开后的设置行：宽窗口下的宽度，以及按声明（[ExploreOptionSpec]）
/// 统一画出的选项——单选与数量为连接按钮组，开关为开关行，有序多选为一排
/// 可点的标签（标签上写选择的先后）。选中即写入（[controller]）。
List<Widget> exploreModuleOptionTiles(
  BuildContext context, {
  required ExploreLayoutEditorController controller,
  required ExploreModuleConfig config,
}) {
  final l10n = context.l10n;
  final id = config.id;
  return <Widget>[
    SettingsChoiceTile(
      nested: true,
      title: l10n.exploreLayoutSpan,
      child: _choices<ExploreModuleSpan>(
        values: ExploreModuleSpan.values,
        selected: config.span,
        label: (ExploreModuleSpan span) => ExploreLayoutLabels.span(l10n, span),
        onSelected: (ExploreModuleSpan span) => controller.setSpan(id, span),
      ),
    ),
    for (final option in config.spec.options)
      switch (option) {
        ExploreChoiceOption() => SettingsChoiceTile(
          nested: true,
          title: ExploreLayoutLabels.optionTitle(l10n, option),
          child: _choices<String>(
            values: <String>[for (final value in option.values) value.name],
            selected: config.rawOption(option) as String,
            label: (String name) => ExploreLayoutLabels.value(
              l10n,
              option.values.firstWhere((value) => value.name == name),
            ),
            onSelected: (String name) => controller.setOption(id, option, name),
          ),
        ),
        ExploreCountOption() => SettingsChoiceTile(
          nested: true,
          title: ExploreLayoutLabels.optionTitle(l10n, option),
          child: _choices<int>(
            values: option.values,
            selected: config.count(option),
            label: (int value) =>
                ExploreLayoutLabels.count(l10n, option, value),
            onSelected: (int value) => controller.setOption(id, option, value),
          ),
        ),
        ExploreToggleOption() => SettingsSwitchTile(
          nested: true,
          title: ExploreLayoutLabels.optionTitle(l10n, option),
          value: config.toggle(option),
          onChanged: (bool value) => controller.setOption(id, option, value),
        ),
        ExploreMultiOption() => SettingsChoiceTile(
          nested: true,
          title: ExploreLayoutLabels.optionTitle(l10n, option),
          subtitle: l10n.exploreLayoutMultiHint(option.maxSelected),
          child: _MultiChips(
            controller: controller,
            config: config,
            option: option,
          ),
        ),
      },
  ];
}

Widget _choices<T>({
  required List<T> values,
  required T selected,
  required String Function(T value) label,
  required ValueChanged<T> onSelected,
}) {
  return ExpressiveButtonGroup<T>(
    minSegmentWidth: 76,
    segments: <ButtonSegment<T>>[
      for (final value in values)
        ButtonSegment<T>(value: value, label: Text(label(value))),
    ],
    selected: <T>{selected},
    onSelectionChanged: (Set<T> next) => onSelected(next.single),
  );
}

/// 有序多选：点未选的追加到末尾（到上限时不可再选），点已选的取消（至少
/// 留一项）；已选的标签前写它的先后。
class _MultiChips extends StatelessWidget {
  const _MultiChips({
    required this.controller,
    required this.config,
    required this.option,
  });

  final ExploreLayoutEditorController controller;
  final ExploreModuleConfig config;
  final ExploreMultiOption<Enum> option;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected = <String>[
      for (final name in config.rawOption(option) as List) '$name',
    ];
    void update(List<String> next) =>
        controller.setOption(config.id, option, next);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final value in option.values)
          () {
            final order = selected.indexOf(value.name);
            final isSelected = order >= 0;
            return FilterChip(
              label: Text(
                isSelected
                    ? '${order + 1}  ${ExploreLayoutLabels.value(l10n, value)}'
                    : ExploreLayoutLabels.value(l10n, value),
              ),
              selected: isSelected,
              showCheckmark: false,
              onSelected:
                  (isSelected && selected.length <= 1) ||
                      (!isSelected && selected.length >= option.maxSelected)
                  ? null
                  : (bool on) => update(
                      on
                          ? <String>[...selected, value.name]
                          : <String>[
                              for (final name in selected)
                                if (name != value.name) name,
                            ],
                    ),
            );
          }(),
      ],
    );
  }
}
