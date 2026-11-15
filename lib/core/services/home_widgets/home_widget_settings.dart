// 桌面小组件的设置：单个 JSON 键 `app.settings.home_widgets`。
//
// 本机偏好：不随备份导出、不参与局域网同步——实例按启动器分配的
// appWidgetId 记，换一台设备毫无意义（docs/rules/home_widgets.md）。
//
// 结构：
// - `instances`：桌面上每个实例的种类、外观与内容，键是 appWidgetId；
// - `pending`：在小组件工作室里设计好、刚请求“添加到桌面”的配置。
//   `requestPinAppWidget` 不把新实例的 id 交回 Dart，所以先按种类暂存，桌面上
//   第一个出现的、还没有配置的同类实例在 [pendingLifetime] 内领走它
//   （`HomeWidgetSettings.claimPending`）；
// - `saved`：“我的样式”，各种类共用的外观（原样保存，界面层编解码）。
//
// 解析逐项容错：一个实例或一条暂存坏了只丢它自己。

import 'dart:convert';

import 'home_widget_content.dart';
import 'home_widget_kind.dart';
import 'home_widget_style.dart';

/// 桌面上的一个小组件实例（或工作室里的一份草稿）。
class HomeWidgetInstance {
  const HomeWidgetInstance({
    required this.kind,
    this.style = HomeWidgetStyle.defaults,
    required this.content,
  });

  /// 某种类的默认配置：刚放到桌面、还没有在应用里调整过的实例按它显示。
  factory HomeWidgetInstance.defaultsFor(HomeWidgetKind kind) =>
      HomeWidgetInstance(
        kind: kind,
        content: HomeWidgetContent.defaultsFor(kind),
      );

  final HomeWidgetKind kind;
  final HomeWidgetStyle style;
  final HomeWidgetContent content;

  HomeWidgetInstance copyWith({
    HomeWidgetStyle? style,
    HomeWidgetContent? content,
  }) => HomeWidgetInstance(
    kind: kind,
    style: style ?? this.style,
    content: content ?? this.content,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.id,
    'style': style.toJson(),
    'content': content.toJson(),
  };

  /// 种类认不出时返回 null（更新版本写入的新种类，原样丢弃）。
  static HomeWidgetInstance? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = HomeWidgetKind.byId(json['kind'] as String?);
    if (kind == null) return null;
    return HomeWidgetInstance(
      kind: kind,
      style: HomeWidgetStyle.fromJson(json['style']),
      content: HomeWidgetContent.fromJson(kind, json['content']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HomeWidgetInstance &&
      other.kind == kind &&
      other.style == style &&
      other.content == content;

  @override
  int get hashCode => Object.hash(kind, style, content);
}

/// 等待桌面实例领走的配置。
class HomeWidgetPendingPin {
  const HomeWidgetPendingPin({
    required this.instance,
    required this.requestedAt,
  });

  final HomeWidgetInstance instance;
  final DateTime requestedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    ...instance.toJson(),
    'at': requestedAt.millisecondsSinceEpoch,
  };

  static HomeWidgetPendingPin? fromJson(Object? json) {
    if (json is! Map) return null;
    final instance = HomeWidgetInstance.fromJson(json);
    final at = json['at'];
    if (instance == null || at is! int) return null;
    return HomeWidgetPendingPin(
      instance: instance,
      requestedAt: DateTime.fromMillisecondsSinceEpoch(at),
    );
  }
}

class HomeWidgetSettings {
  const HomeWidgetSettings({
    this.instances = const <int, HomeWidgetInstance>{},
    this.pending = const <HomeWidgetPendingPin>[],
    this.savedStyles = const <Object?>[],
  });

  static const HomeWidgetSettings empty = HomeWidgetSettings();

  /// 暂存的配置等多久：启动器的确认框通常几秒内就点完了，过期的不再领，
  /// 免得之后从启动器列表里拖出来的同类实例意外套上很早以前的设计。
  static const Duration pendingLifetime = Duration(minutes: 15);

  final Map<int, HomeWidgetInstance> instances;
  final List<HomeWidgetPendingPin> pending;

  /// “我的样式”（工作室「预设」页保存的外观），原样保存的 JSON 列表。编解码与
  /// 增删改在界面层（`HomeWidgetStyleLibrary`，复用样式库的 `SavedStyles`），这里只
  /// 负责随设置一起读写、在其他改动中原样保留。
  final List<Object?> savedStyles;

  HomeWidgetSettings withSavedStyles(List<Object?> raw) => HomeWidgetSettings(
    instances: instances,
    pending: pending,
    savedStyles: List<Object?>.unmodifiable(raw),
  );

  /// 某个实例实际使用的配置：没调整过的按种类默认。
  HomeWidgetInstance instanceFor(int widgetId, HomeWidgetKind kind) {
    final stored = instances[widgetId];
    return stored != null && stored.kind == kind
        ? stored
        : HomeWidgetInstance.defaultsFor(kind);
  }

  HomeWidgetSettings withInstance(int widgetId, HomeWidgetInstance instance) =>
      HomeWidgetSettings(
        instances: <int, HomeWidgetInstance>{...instances, widgetId: instance},
        pending: pending,
        savedStyles: savedStyles,
      );

  HomeWidgetSettings withPending(HomeWidgetInstance instance, DateTime now) =>
      HomeWidgetSettings(
        instances: instances,
        pending: <HomeWidgetPendingPin>[
          // 同一种类只留最新的一份：用户在确认框点了取消又重新设计时，
          // 新设计生效。
          for (final pin in pending)
            if (pin.instance.kind != instance.kind) pin,
          HomeWidgetPendingPin(instance: instance, requestedAt: now),
        ],
        savedStyles: savedStyles,
      );

  /// 按桌面上现有的实例对账：已经不在桌面上的实例删掉配置；没有配置的
  /// 新实例领走同类的暂存配置；过期的暂存丢掉。返回 null 表示无需改动。
  ///
  /// [installed] 为 appWidgetId → 种类。认不出种类的实例不在其中。
  HomeWidgetSettings? reconcile(
    Map<int, HomeWidgetKind> installed,
    DateTime now,
  ) {
    var changed = false;
    final nextInstances = <int, HomeWidgetInstance>{};
    for (final entry in instances.entries) {
      if (installed[entry.key] == entry.value.kind) {
        nextInstances[entry.key] = entry.value;
      } else {
        changed = true;
      }
    }
    final nextPending = <HomeWidgetPendingPin>[
      for (final pin in pending)
        if (now.difference(pin.requestedAt) <= pendingLifetime) pin,
    ];
    if (nextPending.length != pending.length) changed = true;
    final unclaimed = installed.keys.toList()..sort();
    for (final widgetId in unclaimed) {
      if (nextInstances.containsKey(widgetId)) continue;
      final kind = installed[widgetId]!;
      final index = nextPending.indexWhere((pin) => pin.instance.kind == kind);
      if (index < 0) continue;
      nextInstances[widgetId] = nextPending.removeAt(index).instance;
      changed = true;
    }
    if (!changed) return null;
    return HomeWidgetSettings(
      instances: nextInstances,
      pending: nextPending,
      savedStyles: savedStyles,
    );
  }

  String encode() => jsonEncode(<String, Object?>{
    'v': 1,
    'instances': <String, Object?>{
      for (final entry in instances.entries)
        '${entry.key}': entry.value.toJson(),
    },
    if (pending.isNotEmpty)
      'pending': <Object?>[for (final pin in pending) pin.toJson()],
    if (savedStyles.isNotEmpty) 'saved': savedStyles,
  });

  static HomeWidgetSettings decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return empty;
    final Object? node;
    try {
      node = jsonDecode(raw);
    } on FormatException {
      return empty;
    }
    if (node is! Map) return empty;
    final instances = <int, HomeWidgetInstance>{};
    final rawInstances = node['instances'];
    if (rawInstances is Map) {
      for (final entry in rawInstances.entries) {
        final id = int.tryParse('${entry.key}');
        final instance = HomeWidgetInstance.fromJson(entry.value);
        if (id != null && instance != null) instances[id] = instance;
      }
    }
    final pending = <HomeWidgetPendingPin>[];
    final rawPending = node['pending'];
    if (rawPending is List) {
      for (final raw in rawPending) {
        final pin = HomeWidgetPendingPin.fromJson(raw);
        if (pin != null) pending.add(pin);
      }
    }
    final saved = node['saved'];
    return HomeWidgetSettings(
      instances: instances,
      pending: pending,
      savedStyles: saved is List
          ? List<Object?>.unmodifiable(saved)
          : const <Object?>[],
    );
  }
}
