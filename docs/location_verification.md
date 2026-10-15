# 定位修复与验收

## 排查结论

- Android 主 Manifest 已同时声明粗略与精确位置权限；运行时只需前台授权，不需要后台定位权限。Android 插件将“仅大致位置”视为有效授权。
- 原实现只使用中等精度、8 秒单次定位，融合定位失败即结束。现改为高精度 12 秒请求；失败后复查权限和系统开关，再读取系统缓存或用 Android LocationManager 重试一次（20 秒）。插件的 `timeLimit` 负责取消超时的原生监听。
- 缓存读取限制为 2 秒；拒绝非有限数、越界、超过 5 分钟或明显来自未来的设备坐标。地址缓存最多保留 2 分钟，过期后重新获取位置与地址，不再反复续期旧地址。
- Geolocator 返回 WGS84，原实现直接传给要求高德坐标的逆地理编码接口。现先调用高德官方坐标转换接口，逆地理编码使用转换结果，日记与天气仍使用原始 WGS84 坐标。
- 地址请求原来只限制连接和响应头等待，正文断流可能永久等待。现单次 HTTP 请求的 10 秒超时覆盖完整正文；无效地址不回填、不缓存。
- 请求中撤权或关闭定位会返回对应原因；编辑页与发布页使用 ARB 本地化提示，失败后立即恢复按钮，不等待 SnackBar 消失。

高德坐标转换参考：[官方坐标转换说明](https://lbs.amap.com/api/webservice/guide/api/convert)。每次未命中地址缓存的成功定位，现在会各调用一次坐标转换与逆地理编码；部署使用的 Web 服务 key 需有对应服务授权和额度。

## 自动化验证

```sh
flutter test --no-pub \
  test/core/services/location_resolver_service_test.dart \
  test/core/services/location_device_position_test.dart \
  test/ui/diaries/pages/diary_location_permission_test.dart \
  test/ui/diaries/pages/publish_location_precision_test.dart \
  test/ui/diaries/pages/edit_diary_auto_save_test.dart \
  test/ui/diaries/pages/publish_return_flow_test.dart \
  test/ui/diaries/models/diary_location_test.dart \
  test/core/services/qweather_weather_service_test.dart
flutter analyze --no-pub
```

设备定位用可控的插件替身验证；高德用本地 HTTP 服务器验证请求参数、坐标转换顺序、响应解析、失败重试及正文断流超时。页面测试覆盖明暗主题、中英文、原地点保留与提示仍显示时再次尝试。

本次上述 71 项测试全部通过；`flutter gen-l10n` 和 `dart format` 已完成。全仓静态检查仍有 10 条与本次修改无关的既有 info 提示，无本次新增诊断。

## Android 实机检查清单

下面各项分别在编辑已有日记与新日记发布页、亮色与暗色主题执行。权限状态通过系统应用设置调整，无需清除应用数据。

| 触发步骤 | 预期结果 |
| --- | --- |
| 开启系统定位，将应用位置权限设为每次询问，点击自动定位并允许仅使用期间访问 | 授权后填入地址，等待结束；天气仍可使用此位置查询 |
| 仅授予大致位置，点击自动定位 | 不要求升级为精确或后台授权；系统能返回大致坐标时正常填入地址 |
| 拒绝本次授权，或在系统中禁止应用访问位置，再点击定位 | 显示对应语言的权限提示；原地点保持不变；提示仍显示时按钮已可重试 |
| 关闭系统定位后点击定位，随后开启并再次点击 | 先提示开启系统定位，再次点击会重新检查并尝试获取位置 |
| 定位过程中撤销权限或关闭系统定位 | 不继续等待第二次设备定位；显示权限或系统开关提示；按钮恢复 |
| 在 Google 定位服务不可用但系统定位可用的设备点击定位 | 首次失败后可通过系统缓存或 LocationManager 返回位置；不会无限重试 |
| 断网后点击定位，再恢复网络重试 | 解析失败会提示网络问题并保留原地点；失败结果不缓存，恢复网络后可立即重试 |
| 定位成功后切换城市、区县、道路和门牌层级，保存并重新打开 | 地址层级与原始坐标正常保存；手动修改地点不会被层级切换覆盖 |

本次环境未连接 Android 设备，也未配置本地高德 key，因此未执行实机 GPS、真实接口授权或额度验证。发布工作流已有 Web 服务 key 注入和非空校验；这不能证明线上 key 的授权与额度有效。
