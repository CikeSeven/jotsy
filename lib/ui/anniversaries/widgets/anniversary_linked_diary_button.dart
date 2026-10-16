import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../controllers/anniversary_navigation.dart';
import '../providers/anniversary_providers.dart';

/// 纪念日行尾的“打开关联的日记”按钮：只在关联的日记存在且可看时出现
/// （进回收站、被删除或是未解封的胶囊时不占位）。
class AnniversaryLinkedDiaryButton extends ConsumerWidget {
  const AnniversaryLinkedDiaryButton({
    super.key,
    required this.diaryId,
    required this.onOpen,
  });

  final String diaryId;
  final ValueChanged<DiaryWithTags> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diary = ref.watch(anniversaryLinkedDiaryProvider(diaryId)).value;
    if (diary == null || !isOpenableDiary(diary)) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: context.l10n.anniversaryOpenLinkedDiary,
      visualDensity: VisualDensity.compact,
      onPressed: () => onOpen(diary),
      icon: FaIcon(
        FontAwesomeIcons.bookOpen,
        size: 15,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
