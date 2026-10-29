import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/app_update_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/form_width.dart';
import '../providers/changelog_provider.dart';
import '../widgets/changelog_entry_card.dart';
import '../widgets/external_link.dart';

/// 设置 → 关于 → 更新日志：按版本从新到旧列出随应用打包的更新说明（只负责
/// 装配）。
///
/// - 说明来自 `changelogProvider`（离线读取打包的 `docs/releases/`，按界面
///   语言选中文或英文），切换语言时随之换一份；
/// - 每个版本一张卡片，要点常显，其余章节点“展开全部”在卡片内展开；展开
///   状态只记在本页内存里（按 tag），离开页面即清空；
/// - 页尾可在浏览器打开 GitHub 上的全部版本（含安装包与校验文件）。
class ChangelogPage extends ConsumerStatefulWidget {
  const ChangelogPage({super.key});

  @override
  ConsumerState<ChangelogPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends ConsumerState<ChangelogPage> {
  final Set<String> _expanded = <String>{};

  void _toggle(String tag) {
    setState(() {
      if (!_expanded.remove(tag)) {
        _expanded.add(tag);
      }
    });
  }

  void _openLink(String url) => openExternalLink(context, url);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final changelog = ref.watch(changelogProvider(l10n.isZh ? 'zh' : 'en'));
    final empty = EmptyHint(
      icon: FontAwesomeIcons.clockRotateLeft,
      message: l10n.changelogEmpty,
    );
    return AppPageBackground(
      area: AppBackgroundArea.settings,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          appBar: AppTopBar(
            contentMaxWidth: FormWidth.maxWidth,
            title: Text(l10n.changelogTitle),
            leading: IconButton(
              tooltip: l10n.commonBack,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
          ),
          body: changelog.when(
            loading: () => const DelayedLoadingIndicator(),
            error: (_, _) => empty,
            data: (Changelog data) =>
                data.entries.isEmpty ? empty : _buildList(context, data),
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, Changelog data) {
    final entries = data.entries;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final side = FormWidth.gutter(constraints.maxWidth);
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
            side,
            AppSpacing.m,
            side,
            AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
          ),
          // 最后一项是页尾的 GitHub 链接。
          itemCount: entries.length + 1,
          itemBuilder: (BuildContext context, int index) {
            if (index == entries.length) {
              return _AllReleasesLink(
                onTap: () =>
                    _openLink(AppUpdateEndpoints.releasesPage.toString()),
              );
            }
            final entry = entries[index];
            return Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : AppSpacing.m),
              child: ChangelogEntryCard(
                key: ValueKey<String>(entry.tag),
                entry: entry,
                current: data.isInstalled(entry),
                expanded: _expanded.contains(entry.tag),
                onToggle: () => _toggle(entry.tag),
                onOpenLink: _openLink,
              ),
            );
          },
        );
      },
    );
  }
}

/// 页尾的“在 GitHub 查看全部版本”。直接画在页面背景上（不在卡片里），
/// 文字与图标经 `onBackgroundTextStyle` 兜底可读性；没有背景图时就是普通
/// 的主色文本按钮。
class _AllReleasesLink extends StatelessWidget {
  const _AllReleasesLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = AppPageBackdrop.onBackgroundTextStyle(
      context,
      TextStyle(color: Theme.of(context).colorScheme.primary),
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.l),
      child: Center(
        child: TextButton.icon(
          onPressed: onTap,
          icon: FaIcon(
            FontAwesomeIcons.github,
            size: 14,
            color: style?.color,
            shadows: style?.shadows,
          ),
          label: Text(context.l10n.changelogAllReleases, style: style),
        ),
      ),
    );
  }
}
