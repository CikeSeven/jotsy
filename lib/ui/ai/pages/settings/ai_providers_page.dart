import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/services/ai/ai_provider_presets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../../settings/widgets/settings_card_group.dart';
import '../../controllers/ai_provider_flows.dart';
import '../../providers/ai_providers.dart';
import '../../sections/settings/ai_preset_sheet.dart';
import '../../viewmodels/ai_labels.dart';
import '../../widgets/ai_page_scaffold.dart';

/// 服务商列表：点一行编辑，底部添加。顺序即添加顺序（没有指定默认模型时
/// 用第一个可用的服务商）。
class AiProvidersPage extends ConsumerWidget {
  const AiProvidersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final providers = ref.watch(
      aiLocalConfigProvider.select((config) => config.providers),
    );
    return AiPageScaffold(
      title: l10n.aiProvidersTitle,
      children: <Widget>[
        SettingsCardGroup(
          footer: l10n.aiProvidersFooter,
          children: <Widget>[
            for (final provider in providers)
              ListTile(
                key: ValueKey<String>(provider.id),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                titleAlignment: ListTileTitleAlignment.center,
                leading: AiProviderMonogram(name: provider.name),
                title: Text(
                  provider.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${aiProtocolLabel(l10n, provider.protocol)} · '
                  '${l10n.aiProviderModelsCount(provider.models.length)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (!provider.enabled)
                      AiBadge(l10n.aiProviderDisabled)
                    else if (provider.apiKey.isEmpty &&
                        (aiProviderPresetById(provider.presetId)?.needsKey ??
                            true))
                      AiBadge(l10n.aiProviderNoKey, error: true),
                    const SizedBox(width: 8),
                    FaIcon(
                      FontAwesomeIcons.angleRight,
                      size: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ],
                ),
                onTap: () => editAiProviderFlow(context, provider),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonalIcon(
                  style: AppGlassField.tonalButtonStyle(context),
                  onPressed: () => addAiProviderFlow(context, ref),
                  icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
                  label: Text(l10n.aiStatusAddProvider),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
