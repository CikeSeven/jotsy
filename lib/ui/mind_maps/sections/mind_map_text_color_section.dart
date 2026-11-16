import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/mind_map/mind_map_ops.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/models/diary_material_colors.dart';
import '../../diaries/models/diary_text_colors.dart';
import '../../diaries/providers/diary_saved_colors_provider.dart';
import '../../diaries/widgets/diary_color_panel/diary_color_host.dart';
import '../../diaries/widgets/diary_color_panel/diary_color_panel.dart';
import '../../widgets/expressive_button_group.dart';
import '../controllers/mind_map_editing_controller.dart';
import '../viewmodels/mind_map_text_colors.dart';

/// 主题样式面板里的“文字颜色 / 文字高亮”：上方二选一切换目标，下方是正文
/// 同款的颜色面板（色板 + 我的颜色、色系、自定义），作用于整条主题。
///
/// 写入经 [MindMapOps.setStyle]（各是一步撤销，同名的局部样式一并去掉），
/// 颜色按原色存 `#AARRGGBB`，与格式条、正文同一套；我的颜色与正文共用。
class MindMapTextColorSection extends ConsumerStatefulWidget {
  const MindMapTextColorSection({
    super.key,
    required this.controller,
    required this.id,
  });

  final MindMapEditingController controller;
  final String id;

  @override
  ConsumerState<MindMapTextColorSection> createState() =>
      _MindMapTextColorSectionState();
}

class _MindMapTextColorSectionState
    extends ConsumerState<MindMapTextColorSection> {
  DiaryColorTarget _target = DiaryColorTarget.text;
  DiaryColorPanelMode _mode = DiaryColorPanelMode.swatches;
  DiaryMaterialFamily _family = DiaryMaterialFamily.red;
  late List<Color> _documentColors = _scan();

  List<Color> _scan() =>
      mindMapDocumentColors(widget.controller.document, _target);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ExpressiveButtonGroup<DiaryColorTarget>(
          segments: <ButtonSegment<DiaryColorTarget>>[
            ButtonSegment<DiaryColorTarget>(
              value: DiaryColorTarget.text,
              label: Text(l10n.mindMapTextColor),
            ),
            ButtonSegment<DiaryColorTarget>(
              value: DiaryColorTarget.background,
              label: Text(l10n.mindMapHighlight),
            ),
          ],
          selected: <DiaryColorTarget>{_target},
          onSelectionChanged: (value) => setState(() {
            _target = value.first;
            _documentColors = _scan();
          }),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final grid = DiaryColorGridLayout.resolve(
              innerWidth: constraints.maxWidth,
            );
            final height = diaryColorPanelNaturalHeight(_mode, grid);
            return DiaryColorPanel(
              host: _NodeStyleColorHost(widget.controller, widget.id),
              target: _target,
              title: _target == DiaryColorTarget.text
                  ? l10n.mindMapTextColor
                  : l10n.mindMapHighlight,
              mode: _mode,
              onModeChanged: (mode) => setState(() {
                _mode = mode;
                if (mode == DiaryColorPanelMode.swatches) {
                  _documentColors = _scan();
                }
              }),
              grid: grid,
              savedColors: ref
                  .watch(diarySavedColorsProvider)
                  .forTarget(_target),
              documentColors: _documentColors,
              bodyHeight: height,
              active: true,
              onEditSavedColors: ref
                  .read(diarySavedColorsProvider.notifier)
                  .edit,
              materialFamily: _family,
              onMaterialFamilyChanged: (family) => _family = family,
            );
          },
        ),
      ],
    );
  }
}

/// 颜色面板作用在一个主题的整条样式上。按会话与节点判等。
final class _NodeStyleColorHost implements DiaryColorHost {
  const _NodeStyleColorHost(this.controller, this.id);

  final MindMapEditingController controller;
  final String id;

  @override
  DiaryColorValue colorValue(DiaryColorTarget target) {
    final raw =
        controller.document.index[id]?.style[mindMapColorMarkOf(target).key];
    return DiaryColorValue.parse(raw is String ? raw : null);
  }

  @override
  void applyColor(DiaryColorTarget target, Color? color) =>
      controller.updateDocument(
        (document) => MindMapOps.setStyle(
          document,
          id,
          mindMapColorMarkOf(target).key,
          color == null ? null : encodeDiaryColor(color),
        ),
      );

  @override
  Object? get selectionToken => id;

  @override
  void addListener(VoidCallback listener) => controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      controller.removeListener(listener);

  @override
  bool operator ==(Object other) =>
      other is _NodeStyleColorHost &&
      identical(other.controller, controller) &&
      other.id == id;

  @override
  int get hashCode => Object.hash(identityHashCode(controller), id);
}
