import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The upload key lives outside the repository: android/key.properties says
// where the keystore is and how to open it (docs/PRODUCTION.md). Without that
// file, release builds are signed with the debug key, which is enough for
// `flutter run --release` and is refused by Google Play.
val uploadKey = Properties()
val uploadKeyFile = rootProject.file("key.properties")
if (uploadKeyFile.exists()) {
    FileInputStream(uploadKeyFile).use { uploadKey.load(it) }
}

android {
    namespace = "dev.dlsoft.quincena"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.dlsoft.quincena"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("upload") {
            keyAlias = uploadKey.getProperty("keyAlias")
            keyPassword = uploadKey.getProperty("keyPassword")
            storeFile = uploadKey.getProperty("storeFile")?.let { file(it) }
            storePassword = uploadKey.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig =
                signingConfigs.getByName(if (uploadKeyFile.exists()) "upload" else "debug")
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

dependencies {
    // Text in screenshots, photos and PDFs, read on the device. The model
    // ships with the app, so it works offline and without Google Play.
    implementation("com.google.mlkit:text-recognition:16.0.1")
}
