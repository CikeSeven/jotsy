import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/diary_font_storage_service.dart';
import '../../../core/services/diary_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/controllers/diary_typography_controller.dart';
import '../../diaries/providers/diary_typography_provider.dart';
import '../../diaries/viewmodels/diary_text_appearance.dart';
import '../../diaries/widgets/diary_font_choices.dart';
import '../../diaries/widgets/diary_typography_metrics_editor.dart';
import '../../diaries/widgets/diary_typography_preview.dart';
import '../../widgets/action_loading_overlay.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/expressive_choice_tile.dart';
import '../widgets/diary_font_delete_dialog.dart';
import '../widgets/settings_card_group.dart';
import '../../widgets/form_width.dart';

/// 设置 › 编辑器 › 正文字体与排版。
///
/// 预览卡固定在列表上方、不随列表滚动：调整下方的滑块时始终看得到效果。
/// 预览按滑块草稿渲染（拖动中即时变化），松手后才提交到全部日记页面。
/// 预览卡高度有上限，大字号、大行距时正文在卡内滚动，不挤占设置项。
class DiaryTypographyPage extends ConsumerStatefulWidget {
  const DiaryTypographyPage({super.key});

  @override
  ConsumerState<DiaryTypographyPage> createState() =>
      _DiaryTypographyPageState();
}

class _DiaryTypographyPageState extends ConsumerState<DiaryTypographyPage> {
  late final DiaryTypographyController _controller = DiaryTypographyController(
    ref,
  );
  DiaryTypography? _draft;
  bool _importing = false;

  void _setImporting(bool value) {
    if (mounted) {
      setState(() => _importing = value);
    }
  }

  Future<void> _deleteFont(DiaryImportedFont font) async {
    final confirmed = await showDiaryFontDeleteDialog(
      context,
      fontName: font.name,
    );
    if (confirmed) {
      await _controller.deleteFont(font);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typography = ref.watch(diaryTypographyProvider);
    final appearance = ref.watch(diaryTextAppearanceProvider);
    final draft = _draft;
    // 草稿只改排版数值，字体仍取已解析的字族名。
    final previewAppearance = draft == null
        ? appearance
        : DiaryTextAppearance(
            typography: draft,
            fontFamily: appearance.fontFamily,
          );
    final fontsAsync = ref.watch(diaryImportedFontsProvider);
    final importedFonts =
        fontsAsync.asData?.value ?? const <DiaryImportedFont>[];
    // 备份恢复到新设备、或字体目录被系统清理后，所选导入字体可能已不存在。
    final selectedFontMissing =
        typography.usesImportedFont &&
        fontsAsync.hasValue &&
        !importedFonts.any((font) => font.id == typography.fontId);
    final previewMaxHeight = MediaQuery.sizeOf(context).height * 0.32;

    return Scaffold(
      appBar: AppTopBar(
        contentMaxWidth: FormWidth.maxWidth,
        title: Text(l10n.diaryTypographyTitle),
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
      ),
      body: Stack(
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final side = FormWidth.extra(constraints.maxWidth);
              return Column(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      FormWidth.gutter(constraints.maxWidth),
                      AppSpacing.m,
                      FormWidth.gutter(constraints.maxWidth),
                      AppSpacing.m,
                    ),
                    child: DiaryTypographyPreview(
                      appearance: previewAppearance,
                      maxHeight: previewMaxHeight,
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        side,
                        AppSpacing.xs,
                        side,
                        24,
                      ),
                      children: <Widget>[
                        SettingsCardGroup(
                          title: l10n.diaryTypographyFontSection,
                          footer: selectedFontMissing
                              ? l10n.diaryTypographyFontMissing
                              : null,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.s),
                              child: Column(
                                children: <Widget>[
                                  for (final option in diaryFontOptions(
                                    l10n,
                                    importedFonts,
                                  ))
                                    _FontOptionTile(
                                      option: option,
                                      selected: option.id == typography.fontId,
                                      onSelected: () => _controller.commit(
                                        typography.copyWith(fontId: option.id),
                                      ),
                                      onDelete: option.imported == null
                                          ? null
                                          : () => _deleteFont(option.imported!),
                                    ),
                                ],
                              ),
                            ),
                            ListTile(
                              leading: const FaIcon(
                                FontAwesomeIcons.fileImport,
                                size: 18,
                              ),
                              title: Text(l10n.diaryTypographyImportFont),
                              subtitle: Text(
                                l10n.diaryTypographyImportFontHint,
                              ),
                              onTap: _importing
                                  ? null
                                  : () => _controller.importFont(
                                      context,
                                      onBusyChanged: _setImporting,
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.l),
                        SettingsCardGroup(
                          title: l10n.diaryTypographyLayoutSection,
                          footer: l10n.diaryTypographyScopeHint,
                          children: <Widget>[
                            DiaryTypographyMetricsEditor(
                              typography: typography,
                              onCommit: _controller.commit,
                              onPreview: (DiaryTypography? next) =>
                                  setState(() => _draft = next),
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.s,
                                AppSpacing.xs,
                                AppSpacing.s,
                                AppSpacing.s,
                              ),
                            ),
                            ListTile(
                              leading: const FaIcon(
                                FontAwesomeIcons.arrowRotateLeft,
                                size: 18,
                              ),
                              title: Text(l10n.diaryTypographyReset),
                              enabled: !typography.hasDefaultMetrics,
                              onTap: () => _controller.commit(
                                typography.withDefaultMetrics(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned.fill(
            child: ActionLoadingOverlay(
              visible: _importing,
              label: l10n.diaryTypographyImporting,
            ),
          ),
        ],
      ),
    );
  }
}

/// 字体选项；导入的字体在行尾带删除按钮。
class _FontOptionTile extends StatelessWidget {
  const _FontOptionTile({
    required this.option,
    required this.selected,
    required this.onSelected,
    this.onDelete,
  });

  final DiaryFontOption option;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tile = ExpressiveChoiceTile(
      label: option.label,
      description: option.id == DiaryTypography.systemFontId
          ? l10n.diaryTypographyFontSystemHint
          : null,
      selected: selected,
      onTap: onSelected,
    );
    final onDelete = this.onDelete;
    if (onDelete == null) {
      return tile;
    }
    return Row(
      children: <Widget>[
        Expanded(child: tile),
        IconButton(
          tooltip: l10n.diaryTypographyDeleteFont,
          onPressed: onDelete,
          icon: const FaIcon(FontAwesomeIcons.trashCan, size: 16),
        ),
      ],
    );
  }
}
