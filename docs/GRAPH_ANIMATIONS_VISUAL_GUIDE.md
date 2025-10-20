# 🎬 Guía Visual de Animaciones del Grafo Interactivo

## 📋 Índice
1. [Animación del Panel de Información](#animacion-panel-info)
2. [Animación del Panel de Filtrado](#animacion-panel-filtrado)
3. [Gestos Interactivos](#gestos-interactivos)
4. [Estados de Transición](#estados-transicion)

---

## 1. 🎯 Animación del Panel de Información {#animacion-panel-info}

### Comportamiento: Slide-Up + Fade-In
**Duración**: 300ms | **Curva**: easeOutCubic

```
ESTADO INICIAL (t=0ms)          ESTADO INTERMEDIO (t=150ms)      ESTADO FINAL (t=300ms)
═══════════════════════════════════════════════════════════════════════════════

┌─────────────────────────┐    ┌─────────────────────────┐    ┌─────────────────────────┐
│                         │    │                         │    │                         │
│                         │    │                         │    │                         │
│      GRAPH  AREA        │    │      GRAPH  AREA        │    │      GRAPH  AREA        │
│                         │    │                         │    │                         │
│                         │    │                         │    │                         │
│                         │    │                         │    │    ┌─────────────────┐  │
│                         │    │    ┌─────────────────┐  │    │    │  📊 Node Info   │  │
│                         │    │    │  📊 Node Info   │  │    │    │                 │  │
│                         │    │    │  (50% opacity)  │  │    │    │  Title: Note 1  │  │
│                         │    │    │                 │  │    │    │  ⭐ 85%         │  │
│                         │    │    │  (50px up)      │  │    │    │  🔗 12 links    │  │
│                         │    │    └─────────────────┘  │    │    │  😊 Positive    │  │
│    ┌─────────────────┐  │    │                         │    │    └─────────────────┘  │
│    │  📊 Node Info   │  │    └─────────────────────────┘    └─────────────────────────┘
│    │  (invisible)    │  │         ↑ Translation: -50px          ↑ Translation: 0px
│    │  (100px down)   │  │         ↑ Opacity: 0.5                ↑ Opacity: 1.0
│    └─────────────────┘  │
└─────────────────────────┘
     ↑ Translation: +100px
     ↑ Opacity: 0.0
```

### Código de Animación:
```dart
TweenAnimationBuilder<double>(
  duration: Duration(milliseconds: 300),
  curve: Curves.easeOutCubic,
  tween: Tween(begin: 100.0, end: 0.0),
  builder: (context, offset, child) {
    return Transform.translate(
      offset: Offset(0, offset),           // ⬆️ Deslizar hacia arriba
      child: Opacity(
        opacity: 1.0 - (offset / 100.0),  // 🌟 Fade in
        child: child,
      ),
    );
  },
)
```

### Curva de Movimiento (easeOutCubic):
```
1.0 ┤                           ╭──────
    │                      ╭────╯
0.8 ┤                 ╭────╯
    │            ╭────╯
0.6 ┤       ╭────╯
    │  ╭────╯
0.4 ┤──╯
    │
0.2 ┤
    │
0.0 ┼─────┬─────┬─────┬─────┬─────┬────
    0    50   100  150  200  250  300ms
```

---

## 2. 🔗 Animación del Panel de Filtrado {#animacion-panel-filtrado}

### Comportamiento: Slide-In-From-Right + Fade-In
**Duración**: 400ms | **Curva**: easeOutBack (con rebote)

```
ESTADO INICIAL (t=0ms)          ESTADO INTERMEDIO (t=200ms)      ESTADO FINAL (t=400ms)
═══════════════════════════════════════════════════════════════════════════════

┌─────────────────────────┐    ┌─────────────────────────┐    ┌─────────────────────────┐
│                         │    │                    ┌────┐│    │                    ┌────┐
│      GRAPH  AREA        │    │      GRAPH  AREA   │🔗  ││    │      GRAPH  AREA   │🔗  │
│                         │    │                    │Fil ││    │                    │Filt│
│                         │    │                    │ter ││    │                    │ers │
│                         │    │                    │    ││    │                    │    │
│                         │    │                    │50% ││    │                    │💪  │
│                         │    │                    │opa ││    │                    │🧠  │
│                         │    │                    │city││    │                    │📝  │
│                         │    │                    │    ││    │                    │🔸  │
│                         │    │                    │-25 ││    │                    │🔗  │
│                         │    │                    │px  ││    │                    │    │
│                         │    │                    └────┘│    │                    └────┘
└─────────────────────────┘    └─────────────────────────┘    └─────────────────────────┘
                                     ← Translation: 25px             ← Translation: 0px
                                     ↑ Opacity: 0.5                  ↑ Opacity: 1.0

           ┌────┐
           │🔗  │
           │Fil │ ← INICIAL: +50px derecha
           │ter │   Opacity: 0.0
           │    │
           └────┘
```

### Código de Animación:
```dart
TweenAnimationBuilder<double>(
  duration: Duration(milliseconds: 400),
  curve: Curves.easeOutBack,  // 🏀 Efecto rebote
  tween: Tween(begin: 50.0, end: 0.0),
  builder: (context, offset, child) {
    return Transform.translate(
      offset: Offset(offset, 0),           // ⬅️ Deslizar desde derecha
      child: Opacity(
        opacity: 1.0 - (offset / 50.0),   // 🌟 Fade in
        child: child,
      ),
    );
  },
)
```

### Curva de Movimiento (easeOutBack con rebote):
```
1.0 ┤                                ╭─╮╭───
    │                           ╭────╯ ╰╯
0.8 ┤                      ╭────╯
    │                 ╭────╯
0.6 ┤            ╭────╯
    │       ╭────╯
0.4 ┤  ╭────╯
    │──╯
0.2 ┤
    │
0.0 ┼────┬────┬────┬────┬────┬────┬────
    0   50  100 150 200 250 300 350 400ms
         ↑                          ↑
      Aceleración               Pequeño rebote
```

---

## 3. 🎮 Gestos Interactivos {#gestos-interactivos}

### A. Pan (Arrastre)
```
GESTO DEL USUARIO:              RESPUESTA DEL GRAFO:
═══════════════════════════════════════════════════════

     👆                         ┌─────────────────────┐
     │ Arrastre               │    ╭─●───●──╮        │
     │ hacia abajo            │    │  \   /  │        │
     ↓                         │    ●───●───●         │
                              │     \  |  /          │
┌─────────────────────┐        │      ╰─●─╯          │
│    ╭─●───●──╮        │        └─────────────────────┘
│    │  \   /  │        │                ↓
│    ●───●───●         │        El grafo se mueve
│     \  |  /          │        siguiendo el dedo
│      ╰─●─╯          │
└─────────────────────┘
   ANTES                           DESPUÉS
```

### B. Zoom (Pellizco)
```
GESTO DEL USUARIO:              RESPUESTA DEL GRAFO:
═══════════════════════════════════════════════════════

    👆      👆                  ┌─────────────────────┐
     \      /                   │                     │
      \    /  Separar          │      ╭─●───●──╮     │
       \  /   dedos            │      │  \   /  │     │
        \/                     │      ●───●───●      │
                              │       \  |  /       │
┌─────────────────────┐        │        ╰─●─╯       │
│   ╭●─●╮              │        └─────────────────────┘
│   │\ /│              │         Zoom In (scale × 2)
│   ●─●─●              │
│    \|/               │
│     ●                │        ┌─────────────────────┐
└─────────────────────┘        │  ╭●╮                 │
   ANTES (scale = 1.0)         │  ●●●                 │
                              │   ●                  │
    👆      👆                  └─────────────────────┘
     \      /                    Zoom Out (scale × 0.5)
      \    /  Juntar
       \  /   dedos
        \/
```

### C. Tap (Selección)
```
GESTO DEL USUARIO:              RESPUESTA DEL GRAFO:
═══════════════════════════════════════════════════════

┌─────────────────────┐        ┌─────────────────────┐
│    ╭─●───●──╮        │        │    ╭─●───●──╮        │
│    │  \   /  │        │        │    │  \   /  │        │
│    ●───●───●         │ Tap   │    ●───◉───●         │
│     \  |  /       👆 │  →    │     \  |  /          │
│      ╰─●─╯          │        │      ╰─●─╯          │
│                     │        │                     │
└─────────────────────┘        │ ┌─────────────────┐ │
                              │ │ 📊 Node Info    │ │
                              │ │ Title: Note 2   │ │
                              │ │ ⭐ 75%          │ │
                              │ └─────────────────┘ │
                              └─────────────────────┘
    NODO NORMAL                    NODO SELECCIONADO
                                   + Panel de info
```

### D. Double Tap (Enfoque)
```
GESTO DEL USUARIO:              RESPUESTA DEL GRAFO:
═══════════════════════════════════════════════════════

┌─────────────────────┐        ┌─────────────────────┐
│ ●─────●─────●       │        │                     │
│  \    |    /         │        │      ╭─●───●──╮     │
│   ╰─●─●─●╮          │ 2×Tap │      │  \   /  │     │
│      \ |/  │      👆👆│  →    │      ●───◉───●      │
│       ●╯   │         │        │       \  |  /       │
│            │         │        │        ╰─●─╯       │
│            │         │        │                     │
└─────────────────────┘        └─────────────────────┘
   VISTA GENERAL                  ENFOCADO EN NODO
   (scale = 1.0)                  (centrado + zoom)
```

### E. Long Press (Menú Contextual)
```
GESTO DEL USUARIO:              RESPUESTA DEL GRAFO:
═══════════════════════════════════════════════════════

┌─────────────────────┐        ┌─────────────────────┐
│    ╭─●───●──╮        │        │    ╭─●───●──╮        │
│    │  \   /  │        │        │    │  \   /  │        │
│    ●───●───●         │        │    ●───◉───●         │
│     \  |  /          │        │     \  |  /          │
│      ╰─●─╯          │ Hold  │      ╰─●─╯    ┌─────┐│
│               👆     │  2s   │              │ 📄  ││
│                     │   →   │              │ ✏️  ││
└─────────────────────┘        │              │ 🗑️  ││
                              │              │ 🔗  ││
   NODO NORMAL                 │              │ 📋  ││
                              │              │ 🎯  ││
                              │              │ 🔗  ││
                              │              └─────┘│
                              └─────────────────────┘
                                 MENÚ CONTEXTUAL
```

---

## 4. 🔄 Estados de Transición {#estados-transicion}

### Ciclo de Vida del Panel de Información:

```
┌──────────────────────────────────────────────────────────────────┐
│                    CICLO DE VIDA DEL PANEL                       │
└──────────────────────────────────────────────────────────────────┘

    ┌─────────┐
    │ INICIO  │
    └────┬────┘
         │
         │ Usuario hace TAP en nodo
         ↓
    ┌─────────────────┐
    │ _selectedNodeId │
    │   = node.id     │
    └────┬────────────┘
         │
         │ setState() trigger
         ↓
    ┌──────────────────────────────────┐
    │  if (_selectedNodeId != null)    │
    │    _buildNodeInfoPanel()         │
    └────┬─────────────────────────────┘
         │
         │ TweenAnimationBuilder inicia
         ↓
    ┌──────────────────────────────────┐
    │  t=0ms:   offset=100px, α=0.0    │
    │  t=75ms:  offset=60px,  α=0.4    │
    │  t=150ms: offset=25px,  α=0.75   │
    │  t=225ms: offset=5px,   α=0.95   │
    │  t=300ms: offset=0px,   α=1.0    │
    └────┬─────────────────────────────┘
         │
         │ Panel completamente visible
         ↓
    ┌─────────────────┐
    │  PANEL VISIBLE  │
    │  Interactivo    │
    └────┬────────────┘
         │
         │ Usuario presiona ❌ o TAP fuera
         ↓
    ┌─────────────────┐
    │ _selectedNodeId │
    │   = null        │
    └────┬────────────┘
         │
         │ setState() trigger
         ↓
    ┌──────────────────────────────────┐
    │  Panel NO renderizado            │
    │  (condicional: if == null)       │
    └──────────────────────────────────┘
```

### Máquina de Estados de Gestos:

```
┌────────────────────────────────────────────────────────────────┐
│                    ESTADOS DE GESTOS                           │
└────────────────────────────────────────────────────────────────┘

           ┌──────────────┐
           │   IDLE       │
           │  (Esperando) │
           └───┬──────────┘
               │
       ┌───────┼───────┬───────┬───────────┐
       │       │       │       │           │
    1 toque  2 toques Hold  2×Tap    Wheel/Trackpad
       │       │       │       │           │
       ↓       ↓       ↓       ↓           ↓
   ┌─────┐ ┌─────┐ ┌──────┐ ┌──────┐  ┌──────┐
   │ TAP │ │SCALE│ │LONG  │ │DOUBLE│  │ ZOOM │
   │     │ │     │ │PRESS │ │TAP   │  │      │
   └──┬──┘ └──┬──┘ └───┬──┘ └───┬──┘  └───┬──┘
      │       │        │        │         │
      │       │        │        │         │
      │       │        │        │         │
      ↓       ↓        ↓        ↓         ↓
   ┌────┐  ┌────┐  ┌─────┐  ┌─────┐  ┌─────┐
   │Sel │  │Pan/│  │Menu │  │Focus│  │Scal │
   │Node│  │Zoom│  │Ctx. │  │Node │  │e    │
   └────┘  └────┘  └─────┘  └─────┘  └─────┘
      │       │        │        │         │
      └───────┴────────┴────────┴─────────┘
                      │
                      ↓
            ┌──────────────┐
            │  ACTUALIZAR  │
            │   VISTA      │
            └──────────────┘
```

---

## 5. 📊 Timing y Performance

### Comparación de Tiempos de Animación:

```
Panel de Info:    ████████████████████████████████░░░░░░░░  300ms  (Rápido)
Panel de Filtro:  ████████████████████████████████████████  400ms  (Normal)

Legend:
█ = Animación activa
░ = Tiempo libre

Recomendación:
- Paneles pequeños: 200-300ms
- Paneles medianos: 300-400ms
- Paneles grandes:  400-500ms
```

### FPS Target durante animaciones:

```
60 FPS ┤ ████████████████████████████████████████████  ← OBJETIVO
       │
50 FPS ┤ ██████████████████████████████
       │
40 FPS ┤ ████████████████████
       │
30 FPS ┤ ████████████      ← Mínimo aceptable
       │
       └─────┬─────┬─────┬─────┬─────┬─────
            0    50   100  150  200  250  300ms

Optimizaciones:
✅ Hardware acceleration (Transform + Opacity)
✅ Avoid layout thrashing
✅ Use const constructors
✅ Minimize rebuilds with setState()
```

---

## 6. 🎨 Paleta de Curvas de Easing

### Comparación Visual:

```
Linear:
1.0 ┤        ╱
    │       ╱
0.5 ┤      ╱
    │     ╱
0.0 ┼────╱────────

easeOutCubic (Panel Info):
1.0 ┤           ╭──────
    │      ╭────╯
0.5 ┤ ╭────╯
    │─╯
0.0 ┼────────────

easeOutBack (Panel Filtro):
1.0 ┤                ╭─╮╭──
    │           ╭────╯ ╰╯
0.5 ┤      ╭────╯
    │─╭────╯
0.0 ┼──────────────

easeInOutQuart (Alternativa):
1.0 ┤              ╭────
    │         ╭────╯
0.5 ┤    ╭────╯
    │────╯
0.0 ┼────────────────
```

---

## 7. 🔧 Tips de Implementación

### ✅ DO (Hacer):
```dart
// ✅ Usa TweenAnimationBuilder para animaciones simples
TweenAnimationBuilder<double>(
  duration: Duration(milliseconds: 300),
  tween: Tween(begin: 0.0, end: 1.0),
  builder: (context, value, child) => ...
)

// ✅ Combina Transform y Opacity
Transform.translate(
  offset: Offset(0, offset),
  child: Opacity(
    opacity: value,
    child: child,
  ),
)

// ✅ Usa curvas apropiadas
curve: Curves.easeOutCubic  // Para UI suave
curve: Curves.easeOutBack   // Para efecto rebote
```

### ❌ DON'T (No hacer):
```dart
// ❌ Evita AnimationController para animaciones simples
AnimationController controller = AnimationController(...)
Animation animation = Tween(...).animate(controller)
// Demasiado código para algo simple

// ❌ No uses setState() dentro de builder
builder: (context, value, child) {
  setState(() { ... })  // ❌ NUNCA
  return Widget()
}

// ❌ No animes propiedades pesadas
// Evita animar: size, padding (causa relayout)
// Prefiere: transform, opacity (GPU accelerated)
```

---

## 8. 📱 Responsive Design

### Breakpoints para Paneles:

```
┌─────────────────────────────────────────────────────────┐
│                   RESPONSIVE LAYOUT                     │
└─────────────────────────────────────────────────────────┘

Mobile (< 600px):
┌────────────┐
│  🔍 Search │  ← Top, full width
├────────────┤
│            │
│   GRAPH    │  ← Main area
│            │
├────────────┤
│ 📊 Info    │  ← Bottom, full width
└────────────┘

Tablet (600-900px):
┌──┬─────────┬───┐
│📊│  🔍     │🔗 │
├──┤         │Fil│
│  │  GRAPH  │ter│
│  │         │   │
├──┴─────────┴───┤
│  📊 Info Panel │
└────────────────┘

Desktop (> 900px):
┌──┬──────────────┬───┐
│📊│  🔍 Search   │🔗 │
├──┤              │Fil│
│  │              │ter│
│  │    GRAPH     │   │
│  │              │🎨 │
│  │              │Leg│
├──┴──────────────┴end┤
│   📊 Info Panel     │
└─────────────────────┘
```

---

## 9. 🎯 Casos de Uso

### Flujo: Explorar Nota
```
1. Usuario ve el grafo
   ↓
2. Usuario hace TAP en nodo de interés
   ↓
3. Panel de Info se desliza hacia arriba (300ms)
   ↓
4. Usuario revisa información
   ↓
5. Usuario hace LONG PRESS en nodo
   ↓
6. Aparece menú contextual
   ↓
7. Usuario selecciona "Abrir nota"
   ↓
8. Navega a NoteEditorPage
```

### Flujo: Filtrar Conexiones
```
1. Usuario abre la app
   ↓
2. Panel de Filtro se desliza desde derecha (400ms)
   ↓
3. Usuario ajusta slider de fuerza mínima
   ↓
4. Grafo actualiza edges en tiempo real
   ↓
5. Usuario desmarca tipo "Débil"
   ↓
6. Edges débiles desaparecen inmediatamente
   ↓
7. Grafo muestra solo conexiones relevantes
```

---

**Versión**: 2.0.0  
**Fecha**: 2024  
**Build Status**: ✅ Exitoso (11.6s)  
**Autor**: GitHub Copilot
