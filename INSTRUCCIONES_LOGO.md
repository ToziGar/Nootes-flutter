# Instrucciones para Actualizar el Logo

## 📱 Pasos para Configurar el Logo en Todos los Lugares

### 1. Convertir LOGO.webp a PNG
Primero necesitas convertir `LOGO.webp` a formato PNG con diferentes tamaños.

Puedes usar una herramienta online como:
- https://convertio.co/webp-png/
- https://cloudconvert.com/webp-to-png

O usar ImageMagick en terminal:
```bash
# Instalar ImageMagick si no lo tienes
# Windows: choco install imagemagick
# Mac: brew install imagemagick
# Linux: apt-get install imagemagick

# Convertir el logo
magick LOGO.webp LOGO.png
```

### 2. Crear los Tamaños Necesarios

Necesitas crear estas versiones del logo:

#### Para Web:
- `web/favicon.png` → 32x32 o 64x64 px
- `web/icons/Icon-192.png` → 192x192 px
- `web/icons/Icon-512.png` → 512x512 px
- `web/icons/Icon-maskable-192.png` → 192x192 px (con padding)
- `web/icons/Icon-maskable-512.png` → 512x512 px (con padding)

#### Para Android:
- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` → 48x48 px
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` → 72x72 px
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` → 96x96 px
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` → 144x144 px
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` → 192x192 px

#### Para iOS:
- Actualizar en `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- Varios tamaños desde 20x20 hasta 1024x1024

### 3. Usar Flutter Launcher Icons (Recomendado - Automático)

La forma más fácil es usar el paquete `flutter_launcher_icons`:

1. **Agregar a `pubspec.yaml`** (sección `dev_dependencies`):
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  flutter_launcher_icons: ^0.13.1
```

2. **Configurar en `pubspec.yaml`** (al final del archivo):
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  web:
    generate: true
    image_path: "LOGO.webp"
    background_color: "#1a1b26"
    theme_color: "#3b82f6"
  image_path: "LOGO.webp"
  adaptive_icon_background: "#1a1b26"
  adaptive_icon_foreground: "LOGO.webp"
```

3. **Ejecutar el generador**:
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

Esto generará automáticamente todos los tamaños necesarios para Android, iOS y Web.

### 4. Actualizar Splash Screen (Pantalla de Inicio)

Para agregar el logo en la pantalla de inicio de Android:

1. Crear `android/app/src/main/res/drawable/launch_background_custom.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/launch_background_color" />
    <item>
        <bitmap
            android:gravity="center"
            android:src="@mipmap/ic_launcher" />
    </item>
</layer-list>
```

2. Editar `android/app/src/main/res/values/styles.xml`:
```xml
<style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
    <item name="android:windowBackground">@drawable/launch_background_custom</item>
</style>
```

### 5. Verificar Cambios

Después de hacer los cambios:

```bash
# Limpiar build
flutter clean
flutter pub get

# Probar en web
flutter run -d chrome

# Probar en Android
flutter run -d android

# Build para producción
flutter build apk
flutter build web
```

## 🎨 Colores del Tema Actual

- Background: `#1a1b26`
- Primary: `#3b82f6`
- Accent: `#8b5cf6`

Estos colores pueden usarse en el splash screen y favicon.

## ⚠️ Notas Importantes

1. **WEBP en Android**: Android soporta WebP desde API 14+, así que podrías usarlo directamente
2. **Favicon**: Los navegadores modernos soportan PNG y ICO
3. **Maskable Icons**: Para PWA, necesitas versiones con padding para que no se recorten
4. **Splash Screen**: Para una experiencia profesional, considera usar `flutter_native_splash`

## 🔧 Comandos Útiles

```bash
# Ver dispositivos disponibles
flutter devices

# Limpiar y reconstruir
flutter clean && flutter pub get

# Generar iconos automáticamente
flutter pub run flutter_launcher_icons

# Build para Android
flutter build apk --release

# Build para Web
flutter build web --release
```
