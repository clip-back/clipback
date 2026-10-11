import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

// Flutter passes --dart-define values as comma-separated base64 entries.
// Derive the native redirect from the same public key used by the Dart SDK.
val dartDefines = providers.gradleProperty("dart-defines").orNull
    ?.split(",")
    ?.filter { it.isNotEmpty() }
    ?.mapNotNull {
        val entry = String(Base64.getDecoder().decode(it), Charsets.UTF_8)
            .split("=", limit = 2)
        if (entry.size == 2) entry[0] to entry[1] else null
    }
    ?.toMap().orEmpty()
val kakaoNativeAppKey = dartDefines["CLIPBACK_KAKAO_NATIVE_APP_KEY"].orEmpty()

android {
    namespace = "com.clipback.frontend"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.clipback.frontend"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["kakaoLoginScheme"] = if (kakaoNativeAppKey.isNotBlank()) {
            "kakao$kakaoNativeAppKey"
        } else {
            "clipback-kakao-unconfigured"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
