# 保留泛型與註解資訊（供 Gson / Reflection 使用，不阻擋 R8 縮減與模糊化）
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-dontwarn sun.misc.**

# 保留 Gson TypeAdapter / TypeToken 子類別（供 flutter_local_notifications 等套件反序列化使用）
-keep class * extends com.google.gson.reflect.TypeToken { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# 忽略 UCrop / OkHttp 可選相依性警告
-dontwarn com.yalantis.ucrop.**
-dontwarn okhttp3.**
-dontwarn okio.**
