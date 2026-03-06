import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/app/node_diary_app.dart';

void main() {
  runApp(ProviderScope(child: const NodeDiaryApp()));
}
