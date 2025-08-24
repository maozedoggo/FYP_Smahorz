// android/build.gradle.kts

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.10")
        classpath("com.android.tools.build:gradle:8.2.1") // Android Gradle Plugin
        classpath("com.google.gms:google-services:4.4.2") // Google Services plugin for Firebase
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Clean task for project
tasks.register("clean", Delete::class) {
    delete(rootProject.buildDir)
}
