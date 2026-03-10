import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")

if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val amapApiKey = localProperties.getProperty("amap.api.key", "")
val escapedAmapApiKey = amapApiKey
    .replace("\\", "\\\\")
    .replace("\"", "\\\"")
val amapWebApiKey = localProperties.getProperty("amap.web.api.key", "")
val escapedAmapWebApiKey = amapWebApiKey
    .replace("\\", "\\\\")
    .replace("\"", "\\\"")
val qWeatherCredentialId = localProperties.getProperty("qweather.credential_id", "")
val escapedQWeatherCredentialId = qWeatherCredentialId
    .replace("\\", "\\\\")
    .replace("\"", "\\\"")
val qWeatherApiKey = localProperties.getProperty("qweather.api_key", "")
val escapedQWeatherApiKey = qWeatherApiKey
    .replace("\\", "\\\\")
    .replace("\"", "\\\"")
val qWeatherApiHost = localProperties.getProperty("qweather.api_host", "")
val escapedQWeatherApiHost = qWeatherApiHost
    .replace("\\", "\\\\")
    .replace("\"", "\\\"")

android {
    namespace = "com.jotsy.diary"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        applicationId = "com.jotsy.diary"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["AMAP_API_KEY"] = amapApiKey
        buildConfigField("String", "AMAP_API_KEY", "\"$escapedAmapApiKey\"")
        buildConfigField("String", "AMAP_WEB_API_KEY", "\"$escapedAmapWebApiKey\"")
        buildConfigField("String", "QWEATHER_CREDENTIAL_ID", "\"$escapedQWeatherCredentialId\"")
        buildConfigField("String", "QWEATHER_API_KEY", "\"$escapedQWeatherApiKey\"")
        buildConfigField("String", "QWEATHER_API_HOST", "\"$escapedQWeatherApiHost\"")
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
