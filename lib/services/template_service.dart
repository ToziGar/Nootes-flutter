import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

/// Servicio para manejar plantillas de notas
class TemplateService {
  static final TemplateService _instance = TemplateService._internal();
  factory TemplateService() => _instance;
  TemplateService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService.instance;

  /// Obtiene plantillas predefinidas del sistema
  List<NoteTemplate> getSystemTemplates() {
    return [
      NoteTemplate(
        id: 'meeting',
        name: 'Reunión',
        icon: '📅',
        description: 'Plantilla para notas de reuniones',
        category: 'Trabajo',
        content: '''# Reunión - {{fecha}}

## Participantes
- 
- 
- 

## Agenda
1. 
2. 
3. 

## Notas
{{contenido}}

## Acciones
- [ ] 
- [ ] 
- [ ] 

## Próximos pasos
''',
        tags: ['reunión', 'trabajo', 'agenda'],
        variables: ['fecha', 'contenido'],
      ),
      
      NoteTemplate(
        id: 'todo',
        name: 'Lista de Tareas',
        icon: '✅',
        description: 'Lista de tareas organizada',
        category: 'Productividad',
        content: '''# {{titulo}}

## Prioridad Alta 🔴
- [ ] 
- [ ] 

## Prioridad Media 🟡
- [ ] 
- [ ] 

## Prioridad Baja 🟢
- [ ] 
- [ ] 

## Completadas ✅
- [x] 

---
*Creado: {{fecha}}*
''',
        tags: ['tareas', 'productividad', 'organizacion'],
        variables: ['titulo', 'fecha'],
      ),
      
      NoteTemplate(
        id: 'daily_journal',
        name: 'Diario Personal',
        icon: '📔',
        description: 'Reflexiones diarias',
        category: 'Personal',
        content: '''# {{fecha}}

## ¿Cómo me siento hoy?
{{estado_animo}}

## Lo mejor del día
{{mejor_momento}}

## Desafíos
{{desafios}}

## Aprendizajes
{{aprendizajes}}

## Mañana quiero...
{{objetivos_manana}}

---
💭 *Reflexión:* {{reflexion}}
''',
        tags: ['diario', 'personal', 'reflexion'],
        variables: ['fecha', 'estado_animo', 'mejor_momento', 'desafios', 'aprendizajes', 'objetivos_manana', 'reflexion'],
      ),
      
      NoteTemplate(
        id: 'project_plan',
        name: 'Plan de Proyecto',
        icon: '📋',
        description: 'Estructura para planificar proyectos',
        category: 'Trabajo',
        content: '''# Proyecto: {{nombre_proyecto}}

## Objetivo
{{objetivo}}

## Alcance
### Incluye
- 
- 

### No incluye
- 
- 

## Timeline
| Fase | Inicio | Fin | Responsable |
|------|--------|-----|-------------|
| Fase 1 | | | |
| Fase 2 | | | |
| Fase 3 | | | |

## Recursos Necesarios
### Humanos
- 
- 

### Técnicos
- 
- 

### Presupuesto
{{presupuesto}}

## Riesgos
| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| | | | |

## Criterios de Éxito
- [ ] 
- [ ] 
- [ ] 
''',
        tags: ['proyecto', 'planificacion', 'trabajo'],
        variables: ['nombre_proyecto', 'objetivo', 'presupuesto'],
      ),
      
      NoteTemplate(
        id: 'book_notes',
        name: 'Notas de Libro',
        icon: '📚',
        description: 'Para tomar notas mientras lees',
        category: 'Aprendizaje',
        content: '''# {{titulo_libro}}
**Autor:** {{autor}}  
**Fecha de lectura:** {{fecha}}

## Resumen
{{resumen}}

## Ideas Principales
### Capítulo 1
- 
- 

### Capítulo 2
- 
- 

## Citas Importantes
> "{{cita_1}}"

> "{{cita_2}}"

## Reflexiones Personales
{{reflexiones}}

## Aplicaciones Prácticas
- [ ] 
- [ ] 
- [ ] 

## Calificación
⭐⭐⭐⭐⭐

## Libros Relacionados
- 
- 
''',
        tags: ['libro', 'lectura', 'aprendizaje', 'notas'],
        variables: ['titulo_libro', 'autor', 'fecha', 'resumen', 'cita_1', 'cita_2', 'reflexiones'],
      ),
      
      NoteTemplate(
        id: 'recipe',
        name: 'Receta de Cocina',
        icon: '🍳',
        description: 'Para guardar tus recetas favoritas',
        category: 'Personal',
        content: '''# {{nombre_receta}}

## Información
- **Tiempo de preparación:** {{tiempo_prep}}
- **Tiempo de cocción:** {{tiempo_coccion}}
- **Porciones:** {{porciones}}
- **Dificultad:** {{dificultad}}

## Ingredientes
- 
- 
- 
- 

## Preparación
1. 
2. 
3. 
4. 

## Notas
{{notas_especiales}}

## Variaciones
- 
- 

---
💡 **Tip:** {{tip}}
''',
        tags: ['receta', 'cocina', 'comida'],
        variables: ['nombre_receta', 'tiempo_prep', 'tiempo_coccion', 'porciones', 'dificultad', 'notas_especiales', 'tip'],
      ),
      
      NoteTemplate(
        id: 'idea_capture',
        name: 'Captura de Ideas',
        icon: '💡',
        description: 'Para anotar ideas rápidamente',
        category: 'Creatividad',
        content: '''# 💡 {{titulo_idea}}

## La Idea
{{descripcion_idea}}

## ¿Por qué es interesante?
{{valor}}

## Posibles aplicaciones
- 
- 
- 

## Próximos pasos
- [ ] Investigar más sobre...
- [ ] Hablar con...
- [ ] Probar...

## Recursos relacionados
- 
- 

---
*Capturado el: {{fecha_captura}}*  
*Estado: {{estado}}*
''',
        tags: ['idea', 'creatividad', 'brainstorming'],
        variables: ['titulo_idea', 'descripcion_idea', 'valor', 'fecha_captura', 'estado'],
      ),
    ];
  }

  /// Obtiene plantillas personalizadas del usuario
  Future<List<NoteTemplate>> getUserTemplates() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('templates')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return NoteTemplate.fromMap(doc.id, data);
    }).toList();
  }

  /// Guarda una plantilla personalizada
  Future<void> saveUserTemplate(NoteTemplate template) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('templates')
        .add({
      'name': template.name,
      'icon': template.icon,
      'description': template.description,
      'category': template.category,
      'content': template.content,
      'tags': template.tags,
      'variables': template.variables,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Elimina una plantilla personalizada
  Future<void> deleteUserTemplate(String templateId) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('templates')
        .doc(templateId)
        .delete();
  }

  /// Crea una nota desde una plantilla
  String createNoteFromTemplate(NoteTemplate template, Map<String, String> values) {
    String content = template.content;
    
    // Valores por defecto
    final defaultValues = {
      'fecha': DateTime.now().toString().substring(0, 10),
      'fecha_captura': DateTime.now().toString().substring(0, 16),
      'titulo': 'Nuevo documento',
    };
    
    // Combinar valores proporcionados con valores por defecto
    final allValues = {...defaultValues, ...values};
    
    // Reemplazar variables en el contenido
    for (final variable in template.variables) {
      final value = allValues[variable] ?? '{{$variable}}';
      content = content.replaceAll('{{$variable}}', value);
    }
    
    return content;
  }

  /// Obtiene todas las plantillas (sistema + usuario)
  Future<List<NoteTemplate>> getAllTemplates() async {
    final systemTemplates = getSystemTemplates();
    final userTemplates = await getUserTemplates();
    return [...systemTemplates, ...userTemplates];
  }

  /// Busca plantillas por categoría
  Future<List<NoteTemplate>> getTemplatesByCategory(String category) async {
    final allTemplates = await getAllTemplates();
    return allTemplates.where((template) => template.category == category).toList();
  }

  /// Busca plantillas por etiquetas
  Future<List<NoteTemplate>> searchTemplates(String query) async {
    final allTemplates = await getAllTemplates();
    query = query.toLowerCase();
    
    return allTemplates.where((template) {
      return template.name.toLowerCase().contains(query) ||
             template.description.toLowerCase().contains(query) ||
             template.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }
}

/// Clase para representar una plantilla de nota
class NoteTemplate {
  final String id;
  final String name;
  final String icon;
  final String description;
  final String category;
  final String content;
  final List<String> tags;
  final List<String> variables;
  final bool isSystemTemplate;

  const NoteTemplate({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.category,
    required this.content,
    required this.tags,
    required this.variables,
    this.isSystemTemplate = true,
  });

  factory NoteTemplate.fromMap(String id, Map<String, dynamic> data) {
    return NoteTemplate(
      id: id,
      name: data['name'] ?? '',
      icon: data['icon'] ?? '📄',
      description: data['description'] ?? '',
      category: data['category'] ?? 'General',
      content: data['content'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      variables: List<String>.from(data['variables'] ?? []),
      isSystemTemplate: false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icon': icon,
      'description': description,
      'category': category,
      'content': content,
      'tags': tags,
      'variables': variables,
    };
  }
}