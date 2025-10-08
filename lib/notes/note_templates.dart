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

  static const bugReport = NoteTemplate(
    id: 'bug_report',
    name: 'Reporte de Bug',
    description: 'Plantilla para documentar errores y bugs',
    icon: Icons.bug_report_rounded,
    color: Color(0xFFDC2626),
    tags: ['bug', 'desarrollo'],
    variables: {
      'bugTitle': 'Título del bug',
      'severity': 'Severidad',
    },
    content: '''# 🐛 Bug: {{bugTitle}}

**Fecha:** {{date}}
**Severidad:** {{severity}}
**Estado:** 🟡 Abierto

## 📝 Descripción
Describe el problema de manera clara y concisa.

## 🔄 Pasos para reproducir
1. 
2. 
3. 

## ✅ Resultado esperado
Qué debería pasar normalmente.

## ❌ Resultado actual
Qué está pasando en realidad.

## 🖼️ Capturas de pantalla
![]()

## 🌐 Entorno
- Sistema Operativo: 
- Navegador/Versión: 
- Versión de la aplicación: 

## 📝 Logs y mensajes de error
```
```

## 🔧 Solución propuesta


## ✅ Criterios de aceptación para el fix
- [ ] 

''',
  );

  static const codeSnippet = NoteTemplate(
    id: 'code_snippet',
    name: 'Snippet de Código',
    description: 'Guardar fragmentos de código útiles',
    icon: Icons.code_rounded,
    color: Color(0xFF059669),
    tags: ['código', 'desarrollo'],
    variables: {
      'snippetName': 'Nombre del snippet',
      'language': 'Lenguaje',
    },
    content: '''# 💻 {{snippetName}}

**Lenguaje:** {{language}}
**Fecha:** {{date}}
**Tags:** 

## 📝 Descripción
Para qué sirve este código.

## 🔧 Código
```{{language}}
// Tu código aquí
```

## 🎯 Caso de uso


## 📚 Documentación relacionada
- 

## ⚠️ Consideraciones


''',
  );

  static const interview = NoteTemplate(
    id: 'interview',
    name: 'Entrevista',
    description: 'Notas de entrevista con candidatos o usuarios',
    icon: Icons.person_pin_rounded,
    color: Color(0xFF7C3AED),
    tags: ['entrevista', 'rrhh'],
    variables: {
      'candidateName': 'Nombre del candidato',
      'position': 'Posición',
    },
    content: '''# 👤 Entrevista: {{candidateName}}

**Fecha:** {{date}} {{time}}
**Posición:** {{position}}
**Entrevistador(es):** 

## 📋 Información del candidato
- **Email:** 
- **Teléfono:** 
- **LinkedIn:** 

## 💼 Experiencia relevante


## 🎯 Evaluación de habilidades

| Skill | Rating (1-5) | Notas |
|-------|--------------|-------|
|       |              |       |

## 💡 Puntos fuertes
- 

## ⚠️ Áreas de mejora
- 

## ❓ Preguntas realizadas y respuestas


## 🤝 Fit cultural


## 📊 Evaluación final
**Rating general:** ⭐️ / 5
**Recomendación:** 

## 🔄 Siguientes pasos
- [ ] 

''',
  );

  static const retrospective = NoteTemplate(
    id: 'retrospective',
    name: 'Retrospectiva',
    description: 'Retrospectiva de sprint o proyecto',
    icon: Icons.history_rounded,
    color: Color(0xFFEA580C),
    tags: ['agile', 'retrospectiva'],
    variables: {
      'sprintName': 'Sprint o proyecto',
    },
    content: '''# 🔄 Retrospectiva: {{sprintName}}

**Fecha:** {{date}}
**Participantes:** 
**Facilitador:** 

## ✅ ¿Qué fue bien?
- 
- 
- 

## ❌ ¿Qué podemos mejorar?
- 
- 
- 

## 💡 ¿Qué vamos a probar?
- 
- 
- 

## 🎬 Action items
- [ ] **Responsable:** - **Fecha:** 

## 📊 Métricas del sprint
- Velocidad: 
- Tareas completadas: 
- Incidencias: 

## 💭 Comentarios adicionales


''',
  );

  static const productSpec = NoteTemplate(
    id: 'product_spec',
    name: 'Especificación de Producto',
    description: 'Documento de especificación de producto/feature',
    icon: Icons.article_rounded,
    color: Color(0xFF0891B2),
    tags: ['producto', 'especificación'],
    variables: {
      'featureName': 'Nombre de la feature',
      'pm': 'Product Manager',
    },
    content: '''# 📱 Spec: {{featureName}}

**PM:** {{pm}}
**Fecha:** {{date}}
**Estado:** 🟡 Borrador

## 🎯 Problema a resolver
¿Qué problema estamos tratando de solucionar y para quién?

## 💡 Solución propuesta


## 👥 Usuarios objetivo
- **Perfil 1:** 
- **Perfil 2:** 

## ✅ Casos de uso
1. **Como** [tipo de usuario], **quiero** [acción], **para** [beneficio]

## 📐 Requerimientos funcionales
- [ ] RF1: 
- [ ] RF2: 
- [ ] RF3: 

## 🚧 Requerimientos no funcionales
- **Performance:** 
- **Seguridad:** 
- **Accesibilidad:** 

## 🎨 Diseño UX/UI
![]()

## 🔧 Consideraciones técnicas


## 📊 Métricas de éxito
- KPI 1: 
- KPI 2: 

## 🗓️ Timeline
- Diseño: 
- Desarrollo: 
- QA: 
- Release: 

## ⚠️ Riesgos y dependencias


## ❓ Preguntas abiertas
- [ ] 

''',
  );

  static const travelPlan = NoteTemplate(
    id: 'travel_plan',
    name: 'Plan de Viaje',
    description: 'Itinerario y planificación de viajes',
    icon: Icons.flight_takeoff_rounded,
    color: Color(0xFF0EA5E9),
    tags: ['viaje', 'personal'],
    variables: {
      'destination': 'Destino',
      'dates': 'Fechas del viaje',
    },
    content: '''# ✈️ Viaje a {{destination}}

**Fechas:** {{dates}}
**Viajeros:** 

## 📋 Checklist pre-viaje
- [ ] Pasaporte/DNI
- [ ] Reservas de hotel
- [ ] Tickets de transporte
- [ ] Seguro de viaje
- [ ] Moneda local
- [ ] Adaptador de corriente

## 🗓️ Itinerario

### Día 1
- **Mañana:** 
- **Tarde:** 
- **Noche:** 

### Día 2
- **Mañana:** 
- **Tarde:** 
- **Noche:** 

## 🏨 Alojamiento
- **Hotel:** 
- **Dirección:** 
- **Check-in:** 
- **Check-out:** 

## 🍽️ Restaurantes recomendados
1. 
2. 

## 📍 Lugares de interés
- [ ] 
- [ ] 

## 💰 Presupuesto
- Alojamiento: 
- Transporte: 
- Comida: 
- Actividades: 
- **Total:** 

## 📝 Notas y consejos locales


## 📸 Mejores momentos del viaje
![]()

''',
  );

  static const workout = NoteTemplate(
    id: 'workout',
    name: 'Rutina de Ejercicio',
    description: 'Plan de entrenamiento y seguimiento',
    icon: Icons.fitness_center_rounded,
    color: Color(0xFFEC4899),
    tags: ['fitness', 'salud'],
    variables: {
      'workoutName': 'Nombre del workout',
    },
    content: '''# 💪 {{workoutName}}

**Fecha:** {{date}}
**Duración:** 
**Nivel:** 

## 🔥 Calentamiento (10 min)
- 
- 

## 🏋️ Ejercicios principales

### Ejercicio 1
- **Sets:** 
- **Reps:** 
- **Peso:** 
- **Descanso:** 

### Ejercicio 2
- **Sets:** 
- **Reps:** 
- **Peso:** 
- **Descanso:** 

## 🧘 Enfriamiento y estiramiento (5-10 min)
- 
- 

## 📊 Progreso
- Peso corporal: 
- Energía (1-10): 
- Dificultad (1-10): 

## 💭 Notas


''',
  );

  static const bookNotes = NoteTemplate(
    id: 'book_notes',
    name: 'Notas de Libro',
    description: 'Resumen y notas de libros leídos',
    icon: Icons.menu_book_rounded,
    color: Color(0xFF8B5CF6),
    tags: ['lectura', 'aprendizaje'],
    variables: {
      'bookTitle': 'Título del libro',
      'author': 'Autor',
    },
    content: '''# 📖 {{bookTitle}}

**Autor:** {{author}}
**Fecha de lectura:** {{date}}
**Rating:** ⭐️⭐️⭐️⭐️⭐️ / 5

## 📝 Resumen
Una breve descripción del libro en tus propias palabras.

## 🎯 Temas principales
1. 
2. 
3. 

## 💡 Ideas clave y citas

> "Cita memorable"

- **Idea 1:** 
- **Idea 2:** 

## 🤔 Reflexiones personales


## ✅ Aplicaciones prácticas
¿Cómo puedo aplicar lo aprendido en mi vida?

- [ ] 

## 📚 Libros relacionados
- 

## 🔗 Referencias y recursos


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
    bugReport,
    codeSnippet,
    interview,
    retrospective,
    productSpec,
    travelPlan,
    workout,
    bookNotes,
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
