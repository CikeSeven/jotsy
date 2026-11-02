// 发送前确认与私密判断：所有会把日记内容发出去的入口在发请求前都经这里。
//
// - [aiDiaryAllowed]：单篇功能（写作、回应、智能填写）能否用于这篇日记——
//   私密日记只在用户打开“允许对私密日记使用 AI”时可以；
// - [confirmAiSend]：按隐私设置的确认时机决定是否弹确认面板。首次发给某个
//   主机必问（勾“不再提示”后记进本机配置）；“多篇时”对多篇上下文每次都问；
//   “每次”任何请求都问。面板说明发往哪个主机、哪个模型、多少篇 / 多少字、
//   几张图片。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/ai/ai_provider_config.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../models/ai_preference_parts.dart';
import '../providers/ai_providers.dart';
import '../viewmodels/ai_labels.dart';

/// 单篇 AI 功能能否用于 [diaryId]（还没保存的新日记传 null，按草稿要收进
/// 的日记本由调用方另行判断）。
Future<bool> aiDiaryAllowed(WidgetRef ref, String? diaryId) async {
  if (ref.read(aiPreferencesProvider).privacy.allowPrivate) return true;
  if (diaryId == null) return true;
  return !(await ref.read(appDatabaseProvider).isDiaryPrivate(diaryId));
}

/// 一次请求要发送的内容，给确认面板展示。
class AiSendSummary {
  const AiSendSummary({required this.words, this.entries = 0, this.images = 0});

  /// 发送的字数（`TextStats` 口径）。
  final int words;

  /// 多篇上下文的日记篇数；单篇功能为 0。
  final int entries;

  final int images;

  bool get multiDiary => entries > 1;
}

/// 按隐私设置决定是否确认；返回 false 表示用户取消，调用方不要发送。
Future<bool> confirmAiSend(
  BuildContext context,
  WidgetRef ref, {
  required AiResolvedModel model,
  required AiSendSummary summary,
}) async {
  final mode = ref.read(aiPreferencesProvider).privacy.confirm;
  final host = model.provider.host;
  // 直接读存储（等它加载完）：配置 provider 第一次被读时可能还没拿到存储。
  final store = await ref.read(aiProviderStoreProvider.future);
  if (!context.mounted) return false;
  final acknowledged = store.config.acknowledgedHosts.contains(host);
  final ask = switch (mode) {
    AiConfirmMode.always => true,
    AiConfirmMode.multiDiary => !acknowledged || summary.multiDiary,
    AiConfirmMode.firstTime => !acknowledged,
  };
  if (!ask) return true;
  final result = await showAppModalBottomSheet<({bool send, bool remember})>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (BuildContext sheetContext) => _ConfirmSheet(
      host: host,
      modelName: aiModelDisplay(model),
      summary: summary,
      // 首次（还没确认过这个主机）且不是“每次都问”时才给“不再询问”。
      offerRemember: !acknowledged && mode != AiConfirmMode.always,
    ),
  );
  if (result == null || !result.send) return false;
  if (result.remember) await store.acknowledgeHost(host);
  return true;
}

class _ConfirmSheet extends StatefulWidget {
  const _ConfirmSheet({
    required this.host,
    required this.modelName,
    required this.summary,
    required this.offerRemember,
  });

  final String host;
  final String modelName;
  final AiSendSummary summary;
  final bool offerRemember;

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<_ConfirmSheet> {
  bool _remember = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final summary = widget.summary;
    Widget line(FaIconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 24,
            child: FaIcon(icon, size: 14, color: colors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.aiConfirmSendTitle(widget.host),
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            line(
              FontAwesomeIcons.robot,
              l10n.aiConfirmSendModel(widget.modelName),
            ),
            line(
              FontAwesomeIcons.fileLines,
              summary.entries > 0
                  ? l10n.aiConfirmSendEntries(summary.entries, summary.words)
                  : l10n.aiConfirmSendText(summary.words),
            ),
            if (summary.images > 0)
              line(
                FontAwesomeIcons.image,
                l10n.aiConfirmSendImages(summary.images),
              ),
            const SizedBox(height: 14),
            Text(
              l10n.aiConfirmSendNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            if (widget.offerRemember)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _remember,
                title: Text(l10n.aiConfirmSendRemember),
                onChanged: (bool? value) =>
                    setState(() => _remember = value ?? false),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colors.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop((send: true, remember: _remember)),
                  child: Text(l10n.aiConfirmSendAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
