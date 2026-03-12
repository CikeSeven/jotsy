import 'package:flutter/foundation.dart';

/// 注册项目内“手动引入资源”的开源协议。
///
/// `showLicensePage` 默认只展示依赖包协议，不会自动包含我们直接下载进仓库的素材。
/// 这里在应用启动阶段补充注册，确保关于页协议列表里能看到对应条目。
void registerThirdPartyLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      <String>['MingCute Icons'],
      '''
MingCute Icons
Source: https://github.com/mingcute-design/mingcute-icons
License: Apache License 2.0

Copyright (c) MingCute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
''',
    );
  });
}
