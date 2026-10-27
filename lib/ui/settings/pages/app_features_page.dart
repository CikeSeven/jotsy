// 设置 → 功能管理：整体开关日历、探索两个页面（纪念日随日历放在其下），
// 以及日记本、日记模板、时间胶囊三项功能。
//
// 输入：`appFeaturesProvider`（当前开关）、`settingsServiceProvider`
// （写入目标，未就绪时全部开关禁用）、`notebooksProvider`（只取私密本子
// 数量，关闭日记本时据此决定是否先确认）。
// 输出 / 副作用：每次拨动立即经 `saveAppFeatures` 写入单个设置键，provider
// 随设置 notifier 刷新，各处入口随之显隐；数据一律不动。
//
// 纪念日依附日历（列表只能从日历顶栏进入），所以它的开关放在「页面」组里
// 日历的正下方，只在日历开启时展开显示，关闭时收起（不显示禁用态）。
// 拨动纪念日只写用户自己的 `anniversaries` 值（日历关闭不改写它），所以日历
// 重新开启时这一行回到用户原来的选择，不需要额外记忆。
//
// 关闭日记本时的确认：私密（隐藏 / 上锁）本子里的日记被统一谓词从所有全局
// 列表中排除，只在它所在的本子里出现；日记本关闭后本子入口全部隐藏，这些
// 日记就暂时找不到了。我们选择继续把它们藏着而不是放回全局列表（那会露出
// 上锁的内容），因此先提示用户，确认后才写入。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

import '../../../core/database/notebook_payload.dart';
import '../../../core/services/app_features.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../providers/app_features_provider.dart';
import '../widgets/settings_card_group.dart';
import '../widgets/settings_option_tiles.dart';
import '../widgets/settings_reveal.dart';
import '../../widgets/form_width.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_background.dart';

/// 功能管理二级页。
class AppFeaturesPage extends ConsumerWidget {
  const AppFeaturesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final features = ref.watch(appFeaturesProvider);
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    // 先订阅本子列表，关闭日记本时通常已有结果、不必等待；只取私密本数，
    // 其他本子的改动不触发重建。null 表示还没加载出来。
    final privateCount = ref.watch(
      notebooksProvider.select(
        (AsyncValue<List<NotebookView>> async) =>
            async.hasValue ? _countPrivate(async.requireValue) : null,
      ),
    );

    /// 设置未就绪时返回 null，让所有开关显示为禁用。
    ValueChanged<bool>? writer(AppFeatures Function(bool value) update) {
      if (settings == null) return null;
      return (bool value) => saveAppFeatures(settings, update(value));
    }

    return AppPageBackground(
      area: AppBackgroundArea.settings,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          appBar: AppTopBar(
            contentMaxWidth: FormWidth.maxWidth,
            title: Text(l10n.settingsFeaturesTitle),
            leading: IconButton(
              tooltip: l10n.commonBack,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
          ),
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final side = FormWidth.extra(constraints.maxWidth);
              return ListView(
                padding: EdgeInsets.fromLTRB(side, 12, side, 24),
                children: <Widget>[
                  SettingsCardGroup(
                    title: l10n.settingsFeaturesPagesGroup,
                    footer: l10n.settingsFeaturesPagesFooter,
                    children: <Widget>[
                      // 日历与其下的纪念日合成分组里的一项：分组按位置复用子项，若把
                      // 纪念日作为单独一项增删，后面“探索”那一行的开关状态会被它
                      // 接手，从探索的值播一遍开关动画。
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SettingsSwitchTile(
                            title: l10n.navCalendar,
                            subtitle: l10n.settingsFeaturesCalendarSubtitle,
                            value: features.calendar,
                            onChanged: writer(
                              (v) => features.copyWith(calendar: v),
                            ),
                          ),
                          SettingsReveal(
                            visible: features.calendar,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                settingsNestedDivider,
                                SettingsSwitchTile(
                                  title: l10n.settingsFeaturesAnniversaries,
                                  subtitle: l10n
                                      .settingsFeaturesAnniversariesSubtitle,
                                  nested: true,
                                  value: features.anniversaries,
                                  onChanged: writer(
                                    (v) => features.copyWith(anniversaries: v),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SettingsSwitchTile(
                        title: l10n.navExplore,
                        subtitle: l10n.settingsFeaturesExploreSubtitle,
                        value: features.explore,
                        onChanged: writer((v) => features.copyWith(explore: v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SettingsCardGroup(
                    title: l10n.settingsFeaturesFeaturesGroup,
                    footer: l10n.settingsFeaturesFeaturesFooter,
                    children: <Widget>[
                      SettingsSwitchTile(
                        title: l10n.notebookTitle,
                        subtitle: l10n.settingsFeaturesNotebooksSubtitle,
                        value: features.notebooks,
                        onChanged: settings == null
                            ? null
                            : (bool value) => _setNotebooks(
                                context,
                                ref,
                                settings,
                                privateCount,
                                value,
                              ),
                      ),
                      SettingsSwitchTile(
                        title: l10n.settingsFeaturesTemplates,
                        subtitle: l10n.settingsFeaturesTemplatesSubtitle,
                        value: features.templates,
                        onChanged: writer(
                          (v) => features.copyWith(templates: v),
                        ),
                      ),
                      SettingsSwitchTile(
                        title: l10n.settingsFeaturesTimeCapsules,
                        subtitle: l10n.settingsFeaturesTimeCapsulesSubtitle,
                        value: features.timeCapsules,
                        onChanged: writer(
                          (v) => features.copyWith(timeCapsules: v),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 开启直接写入；关闭时若有私密本子先确认（原因见文件顶部注释）。
  ///
  /// 本子列表可能还在加载：此时等它的首个结果再判断；读取失败按“没有私密
  /// 本子”处理，不因此挡住用户关闭。等待与弹窗期间页面可能已离开，每次
  /// await 之后都检查 `context.mounted`。
  Future<void> _setNotebooks(
    BuildContext context,
    WidgetRef ref,
    SettingsService settings,
    int? knownPrivateCount,
    bool value,
  ) async {
    if (!value) {
      final privateCount =
          knownPrivateCount ?? await _loadPrivateNotebookCount(ref);
      if (!context.mounted) return;
      if (privateCount > 0) {
        final confirmed = await _confirmNotebooksOff(context, privateCount);
        if (confirmed != true || !context.mounted) return;
      }
    }
    // 弹窗期间其他开关可能已改动，重新读一次当前值再只改这一项。
    final latest = ref.read(appFeaturesProvider);
    await saveAppFeatures(settings, latest.copyWith(notebooks: value));
  }

  Future<int> _loadPrivateNotebookCount(WidgetRef ref) async {
    try {
      return _countPrivate(await ref.read(notebooksProvider.future));
    } on Object {
      return 0;
    }
  }

  /// 私密本子：手动、可见性不是 normal（智能本写入时一律存 normal）。
  static int _countPrivate(List<NotebookView> notebooks) => notebooks
      .where((n) => n.isManual && n.visibility != NotebookVisibility.normal)
      .length;

  Future<bool?> _confirmNotebooksOff(BuildContext context, int count) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.settingsFeaturesNotebooksOffTitle),
          content: Text(l10n.settingsFeaturesNotebooksOffMessage(count)),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colors.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.settingsFeaturesNotebooksOffConfirm),
            ),
          ],
        );
      },
    );
  }
}
