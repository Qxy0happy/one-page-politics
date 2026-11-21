import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

// `flutter build apk --target-platform android-arm64` 会把目标平台传给 Gradle。
// 只有一个目标平台时同时过滤插件的本地库，避免 APK 里混入其它 ABI 的 .so。
val targetPlatforms = (project.findProperty("target-platform") as String?)
    ?.split(",")
    ?.map { it.trim() }
    ?.filter { it.isNotEmpty() }
    .orEmpty()
val singleAbiFilter = if (targetPlatforms.size == 1) {
    when (targetPlatforms.single()) {
        "android-arm64" -> "arm64-v8a"
        "android-arm" -> "armeabi-v7a"
        "android-x64" -> "x86_64"
        "android-x86" -> "x86"
        else -> null
    }
} else {
    null
}

android {
    namespace = "com.qxyhappy.one_page_politics"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.qxyhappy.one_page_politics"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        if (singleAbiFilter != null) {
            ndk {
                abiFilters.add(singleAbiFilter)
            }
        }
    }

    packaging {
        jniLibs {
            if (singleAbiFilter != null) {
                excludes += listOf("arm64-v8a", "armeabi-v7a", "x86_64", "x86")
                    .filter { it != singleAbiFilter }
                    .map { "lib/$it/**" }
            }
        }
    }

    signingConfigs {
        if (keystoreProperties.isNotEmpty()) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // 有 key.properties 时使用专用 release 签名；否则退回本机 debug 签名，
            // 便于本地开发。正式更新包必须保持同一签名，见 tools/check.sh 的证书断言。
            signingConfig = if (keystoreProperties.isNotEmpty()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
