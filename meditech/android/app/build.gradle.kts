plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "ph.meditech"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "ph.meditech"
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
    }

    // AGP 9 disables resValues by default; the flavors below rely on resValue() for app_name
    buildFeatures {
        resValues = true
    }

       // Three apps (customer, pharmacy, admin), each in dev, staging, and prod versions
   flavorDimensions += listOf("app", "env")
   productFlavors {
       create("customer") {
           dimension = "app"
           applicationIdSuffix = ".customer"
           resValue("string", "app_name", "MediTech")
       }
       create("pharmacy") {
           dimension = "app"
           applicationIdSuffix = ".pharmacy"
           resValue("string", "app_name", "MediTech Pharmacy")
       }
       create("admin") {
           dimension = "app"
           applicationIdSuffix = ".admin"
           resValue("string", "app_name", "MediTech Admin")
       }
       create("dev") {
           dimension = "env"
           applicationIdSuffix = ".dev"
           versionNameSuffix = "-dev"
       }
       create("staging") {
           dimension = "env"
           applicationIdSuffix = ".staging"
           versionNameSuffix = "-staging"
       }
       create("prod") {
           dimension = "env"
       }
   }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
