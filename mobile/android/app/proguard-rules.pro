# Flutter WebRTC ProGuard Rules
-keep class com.cloudwebrtc.webrtc.** { *; }
-keep class org.webrtc.** { *; }

# Tor Android
-keep class org.torproject.** { *; }
-keep class info.guardianproject.** { *; }

# Keep generic signature of Call, Callback (R8 full mode strips signatures from non-kept items).
-keep,allowobfuscation,allowshrinking interface retrofit2.Call
-keep,allowobfuscation,allowshrinking class retrofit2.Callback

# With R8 full mode generic signatures are stripped for classes that are not kept.
-keep,allowobfuscation,allowshrinking class kotlin.coroutines.Continuation

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Models
-keep class model.** { *; }
-keep class com.example.** { *; }

# 🔐 Flutter Secure Storage - Don't obfuscate encryption classes
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class android.security.** { *; }

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 🔥 OBFUSCATION EXCEPTIONS - Critical security classes
# Don't obfuscate password manager (but it's RAM-only anyway)
-keep class **.**secure_password_manager.** { *; }
-keep class **.**SecurePasswordManager { *; }

# Keep encryption service
-keep class **.**zero_knowledge_encryption.** { *; }
-keep class **.**ZeroKnowledgeEncryptionService { *; }

# Keep production logger
-keep class **.**production_logger.** { *; }
