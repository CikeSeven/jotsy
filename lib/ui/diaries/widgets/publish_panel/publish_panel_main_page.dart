import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/controllers/diary_meta_actions.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/widgets/value_listenable_selector.dart';

import 'publish_context_fields.dart';
import 'publish_cover_tile.dart';
import 'publish_mood_energy_sections.dart';
import 'publish_panel_chrome.dart';
import 'publish_panel_entry_tiles.dart';

/// 面板上的“发表时间”行：[label] 为 null 时显示“自动获取当前时间”。
@immutable
class PublishTimeOption {
  const PublishTimeOption({required this.label, required this.onPick});

  final String? label;
  final VoidCallback? onPick;
}

/// 面板主页内容，自上而下：封面 → 标签 → 此时此地 → 发表时间 → 时间胶囊 →
/// 心情 → 精力 → 发表按钮。
///
/// 各区块各自监听草稿里自己的字段（见 ValueListenableSelector），拖动精力、
/// 打字、选心情只重建对应区块。
class PublishPanelMainPage extends StatelessWidget {
  const PublishPanelMainPage({
    super.key,
    required this.draft,
    required this.actions,
    required this.tags,
    required this.moodOptions,
    required this.busy,
    required this.publishTime,
    required this.capsuleEnabled,
    required this.onOpenTags,
    required this.onOpenCapsule,
    required this.onPublish,
  });

  final DiaryMetaDraftController draft;
  final DiaryMetaActions actions;
  final AsyncValue<List<Tag>> tags;
  final List<String> moodOptions;
  final bool busy;
  final PublishTimeOption? publishTime;
  final bool capsuleEnabled;
  final VoidCallback onOpenTags;
  final VoidCallback onOpenCapsule;

  /// 编辑已发布日记时为 null（自动保存，没有发表按钮）。
  final VoidCallback? onPublish;

  @override
  Widget build(BuildContext context) {
    final publishTime = this.publishTime;
    final onPublish = this.onPublish;
    const gap = SizedBox(height: 14);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PublishCoverTile(draft: draft, actions: actions),
          gap,
          PublishTagTile(
            draft: draft,
            tags: tags.asData?.value ?? const <Tag>[],
            onOpen: onOpenTags,
          ),
          gap,
          PublishContextFields(draft: draft, actions: actions, busy: busy),
          if (publishTime != null) ...<Widget>[
            gap,
            PublishTimeTile(
              draft: draft,
              label: publishTime.label,
              onPick: publishTime.onPick,
            ),
          ],
          if (capsuleEnabled) ...<Widget>[
            gap,
            PublishCapsuleTile(draft: draft, onOpen: onOpenCapsule),
          ],
          gap,
          PublishMoodSection(draft: draft, moodOptions: moodOptions),
          gap,
          PublishEnergySection(draft: draft),
          if (onPublish != null) ...<Widget>[
            gap,
            ValueListenableSelector<DiaryMetaDraft, bool>(
              valueListenable: draft,
              selector: (value) => value.capsule != null,
              builder: (context, sealing, _) => PublishPanelActionButton(
                busy: busy,
                sealing: sealing,
                onPressed: onPublish,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
