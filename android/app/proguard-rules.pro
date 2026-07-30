# Reglas de ofuscacion para el build de release.
# Flutter y sus plugins ya aportan sus propias reglas via consumer-rules;
# aqui solo van las que necesita este proyecto.

# Flutter embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Las anotaciones de Play Core solo existen si se usa deferred components.
-dontwarn com.google.android.play.core.**

# Conservar nombres de excepciones para que los crashes sean legibles.
-keepattributes SourceFile,LineNumberTable,*Annotation*,Signature,InnerClasses,EnclosingMethod
