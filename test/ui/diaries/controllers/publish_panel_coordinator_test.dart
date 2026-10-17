import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/controllers/publish_panel_coordinator.dart';

void main() {
  PublishPanelCoordinator coordinator() => PublishPanelCoordinator(
    collapsedHeight: 56,
    mainExpandedHeight: 470,
    tagExpandedHeight: 540,
    capsuleExpandedHeight: 540,
    resolveDuration: (token) => token,
  );

  test('without a height limit each page uses its designed height', () {
    final panel = coordinator();
    addTearDown(panel.dispose);
    expect(panel.activeExpandedHeight, 470);
    panel.setContentPageIndex(1);
    expect(panel.activeExpandedHeight, 540);
  });

  // 键盘弹出时可用高度变小：展开高度随之收缩，收起态的吸附点按实际展开
  // 高度换算，收起栏仍完整露出 56dp。
  test('a height limit shrinks the expanded height and the snap factor', () {
    final panel = coordinator()..maxExpandedHeight = 306;
    addTearDown(panel.dispose);
    expect(panel.activeExpandedHeight, 306);
    expect(panel.collapsedFactor, 56 / 306);
    panel.setContentPageIndex(2);
    expect(panel.activeExpandedHeight, 306);
  });

  test('the panel never shrinks below the header plus a detail area', () {
    final panel = coordinator()..maxExpandedHeight = 90;
    addTearDown(panel.dispose);
    expect(
      panel.activeExpandedHeight,
      56 + PublishPanelCoordinator.minDetailHeight,
    );
  });

  test('a generous limit keeps the designed height', () {
    final panel = coordinator()..maxExpandedHeight = 800;
    addTearDown(panel.dispose);
    expect(panel.activeExpandedHeight, 470);
  });
}
