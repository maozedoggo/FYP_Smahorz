plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.smart_horizon_home"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.example.smart_horizon_home"
        minSdk = 23            // Firebase Auth requires min 23
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

        compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
        }

    kotlinOptions {
        jvmTarget = "11"
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.1.0"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-storage") // if you use Storage
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3") // << MUST be here
}

// Apply Flutter plugin
flutter {
    source = "../.."
}

// Apply Google Services plugin at the bottom
apply(plugin = "com.google.gms.google-services")
