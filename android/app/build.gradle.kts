plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.smart_horizon_home"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.smart_horizon_home"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            // For now use debug signing
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.1.0"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    // Optional Firebase modules
    // implementation("com.google.firebase:firebase-analytics")
    // implementation("com.google.firebase:firebase-storage")
}

flutter {
    source = "../.."
}

// Apply Google Services plugin **at the very bottom**
apply(plugin = "com.google.gms.google-services")
