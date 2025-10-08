import 'package:flutter/material.dart';

/// Sistema de plantillas para notas
class NoteTemplate {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String content;
  final List<String> tags;
  final Map<String, String> variables; // Variables que se reemplazan en el contenido

  const NoteTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.content,
    this.tags = const [],
    this.variables = const {},
  });

  /// Reemplaza las variables en el contenido con valores personalizados
  String applyVariables(Map<String, String> values) {
    String result = content;
    values.forEach((key, value) {
      result = result.replaceAll('{{$key}}', value);
    });
    // Reemplazar variables de fecha/hora
    final now = DateTime.now();
    result = result.replaceAll('{{date}}', '${now.day}/${now.month}/${now.year}');
    result = result.replaceAll('{{time}}', '${now.hour}:${now.minute.toString().padLeft(2, '0')}');
    result = result.replaceAll('{{datetime}}', '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
    result = result.replaceAll('{{year}}', '${now.year}');
    result = result.replaceAll('{{month}}', '${now.month}');
    result = result.replaceAll('{{day}}', '${now.day}');
    result = result.replaceAll('{{weekday}}', _weekdayName(now.weekday));
    return result;
  }

  String _weekdayName(int weekday) {
    const names = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return names[weekday - 1];
  }
}

/// Plantillas predefinidas del sistema
class BuiltInTemplates {
  static const daily = NoteTemplate(
    id: 'daily',
    name: 'Diario Personal',
    description: 'Entrada de diario con reflexiones del día',
    icon: Icons.calendar_today_rounded,
    color: Color(0xFF3B82F6),
    tags: ['diario', 'personal'],
    variables: {
      'mood': 'Estado de ánimo',
      'weather': 'Clima',
    },
    content: '''# Diario - {{date}}

**Estado de ánimo:** {{mood}}
**Clima:** {{weather}}

## ☀️ Buenos momentos del día


## 🎯 Logros de hoy


## 💭 Reflexiones


## 🌟 Agradecimientos


## 📅 Plan para mañana

''',
  );

  static const meeting = NoteTemplate(
    id: 'meeting',
    name: 'Reunión',
    description: 'Acta de reunión con asistentes y decisiones',
    icon: Icons.groups_rounded,
    color: Color(0xFF8B5CF6),
    tags: ['reunión', 'trabajo'],
    variables: {
      'project': 'Proyecto',
      'organizer': 'Organizador',
    },
    content: '''# Reunión: {{project}}

**Fecha:** {{date}} {{time}}
**Organizador:** {{organizer}}

## 👥 Asistentes
- 

## 📋 Agenda
1. 
2. 
3. 

## 💬 Discusión


## ✅ Decisiones tomadas
- [ ] 

## 📝 Acción Items
- [ ] **Responsable:** - **Deadline:** 

## 🔄 Próxima reunión
**Fecha:** 
**Temas:** 

''',
  );

  static const todo = NoteTemplate(
    id: 'todo',
    name: 'Lista de Tareas',
    description: 'Lista de tareas con prioridades',
    icon: Icons.checklist_rounded,
    color: Color(0xFF10B981),
    tags: ['tareas', 'productividad'],
    variables: {
      'context': 'Contexto',
    },
    content: '''# Tareas - {{context}}

**Fecha:** {{date}}

## 🔴 Alta Prioridad
- [ ] 

## 🟡 Media Prioridad
- [ ] 

## 🟢 Baja Prioridad
- [ ] 

## ✅ Completadas
- [x] 

## 📝 Notas

''',
  );

  static const recipe = NoteTemplate(
    id: 'recipe',
    name: 'Receta de Cocina',
    description: 'Receta con ingredientes y preparación',
    icon: Icons.restaurant_rounded,
    color: Color(0xFFEF4444),
    tags: ['receta', 'cocina'],
    variables: {
      'recipeName': 'Nombre de la receta',
      'servings': 'Porciones',
    },
    content: '''# 🍳 {{recipeName}}

**Porciones:** {{servings}}
**Tiempo de preparación:** 
**Tiempo de cocción:** 
**Dificultad:** 

## 🥘 Ingredientes
- 
- 
- 

## 👨‍🍳 Preparación

1. 
2. 
3. 

## 💡 Consejos y Variaciones


## 📸 Resultado
![]()

''',
  );

  static const project = NoteTemplate(
    id: 'project',
    name: 'Plan de Proyecto',
    description: 'Planificación de proyecto con objetivos',
    icon: Icons.rocket_launch_rounded,
    color: Color(0xFFF59E0B),
    tags: ['proyecto', 'planificación'],
    variables: {
      'projectName': 'Nombre del proyecto',
      'deadline': 'Fecha límite',
    },
    content: '''# 🚀 Proyecto: {{projectName}}

**Fecha de inicio:** {{date}}
**Fecha límite:** {{deadline}}
**Estado:** 🟡 En progreso

## 🎯 Objetivos
- 

## 📊 Alcance
**En alcance:**
- 

**Fuera de alcance:**
- 

## 👥 Equipo
- 

## 📅 Cronograma

| Fase | Tarea | Responsable | Fecha |
|------|-------|-------------|-------|
|      |       |             |       |

## 🚧 Riesgos e Impedimentos


## 📈 Métricas de Éxito


## 📝 Notas Adicionales

''',
  );

  static const learning = NoteTemplate(
    id: 'learning',
    name: 'Aprendizaje',
    description: 'Notas de estudio con resumen y conceptos',
    icon: Icons.school_rounded,
    color: Color(0xFF06B6D4),
    tags: ['aprendizaje', 'estudio'],
    variables: {
      'topic': 'Tema',
      'source': 'Fuente',
    },
    content: '''# 📚 {{topic}}

**Fecha:** {{date}}
**Fuente:** {{source}}

## 🎯 Objetivos de aprendizaje
- 

## 📝 Resumen


## 🔑 Conceptos clave
- **Concepto 1:** 
- **Concepto 2:** 

## 💡 Insights


## ❓ Preguntas pendientes


## 🔗 Referencias y recursos


## ✅ Para practicar
- [ ] 

''',
  );

  static const brainstorm = NoteTemplate(
    id: 'brainstorm',
    name: 'Lluvia de Ideas',
    description: 'Sesión de brainstorming con ideas y acciones',
    icon: Icons.lightbulb_rounded,
    color: Color(0xFFF43F5E),
    tags: ['ideas', 'creatividad'],
    variables: {
      'challenge': 'Desafío o pregunta',
    },
    content: '''# 💡 Lluvia de Ideas

**Fecha:** {{date}}
**Desafío:** {{challenge}}

## 🎨 Ideas locas (sin filtro)
- 
- 
- 

## ⭐ Ideas prometedoras
1. 
2. 
3. 

## ✅ Acciones a tomar
- [ ] 

## 🚫 Descartadas (¿por qué?)


## 🔄 Seguimiento

''',
  );

  static const weekly = NoteTemplate(
    id: 'weekly',
    name: 'Revisión Semanal',
    description: 'Revisión de logros y planes para la semana',
    icon: Icons.event_note_rounded,
    color: Color(0xFF6366F1),
    tags: ['revisión', 'planificación'],
    variables: {
      'weekNumber': 'Número de semana',
    },
    content: '''# 📅 Semana {{weekNumber}} - {{year}}

**Del:** 
**Al:** 

## ✨ Highlights de la semana
- 
- 
- 

## ✅ Logros completados
- 

## 📊 Métricas
- Notas creadas: 
- Tareas completadas: 
- Horas de trabajo: 

## 🎯 Objetivos cumplidos
- [ ] 
- [ ] 

## 🔄 En progreso
- 

## 🚧 Bloqueadores


## 📈 Plan para la próxima semana

**Prioridad 1:**

**Prioridad 2:**

**Prioridad 3:**

## 💭 Reflexiones


''',
  );

  /// Lista de todas las plantillas disponibles
  static List<NoteTemplate> get all => [
    daily,
    meeting,
    todo,
    recipe,
    project,
    learning,
    brainstorm,
    weekly,
  ];

  /// Obtener plantilla por ID
  static NoteTemplate? getById(String id) {
    try {
      return all.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}
