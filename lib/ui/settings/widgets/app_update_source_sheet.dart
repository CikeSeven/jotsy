import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/app_update_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../widgets/expressive_choice_tile.dart';
import 'app_update_labels.dart';

/// 下载线路面板的选择结果。
class AppUpdateSourceChoice {
  const AppUpdateSourceChoice(this.sourceId, {this.customMirror});

  final String sourceId;

  /// 选择自定义镜像时已校验、规范化的前缀。
  final String? customMirror;
}

/// 打开下载线路面板；取消返回 null。
///
/// 选项：自动（测速择优，默认）、各内置镜像、GitHub 直连与自定义镜像。
/// 自定义镜像选中时展开输入框，保存前经 `normalizeMirrorPrefix` 校验。
Future<AppUpdateSourceChoice?> showAppUpdateSourceSheet(
  BuildContext context, {
  required AppUpdatePreferences preferences,
}) {
  return showAppModalBottomSheet<AppUpdateSourceChoice>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxWidth: 640,
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) =>
        AppUpdateSourceSheet(preferences: preferences),
  );
}

class AppUpdateSourceSheet extends StatefulWidget {
  const AppUpdateSourceSheet({super.key, required this.preferences});

  final AppUpdatePreferences preferences;

  @override
  State<AppUpdateSourceSheet> createState() => _AppUpdateSourceSheetState();
}

class _AppUpdateSourceSheetState extends State<AppUpdateSourceSheet> {
  late String _selected = widget.preferences.sourceId;
  late final TextEditingController _customController = TextEditingController(
    text: widget.preferences.customMirror ?? '',
  );
  bool _showCustomError = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _save() {
    if (_selected != AppUpdateSource.customId) {
      Navigator.of(context).pop(AppUpdateSourceChoice(_selected));
      return;
    }
    final normalized = AppUpdateSource.normalizeMirrorPrefix(
      _customController.text,
    );
    if (normalized == null) {
      setState(() => _showCustomError = true);
      return;
    }
    Navigator.of(
      context,
    ).pop(AppUpdateSourceChoice(_selected, customMirror: normalized));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    Widget choice(String id, String label, String description) =>
        ExpressiveChoiceTile(
          label: label,
          description: description,
          selected: _selected == id,
          onTap: () => setState(() {
            _selected = id;
            _showCustomError = false;
          }),
        );
    final mirrors = AppUpdateSource.builtInSources.where(
      (source) => !source.isDirect,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.s,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.appUpdateSource,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  // 桌面在浏览器里下载，应用不校验安装包，说明随之不同。
                  AppPlatform.supportsInAppInstall
                      ? l10n.appUpdateSourceSheetHint
                      : l10n.appUpdateSourceSheetHintDesktop,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              children: <Widget>[
                choice(
                  AppUpdatePreferences.autoSource,
                  l10n.appUpdateSourceAuto,
                  AppPlatform.supportsInAppInstall
                      ? l10n.appUpdateSourceAutoDescription
                      : l10n.appUpdateSourceAutoDescriptionDesktop,
                ),
                for (final source in mirrors)
                  choice(
                    source.id,
                    appUpdateSourceName(l10n, source),
                    l10n.appUpdateSourceMirrorDescription,
                  ),
                choice(
                  AppUpdateSource.directId,
                  l10n.appUpdateSourceDirect,
                  l10n.appUpdateSourceDirectDescription,
                ),
                choice(
                  AppUpdateSource.customId,
                  l10n.appUpdateSourceCustom,
                  l10n.appUpdateSourceCustomDescription,
                ),
                AnimatedSize(
                  duration: ExpressiveMotion.durationNonZero(
                    context,
                    ExpressiveMotion.medium,
                  ),
                  curve: ExpressiveMotion.effects,
                  child: _selected == AppUpdateSource.customId
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.s,
                            AppSpacing.s,
                            AppSpacing.s,
                            0,
                          ),
                          child: TextField(
                            controller: _customController,
                            autofocus: _customController.text.isEmpty,
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _save(),
                            onChanged: (_) {
                              if (_showCustomError) {
                                setState(() => _showCustomError = false);
                              }
                            },
                            decoration: InputDecoration(
                              hintText: l10n.appUpdateSourceCustomHint,
                              errorText: _showCustomError
                                  ? l10n.appUpdateSourceCustomInvalid
                                  : null,
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.m,
              AppSpacing.xl,
              AppSpacing.l,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: AppSpacing.s),
                FilledButton(onPressed: _save, child: Text(l10n.commonSave)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
