# 应用自己的 R8 规则（release 构建，在 build.gradle.kts 的 release 里登记）。

# Media3 里 LogSessionId 类型的字段保持原样，不让 R8 改它们的类型与所在类。
#
# 为什么：android.media.metrics.LogSessionId 是 API 31 才有的系统类。Media3 在所有系统版本上
# 都会把这类 @Nullable 字段（API 31 以下恒为 null）读出来往下传；原始字节码里读字段不需要强转，
# 低版本上无害。R8 的横向类合并会把被合并类的字段统一放宽成 Object，再在读取处补一条
# check-cast，而 ART 执行 check-cast 时先解析目标类型（值为 null 也一样），Android 7–11 上解析
# 不到就抛 NoClassDefFoundError。v0.13.0 里 ExoPlayerAssetLoader.Factory 与 androidx.biometric
# 的 CryptoObject 被合并成一个类，存储管理压缩视频时 Transformer 一创建资源加载器，整个应用就
# 闪退（发布包 b72.e 第 141 行）。
#
# 被保留的字段不能改类型、不能搬到别的类，持有它们的类也就不再参与合并，读取处不会多出强转。
# 升级 Media3 / video_player 后应在发布包里复查（docs/rules/storage.md）。
-keepclassmembers class androidx.media3.** {
    android.media.metrics.LogSessionId *;
}
