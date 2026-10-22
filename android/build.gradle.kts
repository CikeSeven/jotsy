allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
    if (name == "keyboard_height_plugin") {
        // AppFlowy 的键盘高度适配插件固定在 SDK 31，但无需旧平台 API。
        // 跟随应用的 Flutter compileSdk，避免迁移额外要求安装过期 SDK。
        afterEvaluate {
            val appAndroid = project(":app").extensions
                .getByType<com.android.build.gradle.BaseExtension>()
            extensions.configure<com.android.build.gradle.BaseExtension> {
                compileSdkVersion(requireNotNull(appAndroid.compileSdkVersion))
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
