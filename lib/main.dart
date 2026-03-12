import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/app/node_diary_app.dart';
import 'package:node_diary/core/services/third_party_licenses.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerThirdPartyLicenses();
  runApp(ProviderScope(child: const NodeDiaryApp()));
}
