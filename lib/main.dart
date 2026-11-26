import 'package:flutter/material.dart';
import 'package:node_diary/app/app_root_shell.dart';
import 'package:node_diary/app/launch_brand_mark.dart';
import 'package:node_diary/app/launch_splash_theme.dart';
import 'package:node_diary/core/services/third_party_licenses.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  registerThirdPartyLicenses();
  runApp(
    AppRootShell(
      launchBrandMark: args.contains(launchBrandMarkEntrypointArg),
      launchSeedColor: LaunchSplashTheme.seedFromEntrypointArgs(args),
    ),
  );
}
