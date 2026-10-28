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
val shareApiBaseUrl = dartDefines["CLIPBACK_API_BASE_URL"]
    ?: "https://clipback-production.up.railway.app/api/v1"

android {
    namespace = "com.clipback.frontend"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    buildFeatures { buildConfig = true }
    useLibrary("android.test.runner", false)
    useLibrary("android.test.base", false)
    useLibrary("android.test.mock", false)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.huturu.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "android.test.InstrumentationTestRunner"
        buildConfigField("String", "SHARE_API_BASE_URL", "\"${shareApiBaseUrl.replace("\\", "\\\\").replace("\"", "\\\"")}\"")
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
