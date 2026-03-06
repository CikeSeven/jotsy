import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ThemeMode.system;
  }


}