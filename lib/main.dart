import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_note/app/node_note_app.dart';

void main() {
  runApp(ProviderScope(child: const NodeNoteApp()));
}
