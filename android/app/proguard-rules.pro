-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# (Exemplos comuns de plugins; adicione conforme estiver usando)
-keep class com.google.firebase.** { *; }
-keep class com.google.gson.** { *; }
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-keep class retrofit2.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
