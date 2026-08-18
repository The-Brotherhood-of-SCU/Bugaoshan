import java.util.Properties
import com.android.build.gradle.internal.api.ApkVariantOutputImpl

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    // 关闭依赖信息块，F-Droid 会检查 APK 中不能有 AGP 自动注入的依赖元数据签名块，否则直接拒绝。
    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }

    namespace = "io.github.the_brotherhood_of_scu.bugaoshan"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "io.github.the_brotherhood_of_scu.bugaoshan"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26 //android8: adaptive icon
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            ndk {
                debugSymbolLevel = "NONE"
            }
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
        getByName("debug") {
            applicationIdSuffix = ".debug"
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

// F-Droid ABI split 版本号方案：versionCode = base*10 + abiCode
// （base 来自 pubspec.yaml 的 +N / flutter build --build-number）
// 见 https://f-droid.org/en/docs/Submitting_to_F-Droid_Quick_Start_Guide/#setup-abi-split
val abiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 4)
android.applicationVariants.configureEach {
    val variant = this
    variant.outputs.forEach { output ->
        val abiVersionCode = abiCodes[output.filters.find { it.filterType == "ABI" }?.identifier]
        if (abiVersionCode != null) {
            (output as ApkVariantOutputImpl).versionCodeOverride = variant.versionCode * 10 + abiVersionCode
        }
    }
}

dependencies {
    implementation("androidx.glance:glance-appwidget:1.1.1")
    implementation("androidx.work:work-runtime-ktx:2.11.2")
    testImplementation(kotlin("test"))
}

flutter {
    source = "../.."
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21
    }
}
