import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/app_radii.dart';

/// 发布页底部玻璃悬浮面板。
///
/// - 收起态：提示“上划展开”；
/// - 展开态：提供标签与上下文信息编辑，并触发发布动作。
class PublishDiaryGlassPanel extends StatelessWidget {
  const PublishDiaryGlassPanel({
    super.key,
    required this.expanded,
    required this.saving,
    required this.bottomInset,
    required this.hasCover,
    required this.coverLabel,
    required this.locationController,
    required this.weatherController,
    required this.moodEmoji,
    required this.energyLevel,
    required this.tags,
    required this.tagsLoading,
    required this.tagsError,
    required this.selectedTagIds,
    required this.metadataPreview,
    required this.onExpandedChanged,
    required this.onPickCover,
    required this.onCreateTag,
    required this.onToggleTag,
    required this.onLocationChanged,
    required this.onWeatherChanged,
    required this.onMoodChanged,
    required this.onEnergyChanged,
    required this.onPublish,
    this.onClearCover,
  });

  static const List<String> moodOptions = <String>[
    '😀',
    '🙂',
    '😌',
    '😐',
    '😕',
    '😴',
    '😤',
    '🤩',
  ];

  final bool expanded;
  final bool saving;
  final double bottomInset;
  final bool hasCover;
  final String? coverLabel;
  final TextEditingController locationController;
  final TextEditingController weatherController;
  final String? moodEmoji;
  final int energyLevel;
  final List<Tag> tags;
  final bool tagsLoading;
  final String? tagsError;
  final Set<int> selectedTagIds;
  final String metadataPreview;
  final ValueChanged<bool> onExpandedChanged;
  final VoidCallback onPickCover;
  final VoidCallback onCreateTag;
  final void Function(int tagId, bool selected) onToggleTag;
  final ValueChanged<String> onLocationChanged;
  final ValueChanged<String> onWeatherChanged;
  final ValueChanged<String?> onMoodChanged;
  final ValueChanged<double> onEnergyChanged;
  final VoidCallback onPublish;
  final VoidCallback? onClearCover;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final targetHeight = expanded ? 430.0 : 64.0;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset + 8 : 10),
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (!expanded && velocity < -220) {
            onExpandedChanged(true);
            return;
          }
          if (expanded && velocity > 220) {
            onExpandedChanged(false);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          height: targetHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.nav),
            boxShadow: AppEffects.softShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.nav),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 15,
                sigmaY: 15,
                tileMode: TileMode.mirror,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(20),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child:
                      expanded
                          ? _buildExpandedContent(context)
                          : _buildCollapsedContent(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedContent() {
    return InkWell(
      onTap: () => onExpandedChanged(true),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: <Widget>[
            FaIcon(FontAwesomeIcons.anglesUp, size: 15),
            SizedBox(width: 10),
            Text(
              '上划展开',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Spacer(),
            FaIcon(FontAwesomeIcons.penToSquare, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
          child: Row(
            children: <Widget>[
              IconButton(
                icon: const FaIcon(FontAwesomeIcons.chevronDown, size: 14),
                tooltip: '收起',
                onPressed: () => onExpandedChanged(false),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '点击发表日记',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              FilledButton.icon(
                onPressed: saving ? null : onPublish,
                icon: const FaIcon(FontAwesomeIcons.paperPlane, size: 14),
                label: Text(saving ? '发布中...' : '发布'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildCoverSection(context),
                const SizedBox(height: 14),
                _buildTagSection(context),
                const SizedBox(height: 14),
                _buildContextFields(context),
                const SizedBox(height: 14),
                _buildMoodSection(context),
                const SizedBox(height: 14),
                _buildEnergySection(context),
                const SizedBox(height: 14),
                _buildMetadataPreview(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '封面',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: onPickCover,
              icon: const FaIcon(FontAwesomeIcons.image, size: 14),
              label: const Text('选择封面'),
            ),
            if (hasCover) ...<Widget>[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onClearCover,
                icon: const FaIcon(FontAwesomeIcons.xmark, size: 12),
                label: const Text('清除'),
              ),
            ],
          ],
        ),
        if (hasCover && coverLabel != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            coverLabel!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _buildTagSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '标签',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onCreateTag,
              icon: const FaIcon(FontAwesomeIcons.plus, size: 12),
              label: const Text('新建'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (tagsLoading)
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (tagsError != null)
          Text(
            '标签加载失败: $tagsError',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else if (tags.isEmpty)
          Text(
            '暂无标签，可先创建',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: -8,
            children: tags.map((tag) {
              return FilterChip(
                selected: selectedTagIds.contains(tag.id),
                avatar: CircleAvatar(
                  radius: 8,
                  backgroundColor: Color(tag.color),
                ),
                label: Text(tag.name),
                onSelected: (selected) => onToggleTag(tag.id, selected),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildContextFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '环境信息',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: locationController,
          onChanged: onLocationChanged,
          decoration: const InputDecoration(
            isDense: true,
            hintText: '地理位置（手动填写）',
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 12, right: 8),
              child: FaIcon(FontAwesomeIcons.locationDot, size: 14),
            ),
            prefixIconConstraints: BoxConstraints(minHeight: 30, minWidth: 34),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: weatherController,
          onChanged: onWeatherChanged,
          decoration: const InputDecoration(
            isDense: true,
            hintText: '实时天气（手动填写）',
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 12, right: 8),
              child: FaIcon(FontAwesomeIcons.cloudSun, size: 14),
            ),
            prefixIconConstraints: BoxConstraints(minHeight: 30, minWidth: 34),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '情绪',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: -8,
          children: moodOptions.map((emoji) {
            return ChoiceChip(
              label: Text(emoji),
              selected: moodEmoji == emoji,
              onSelected: (selected) => onMoodChanged(selected ? emoji : null),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEnergySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '能量水平（1-5）',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        Slider(
          value: energyLevel.toDouble().clamp(1.0, 5.0).toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: '$energyLevel',
          onChanged: onEnergyChanged,
        ),
      ],
    );
  }

  Widget _buildMetadataPreview(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Metadata（自动生成）',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 96, maxHeight: 140),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              metadataPreview,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}
