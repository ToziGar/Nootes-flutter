# Funciones Avanzadas - Nootes App

Documentación de las nuevas funcionalidades avanzadas implementadas en la aplicación.

## Índice

1. [Logging Avanzado con Firebase Crashlytics](#1-logging-avanzado-con-firebase-crashlytics)
2. [Smart Tag Service - Etiquetado Inteligente](#2-smart-tag-service---etiquetado-inteligente)
3. [Versioning Service - Control de Versiones](#3-versioning-service---control-de-versiones)

---

## 1. Logging Avanzado con Firebase Crashlytics

### Descripción

El `LoggingService` mejorado proporciona logging estructurado con integración completa a Firebase Crashlytics para monitoreo en producción, captura de errores no manejados y análisis de comportamiento de usuarios.

### Ubicación

`lib/services/logging_service.dart`

### Características Principales

- **Niveles de Log**: `debug`, `info`, `warning`, `error`, `critical`
- **Logging Estructurado**: Soporte para tags y metadata estructurada
- **Integración con Crashlytics**: 
  - Breadcrumbs para logs de bajo nivel
  - Non-fatal errors para errores y críticos
  - Custom keys para contexto adicional
- **Captura Global de Errores**:
  - `FlutterError.onError` para errores del framework
  - `PlatformDispatcher.instance.onError` para errores de la plataforma Dart
- **Seguro para Tests**: No intenta usar Crashlytics cuando Firebase no está inicializado

### Uso

#### Inicialización

```dart
// En main.dart, después de Firebase.initializeApp()
await LoggingService.initialize(
  enableCrashlyticsInDebug: false, // true para habilitar en desarrollo
);
```

#### Asociar Usuario

```dart
// Cuando un usuario inicia sesión
await LoggingService.setUserId(user.uid);

// Cuando cierra sesión
await LoggingService.setUserId(null);
```

#### Logging Básico

```dart
// Debug (solo visible en modo debug)
LoggingService.debug('Usuario navegó a pantalla de edición');

// Info
LoggingService.info(
  'Nota guardada exitosamente',
  tag: 'NoteEditor',
  data: {'noteId': noteId, 'wordCount': wordCount},
);

// Warning
LoggingService.warning(
  'Operación lenta detectada',
  tag: 'Performance',
  data: {'operation': 'saveNote', 'duration_ms': 5000},
);

// Error
LoggingService.error(
  'Fallo al sincronizar nota',
  tag: 'Sync',
  error: exception,
  stackTrace: stackTrace,
  data: {'noteId': noteId, 'attempt': retryCount},
);

// Critical (errores graves)
LoggingService.critical(
  'Error fatal en inicialización',
  tag: 'Startup',
  error: exception,
  stackTrace: stackTrace,
);
```

#### Métodos Especializados

```dart
// Log de acciones de usuario (para analytics)
LoggingService.logUserAction(
  'note_created',
  parameters: {
    'source': 'quick_add',
    'has_images': true,
  },
);

// Log de métricas de rendimiento
LoggingService.logPerformance(
  'note_save',
  Duration(milliseconds: 150),
  metadata: {'noteSize': 1024, 'hasAttachments': false},
);

// Log de llamadas API
LoggingService.logApiCall(
  '/api/notes/sync',
  method: 'POST',
  statusCode: 200,
  duration: Duration(milliseconds: 250),
);
```

#### Configurar Nivel Mínimo

```dart
// En producción, solo logs importantes
LoggingService.setMinLevel(LogLevel.warning);

// En desarrollo, todos los logs
LoggingService.setMinLevel(LogLevel.debug);
```

### Mejores Prácticas

1. **Tags Consistentes**: Use tags descriptivos y consistentes (ej: `'Auth'`, `'NoteEditor'`, `'Sync'`)
2. **Metadata Limitada**: Evite enviar objetos muy grandes en `data`; Crashlytics limita custom keys
3. **Información Sensible**: Nunca incluya contraseñas, tokens o PII en logs
4. **Niveles Apropiados**:
   - `debug`: Información de desarrollo/debugging
   - `info`: Eventos normales del flujo
   - `warning`: Situaciones inusuales pero manejables
   - `error`: Errores recuperables
   - `critical`: Errores graves que afectan funcionalidad principal

### Monitoreo en Firebase Console

1. Abra Firebase Console → Crashlytics
2. Revise crashes y non-fatal errors
3. Use breadcrumbs (logs) para rastrear flujo de usuario antes de errores
4. Filtre por custom keys para encontrar patrones

---

## 2. Smart Tag Service - Etiquetado Inteligente

### Descripción

El `SmartTagService` proporciona sugerencias automáticas de etiquetas para notas basándose en el contenido, usando análisis heurístico 100% offline (sin APIs externas).

### Ubicación

`lib/services/smart_tag_service.dart`

### Características Principales

- **Extracción de Hashtags**: Detecta #hashtags existentes en el texto
- **Análisis de Frecuencia**: Identifica palabras clave relevantes
- **Detección de Idioma**: Distingue entre español e inglés
- **Reconocimiento de Entidades**:
  - URLs
  - Emails
  - Fechas
  - Bloques de código
- **Filtrado Inteligente**: Elimina stop words y términos muy cortos
- **100% Offline**: No requiere conexión ni APIs externas

### Uso

#### Ejemplo Básico

```dart
import 'package:nootes/services/smart_tag_service.dart';

// Obtener sugerencias de tags
final tags = SmartTagService.suggestTags(
  title: 'Receta de Paella Valenciana',
  content: '''
  #receta #cocina
  
  Ingredientes:
  - Arroz bomba
  - Pollo y conejo
  - Judías verdes y garrafón
  
  Visita: https://recetas.com/paella
  Contacto: chef@example.com
  ''',
  maxTags: 8, // opcional, por defecto 10
);

print(tags);
// Salida posible: 
// ['receta', 'cocina', 'español', 'url', 'email', 'ingredientes', 'paella', 'arroz']
```

#### Integración en Editor de Notas

```dart
class NoteEditorPage extends StatefulWidget {
  // ...
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  List<String> _suggestedTags = [];
  
  void _updateTagSuggestions() {
    setState(() {
      _suggestedTags = SmartTagService.suggestTags(
        title: _titleController.text,
        content: _contentController.text,
        maxTags: 6,
      );
    });
  }
  
  @override
  void initState() {
    super.initState();
    
    // Actualizar sugerencias cuando cambia el contenido
    _contentController.addListener(() {
      // Debounce para evitar cálculos excesivos
      _debounceTimer?.cancel();
      _debounceTimer = Timer(Duration(seconds: 1), _updateTagSuggestions);
    });
  }
  
  Widget _buildTagSuggestions() {
    if (_suggestedTags.isEmpty) return SizedBox.shrink();
    
    return Wrap(
      spacing: 8,
      children: _suggestedTags.map((tag) => 
        ActionChip(
          label: Text(tag),
          onPressed: () => _addTag(tag),
        ),
      ).toList(),
    );
  }
}
```

#### Widget de Sugerencias Reutilizable

```dart
class SmartTagSuggestionsWidget extends StatelessWidget {
  final String title;
  final String content;
  final Function(String) onTagSelected;
  
  const SmartTagSuggestionsWidget({
    required this.title,
    required this.content,
    required this.onTagSelected,
  });
  
  @override
  Widget build(BuildContext context) {
    final suggestions = SmartTagService.suggestTags(
      title: title,
      content: content,
      maxTags: 8,
    );
    
    if (suggestions.isEmpty) {
      return SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Etiquetas sugeridas:',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: suggestions.map((tag) => 
            FilterChip(
              label: Text(tag),
              onSelected: (_) => onTagSelected(tag),
            ),
          ).toList(),
        ),
      ],
    );
  }
}
```

### Personalización

Para ajustar el comportamiento, modifique las constantes en `smart_tag_service.dart`:

```dart
// Longitud mínima de palabra clave
static const int _minKeywordLength = 4; // Cambiar según necesidad

// Límite de palabras clave por frecuencia
final topKeywords = freqMap.entries
  .where((e) => e.value > 1) // Ajustar umbral de frecuencia
  .toList()
  ..sort((a, b) => b.value.compareTo(a.value));
```

### Mejoras Futuras Sugeridas

- Integración con ML Kit para NER (Named Entity Recognition) local
- Soporte para más idiomas
- Aprendizaje de preferencias de usuario
- Análisis de sentimiento básico

---

## 3. Versioning Service - Control de Versiones

### Descripción

El `VersioningService` permite guardar, listar y restaurar versiones previas de notas, proporcionando un historial completo de cambios con timestamps automáticos.

### Ubicación

`lib/services/versioning_service.dart`

### Características Principales

- **Snapshots Automáticos**: Guarda versiones completas de notas
- **Metadata Flexible**: Soporte para información adicional (ej: razón del cambio)
- **Timestamps de Servidor**: Usa Firestore server timestamps para consistencia
- **Listado con Límites**: Obtiene versiones ordenadas cronológicamente
- **Restauración Completa**: Recupera cualquier versión anterior
- **Integrado con Firestore**: Usa subcolecciones para organización limpia

### Estructura en Firestore

```
users/{uid}/notes/{noteId}/versions/{versionId}
  ├─ snapshot: Map<String, dynamic> (contenido completo de la nota)
  ├─ createdAt: Timestamp (server timestamp)
  └─ metadata: Map<String, dynamic>? (opcional)
```

### Uso

#### Guardar una Versión

```dart
import 'package:nootes/services/versioning_service.dart';

final versioningService = VersioningService();

// Guardar versión antes de una edición mayor
final noteSnapshot = {
  'title': 'Mi Nota Importante',
  'content': 'Contenido original...',
  'tags': ['trabajo', 'proyecto'],
  'lastModified': Timestamp.now(),
  // ... otros campos
};

final versionId = await versioningService.saveVersion(
  noteId: 'note_123',
  snapshot: noteSnapshot,
  metadata: {
    'reason': 'Antes de refactorización mayor',
    'editedBy': 'user@example.com',
    'device': 'mobile',
  }, // metadata es opcional
);

print('Versión guardada: $versionId');
```

#### Listar Versiones

```dart
// Obtener últimas 10 versiones
final versions = await versioningService.listVersions(
  noteId: 'note_123',
  limit: 10, // opcional, por defecto 20
);

for (final version in versions) {
  print('Version ID: ${version.id}');
  print('Creada: ${version.createdAt.toDate()}');
  print('Título: ${version.snapshot['title']}');
  print('Metadata: ${version.metadata}');
  print('---');
}
```

#### Restaurar una Versión

```dart
// Restaurar versión anterior
final restoredSnapshot = await versioningService.restoreVersion(
  noteId: 'note_123',
  versionId: 'version_abc',
);

if (restoredSnapshot != null) {
  // Actualizar la nota principal con el snapshot restaurado
  await FirestoreService().updateNote(
    noteId: 'note_123',
    data: restoredSnapshot,
  );
  
  print('Nota restaurada exitosamente');
} else {
  print('Versión no encontrada');
}
```

#### Widget de Historial de Versiones

```dart
class NoteVersionHistoryPage extends StatelessWidget {
  final String noteId;
  
  const NoteVersionHistoryPage({required this.noteId});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Historial de Versiones')),
      body: FutureBuilder<List<NoteVersion>>(
        future: VersioningService().listVersions(noteId: noteId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final versions = snapshot.data ?? [];
          
          if (versions.isEmpty) {
            return Center(child: Text('No hay versiones guardadas'));
          }
          
          return ListView.builder(
            itemCount: versions.length,
            itemBuilder: (context, index) {
              final version = versions[index];
              final date = version.createdAt.toDate();
              final title = version.snapshot['title'] ?? 'Sin título';
              
              return ListTile(
                leading: Icon(Icons.history),
                title: Text(title),
                subtitle: Text(
                  '${DateFormat.yMd().add_jm().format(date)}\n'
                  '${version.metadata?['reason'] ?? 'Versión automática'}',
                ),
                trailing: IconButton(
                  icon: Icon(Icons.restore),
                  onPressed: () => _restoreVersion(context, version),
                ),
                onTap: () => _previewVersion(context, version),
              );
            },
          );
        },
      ),
    );
  }
  
  Future<void> _restoreVersion(BuildContext context, NoteVersion version) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Restaurar versión?'),
        content: Text(
          'Esto sobrescribirá el contenido actual. '
          '¿Desea continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Restaurar'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        final restored = await VersioningService().restoreVersion(
          noteId: noteId,
          versionId: version.id,
        );
        
        if (restored != null) {
          // Actualizar nota principal
          await FirestoreService().updateNote(
            noteId: noteId,
            data: restored,
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Versión restaurada exitosamente')),
          );
          
          Navigator.pop(context);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al restaurar: $e')),
        );
      }
    }
  }
  
  void _previewVersion(BuildContext context, NoteVersion version) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotePreviewPage(
          title: version.snapshot['title'],
          content: version.snapshot['content'],
          readOnly: true,
        ),
      ),
    );
  }
}
```

### Estrategias de Versionado

#### Auto-save con Versiones

```dart
class NoteEditorWithVersioning extends StatefulWidget {
  // ...
}

class _NoteEditorWithVersioningState extends State<NoteEditorWithVersioning> {
  Timer? _autoSaveTimer;
  Timer? _versionTimer;
  
  @override
  void initState() {
    super.initState();
    
    // Auto-save frecuente (cada 30 segundos)
    _autoSaveTimer = Timer.periodic(
      Duration(seconds: 30),
      (_) => _saveNote(),
    );
    
    // Crear versión cada 5 minutos
    _versionTimer = Timer.periodic(
      Duration(minutes: 5),
      (_) => _createVersion('Auto-save periódico'),
    );
  }
  
  Future<void> _createVersion(String reason) async {
    final snapshot = {
      'title': _titleController.text,
      'content': _contentController.text,
      'tags': _currentTags,
      'lastModified': Timestamp.now(),
    };
    
    await VersioningService().saveVersion(
      noteId: widget.noteId,
      snapshot: snapshot,
      metadata: {'reason': reason},
    );
  }
  
  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _versionTimer?.cancel();
    super.dispose();
  }
}
```

#### Versiones Antes de Operaciones Críticas

```dart
// Antes de eliminar tags masivamente
await _createVersion('Antes de limpiar tags');
await _removeAllTags();

// Antes de merge de conflictos
await _createVersion('Antes de resolver conflicto');
await _mergeConflict(localData, serverData);

// Antes de exportación/conversión de formato
await _createVersion('Antes de convertir a Markdown');
await _convertToMarkdown();
```

### Mejores Prácticas

1. **Límite de Versiones**: Implemente limpieza de versiones antiguas (ej: mantener solo últimas 50)
2. **Metadata Descriptiva**: Incluya razón del cambio para contexto
3. **Compresión Opcional**: Para notas muy grandes, considere comprimir snapshots
4. **Indices Firestore**: Cree índice en `createdAt` para consultas rápidas
5. **UI Clara**: Muestre claramente la diferencia entre versión actual y anterior

### Costos de Firestore

- Cada versión = 1 escritura + almacenamiento del documento
- Listado de versiones = 1 lectura por versión + overhead de query
- Considere estrategia de retención para controlar costos

---

## Ejemplo de Integración Completa

```dart
// Ejemplo: Editor de notas con todas las funciones avanzadas

class AdvancedNoteEditor extends StatefulWidget {
  final String noteId;
  
  const AdvancedNoteEditor({required this.noteId});
  
  @override
  _AdvancedNoteEditorState createState() => _AdvancedNoteEditorState();
}

class _AdvancedNoteEditorState extends State<AdvancedNoteEditor> {
  final _versioningService = VersioningService();
  
  List<String> _suggestedTags = [];
  Timer? _tagUpdateTimer;
  
  @override
  void initState() {
    super.initState();
    
    // Log de apertura de editor
    LoggingService.logUserAction('note_editor_opened', parameters: {
      'noteId': widget.noteId,
    });
    
    // Actualizar sugerencias de tags con debounce
    _contentController.addListener(_scheduleSuggestTags);
  }
  
  void _scheduleSuggestTags() {
    _tagUpdateTimer?.cancel();
    _tagUpdateTimer = Timer(Duration(milliseconds: 500), _updateSuggestedTags);
  }
  
  void _updateSuggestedTags() {
    final stopwatch = Stopwatch()..start();
    
    setState(() {
      _suggestedTags = SmartTagService.suggestTags(
        title: _titleController.text,
        content: _contentController.text,
      );
    });
    
    stopwatch.stop();
    
    // Log de performance
    LoggingService.logPerformance(
      'suggest_tags',
      stopwatch.elapsed,
      metadata: {'tagCount': _suggestedTags.length},
    );
  }
  
  Future<void> _saveWithVersion(String reason) async {
    try {
      // Crear snapshot actual
      final snapshot = {
        'title': _titleController.text,
        'content': _contentController.text,
        'tags': _currentTags,
        'lastModified': FieldValue.serverTimestamp(),
      };
      
      // Guardar versión
      await _versioningService.saveVersion(
        noteId: widget.noteId,
        snapshot: snapshot,
        metadata: {'reason': reason},
      );
      
      // Guardar nota principal
      await _saveNote();
      
      LoggingService.info(
        'Nota guardada con versión',
        tag: 'NoteEditor',
        data: {'reason': reason},
      );
      
      _showSuccessMessage('Guardado con éxito');
      
    } catch (e, stackTrace) {
      LoggingService.error(
        'Error al guardar nota con versión',
        tag: 'NoteEditor',
        error: e,
        stackTrace: stackTrace,
        data: {'noteId': widget.noteId, 'reason': reason},
      );
      
      _showErrorMessage('Error al guardar: $e');
    }
  }
  
  @override
  void dispose() {
    _tagUpdateTimer?.cancel();
    
    // Log de cierre de editor
    LoggingService.logUserAction('note_editor_closed', parameters: {
      'noteId': widget.noteId,
      'sessionDuration': _sessionDuration.inSeconds,
    });
    
    super.dispose();
  }
}
```

---

## Configuración de Firebase Crashlytics

### Android

1. Agregar en `android/app/build.gradle`:

```gradle
dependencies {
    // ...
    implementation platform('com.google.firebase:firebase-bom:33.1.0')
    implementation 'com.google.firebase:firebase-crashlytics'
}
```

2. Habilitar en `android/build.gradle`:

```gradle
buildscript {
    dependencies {
        classpath 'com.google.firebase:firebase-crashlytics-gradle:3.0.2'
    }
}
```

### iOS

1. Los CocoaPods ya incluyen Crashlytics con `firebase_crashlytics`
2. Asegúrese que `GoogleService-Info.plist` está en `ios/Runner/`

### Verificar Instalación

```dart
// En main.dart
await LoggingService.initialize();

// Forzar un crash de prueba (solo en desarrollo)
if (kDebugMode) {
  // Descomentar para probar:
  // FirebaseCrashlytics.instance.crash();
}
```

---

## Recursos Adicionales

- [Firebase Crashlytics Docs](https://firebase.google.com/docs/crashlytics)
- [Firestore Subcollections](https://firebase.google.com/docs/firestore/data-model#subcollections)
- [Flutter Error Handling](https://docs.flutter.dev/testing/errors)

---

## Soporte y Contribuciones

Para reportar problemas o sugerir mejoras:
1. Abra un issue en el repositorio
2. Incluya logs relevantes (sin información sensible)
3. Describa pasos para reproducir

---

**Última actualización**: 19 de Octubre, 2025
**Versión**: 1.0.0
