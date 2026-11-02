import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/services/ai/ai_provider_config.dart';
import '../../../../core/services/http_cancel_token.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_card_surface.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../controllers/ai_provider_flows.dart';
import '../../providers/ai_providers.dart';
import '../../viewmodels/ai_labels.dart';
import '../../widgets/ai_error_view.dart';

/// AI 设置页顶部的状态卡。
///
/// - 没有可用模型：说明 +“添加服务商”（打开预设面板 → 编辑页）；
/// - 已配好：默认模型 +“测试连接”。测试的状态（进行中 / 成功耗时 / 失败
///   说明）只在本卡片内存里；离开页面时取消进行中的请求。
class AiStatusCard extends ConsumerStatefulWidget {
  const AiStatusCard({super.key});

  @override
  ConsumerState<AiStatusCard> createState() => _AiStatusCardState();
}

class _AiStatusCardState extends ConsumerState<AiStatusCard> {
  HttpCancelToken? _testing;
  String? _result;
  Object? _error;

  @override
  void dispose() {
    _testing?.cancel();
    super.dispose();
  }

  Future<void> _test(AiResolvedModel model) async {
    final token = HttpCancelToken();
    setState(() {
      _testing = token;
      _result = null;
      _error = null;
    });
    try {
      final service = await ref.read(aiServiceProvider.future);
      final result = await service.testConnection(
        model.provider,
        model.model,
        cancelToken: token,
      );
      if (!mounted || token.isCancelled) return;
      setState(
        () => _result = context.l10n.aiStatusTestOk(
          result.elapsed.inMilliseconds,
        ),
      );
    } catch (error) {
      if (!mounted || token.isCancelled) return;
      setState(() => _error = error);
    } finally {
      if (mounted && identical(_testing, token)) {
        setState(() => _testing = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final config = ref.watch(aiLocalConfigProvider);
    final model = config.resolveTask(AiTaskKind.chat);
    final tonal = AppGlassField.tonalButtonStyle(context);

    final Widget body;
    if (model == null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Avatar(colors: colors),
          const SizedBox(height: 14),
          Text(
            l10n.aiStatusNotConfiguredTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.aiStatusNotConfiguredBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => addAiProviderFlow(context, ref),
            icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
            label: Text(l10n.aiStatusAddProvider),
          ),
        ],
      );
    } else {
      final testing = _testing != null;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _Avatar(colors: colors),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.aiStatusDefaultModel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      model.model.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${model.provider.name} · '
                      '${aiProtocolLabel(l10n, model.provider.protocol)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              FilledButton.tonalIcon(
                style: tonal,
                onPressed: testing ? null : () => _test(model),
                icon: const FaIcon(FontAwesomeIcons.plugCircleCheck, size: 14),
                label: Text(testing ? l10n.aiStatusTesting : l10n.aiStatusTest),
              ),
              if (_result != null)
                Text(
                  _result!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 10),
            AiErrorView(error: _error!, showSettings: false),
          ],
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AppCardSurface(padding: const EdgeInsets.all(18), child: body),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: FaIcon(
        FontAwesomeIcons.wandMagicSparkles,
        size: 18,
        color: colors.onPrimaryContainer,
      ),
    );
  }
}
