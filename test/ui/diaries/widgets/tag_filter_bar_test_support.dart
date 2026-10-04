import 'package:flutter/material.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_tag_filter_bar.dart';

import '../../../support/expressive_test_theme.dart';

/// Test-only tag panel fixture with separate diary and optional Home positions.
/// The parent scrollables remain genuine Flutter scrollables so arena ownership
/// and hit testing are exercised, rather than just invoking drag callbacks.
Widget buildTagBarHarness({
  required GlobalKey<TagBarHarnessState> key,
  required List<Tag> tags,
  bool initiallyExpanded = false,
  double pageContentHeight = 900,
  Brightness brightness = Brightness.light,
  Set<int> selectedTagIds = const <int>{},
  PageController? pageController,
}) {
  final page = Scaffold(
    body: TagBarHarness(
      key: key,
      tags: tags,
      initiallyExpanded: initiallyExpanded,
      pageContentHeight: pageContentHeight,
      selectedTagIds: selectedTagIds,
    ),
  );
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: expressiveTestTheme(brightness),
    home: pageController == null
        ? page
        : PageView(
            controller: pageController,
            children: <Widget>[page, const SizedBox.expand()],
          ),
  );
}

List<Tag> createTags(int count) => <Tag>[
  for (var index = 1; index <= count; index++)
    Tag(id: index, name: 'Tag $index', color: 0xff336699),
];

class TagBarHarness extends StatefulWidget {
  const TagBarHarness({
    super.key,
    required this.tags,
    this.initiallyExpanded = false,
    this.pageContentHeight = 900,
    this.selectedTagIds = const <int>{},
  });

  final List<Tag> tags;
  final bool initiallyExpanded;
  final double pageContentHeight;
  final Set<int> selectedTagIds;

  @override
  State<TagBarHarness> createState() => TagBarHarnessState();
}

class TagBarHarnessState extends State<TagBarHarness> {
  final ScrollController pageScrollController = ScrollController();
  final List<bool> verticalDragStarts = <bool>[];
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  bool expanded = false;

  @override
  void initState() {
    super.initState();
    expanded = widget.initiallyExpanded;
    _progress.value = expanded ? 1 : 0;
  }

  @override
  void dispose() {
    pageScrollController.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: pageScrollController,
      child: Column(
        children: <Widget>[
          DiaryTagFilterBar(
            tags: widget.tags,
            expansionProgress: _progress,
            canExpand: () => _progress.value < 1,
            canCollapse: () => _progress.value > 0,
            selectedTagFilterIds: widget.selectedTagIds,
            onToggleTagFilter: (_, __) {},
            onClearTagFilters: () {},
            onCollapse: () => setState(() {
              expanded = false;
              _progress.value = 0;
            }),
            onVerticalDragStart: (expanding) {
              verticalDragStarts.add(expanding);
              setState(() => expanded = expanding);
            },
            onVerticalDragUpdate: (delta, expansionExtent) {
              _progress.value = (_progress.value + delta / expansionExtent)
                  .clamp(0.0, 1.0);
            },
            onVerticalDragEnd: (velocity) {
              final target = velocity.abs() >= 600
                  ? velocity > 0
                  : _progress.value >= 0.5;
              setState(() {
                expanded = target;
                _progress.value = target ? 1 : 0;
              });
            },
          ),
          SizedBox(height: widget.pageContentHeight),
        ],
      ),
    );
  }
}
