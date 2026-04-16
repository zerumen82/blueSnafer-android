plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.bluesnafer_pro"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
        freeCompilerArgs += listOf(
            // Use the opt-in annotation for experimental coroutines APIs.
            "-opt-in=kotlinx.coroutines.ExperimentalCoroutinesApi",
            // More permissive type checking to allow the Kotlin type inference issue
            "-Xskip-runtime-version-check",
            "-Xjvm-default=all"
        )
    }

    packagingOptions {
        pickFirst("lib/arm64-v8a/libtensorflowlite_jni.so")
        pickFirst("lib/armeabi-v7a/libtensorflowlite_jni.so")
        pickFirst("lib/x86_64/libtensorflowlite_jni.so")
        pickFirst("lib/x86/libtensorflowlite_jni.so")
        pickFirst("lib/arm64-v8a/libtensorflowlite_gpu_jni.so")
        pickFirst("lib/armeabi-v7a/libtensorflowlite_gpu_jni.so")
        pickFirst("lib/x86_64/libtensorflowlite_gpu_jni.so")
        pickFirst("lib/x86/libtensorflowlite_gpu_jni.so")
    }

    configurations.all {
        resolutionStrategy {
            // Forzar TensorFlow Lite en lugar de LiteRT para evitar conflictos
            force("org.tensorflow:tensorflow-lite:2.14.0")
            force("org.tensorflow:tensorflow-lite-api:2.14.0")
            force("org.tensorflow:tensorflow-lite-gpu:2.14.0")
            force("org.tensorflow:tensorflow-lite-gpu-api:2.14.0")
            
            // Excluir LiteRT que causa conflictos
            eachDependency {
                if (requested.group == "com.google.ai.edge.litert") {
                    useTarget("org.tensorflow:tensorflow-lite:${requested.version}")
                }
            }
        }
    }

    defaultConfig {
        applicationId = "com.bluesnafer_pro"
        minSdk = 26  // Requerido por tflite_flutter
        targetSdk = 36
        versionCode = 4
        versionName = "3.1.0-PERMISSION-FIX"
    }

    signingConfigs {
        create("release") {
            storeFile = file("keystore.jks")
            storePassword = "bluesnafer2025"
            keyAlias = "bluesnafer_key"
            keyPassword = "bluesnafer2025"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
    
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            // version = "3.18.1"
        }
    }
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib:2.1.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.0")
    
    // Android SDK dependencies
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.fragment:fragment-ktx:1.8.0")
    implementation("androidx.activity:activity-ktx:1.9.0")
    
    // Android logging
    implementation("androidx.annotation:annotation:1.7.1")
    
    // Android hardware APIs
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.0")
    
    // TensorFlow Lite - configurado con resolución de conflictos
    implementation("org.tensorflow:tensorflow-lite:2.14.0") {
        exclude(group = "com.google.ai.edge.litert")
    }
    implementation("org.tensorflow:tensorflow-lite-gpu:2.14.0") {
        exclude(group = "com.google.ai.edge.litert")
    }
    implementation("org.tensorflow:tensorflow-lite-api:2.14.0") {
        exclude(group = "com.google.ai.edge.litert")
    }
}

flutter {
    source = "../.."
}
