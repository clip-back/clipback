import java.util.Base64
import java.util.Properties
import java.security.KeyStore
import java.security.PrivateKey

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

// Only the local path is passed through the environment; credentials stay in an
// operator-owned file outside the repository.
val signingPropertiesFile = providers.environmentVariable("CLIPBACK_ANDROID_KEY_PROPERTIES")
    .orNull?.let { File(it) }
val signingProperties = Properties().apply {
    if (signingPropertiesFile?.isFile == true) {
        signingPropertiesFile.reader(Charsets.UTF_8).use { load(it) }
    }
}
val validateReleaseSigning = tasks.register("validateReleaseSigning") {
    doLast {
        require(signingPropertiesFile?.isFile == true) {
            "Set CLIPBACK_ANDROID_KEY_PROPERTIES to the external signing properties file."
        }
        val repository = rootProject.projectDir.parentFile.parentFile.canonicalFile.toPath()
        require(signingPropertiesFile.isAbsolute &&
            !signingPropertiesFile.canonicalFile.toPath().startsWith(repository)) {
            "Use an absolute signing properties path outside the repository."
        }
        for (name in listOf("storeFile", "storePassword", "keyAlias", "keyPassword")) {
            require(!signingProperties.getProperty(name).isNullOrBlank()) {
                "Release signing requires $name."
            }
        }
        val keyFile = File(signingProperties.getProperty("storeFile"))
        require(keyFile.isAbsolute && keyFile.isFile &&
            !keyFile.canonicalFile.toPath().startsWith(repository)) {
            "Release storeFile must be an existing absolute path outside the repository."
        }
        try {
            val store = KeyStore.getInstance(keyFile, signingProperties.getProperty("storePassword").toCharArray())
            require(store.getKey(signingProperties.getProperty("keyAlias"),
                signingProperties.getProperty("keyPassword").toCharArray()) is PrivateKey)
        } catch (_: Exception) {
            throw GradleException("Cannot read the upload key. Check the keystore, alias and passwords.")
        }
    }
}

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

    signingConfigs {
        create("release") {
            storeFile = signingProperties.getProperty("storeFile")?.let { File(it) }
            storePassword = signingProperties.getProperty("storePassword")
            keyAlias = signingProperties.getProperty("keyAlias")
            keyPassword = signingProperties.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

tasks.matching { it.name == "preReleaseBuild" || it.name == "validateSigningRelease" }
    .configureEach { dependsOn(validateReleaseSigning) }

flutter {
    source = "../.."
}
