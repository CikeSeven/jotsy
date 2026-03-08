import 'package:flutter/material.dart';

import '../../widgets/glass_page_header.dart';

/// 探索页占位组件。
class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final headerHeight =
        MediaQuery.paddingOf(context).top + GlassPageHeader.contentHeight;

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.only(top: headerHeight),
          children: const [
            SizedBox(
              height: 240,
              child: Center(child: Text('探索功能开发中')),
            ),
          ],
        ),
        const GlassPageHeader(title: '探索'),
      ],
    );
  }
}
