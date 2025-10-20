# Interactive Graph UI Layout

## Visual Layout Map

```
┌────────────────────────────────────────────────────────────────────────┐
│                         INTERACTIVE GRAPH PAGE                         │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  ┌──────────────┐                                                     │
│  │ 📊 Metrics   │  ◄── Metrics Panel (Top Left)                       │
│  │ Nodos: 25    │      • Node count                                   │
│  │ Enlaces: 47  │      • Connection count                             │
│  │ Clusters: 5  │      • Cluster count                                │
│  │ Central: X   │      • Most central node                            │
│  └──────────────┘                                                     │
│                                                                        │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │ 🔍  Buscar nodo o etiqueta...                          [✕]    │   │
│  └────────────────────────────────────────────────────────────────┘   │
│       ▲                                                                │
│       │                                                                │
│   Search Bar (Top Center)                                              │
│   • Real-time filtering                                                │
│   • Highlights matching nodes                                          │
│   • Glass-morphism design                                              │
│                                                                        │
│                                                                        │
│              ╭─────╮                                                   │
│           ╭──│  📝 │──╮                                                │
│         ╭─┴──╰─────╯──┴─╮                                             │
│        │ 💡            🔗 │         ◄── MAIN GRAPH CANVAS             │
│        │    ╭─────╮       │             • Interactive visualization   │
│        │ ──→│  📁 │←──    │             • Node connections            │
│        │    ╰─────╯       │             • Particle effects            │
│        │  ╱   🏷️    ╲     │             • Zoom & pan                  │
│         ╲─┬─────────┬─╱                                               │
│           │   💼    │                                                  │
│           ╰─────────╯                                                  │
│                                                                        │
│                                                                        │
│                                                 ┌──────────────────┐   │
│                                                 │ 🏷️ Clusters      │   │
│                                                 │ ────────────────  │   │
│                                                 │ 🔵 Trabajo       │   │
│                                                 │ 🟢 Personal      │   │
│                                                 │ 🟡 Ideas         │   │
│                                                 │ 🟣 Proyectos     │   │
│                                                 │                  │   │
│                                                 │ 🔄 Visualization │   │
│                                                 │ [Galaxy    ▼]    │   │
│                                                 │                  │   │
│                                                 │ 🔗 Umbral:       │   │
│                                                 │ ├────●─────────┤ │   │
│                                                 └──────────────────┘   │
│                                                          ▲              │
│                                                          │              │
│                                               Control Panel            │
│                                               (Bottom Right)            │
│                                               • Cluster legend          │
│                                               • Style selector          │
│                                               • Threshold slider        │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

## Component Positions

### Fixed Overlays (using Stack + Positioned)

```dart
Stack(
  children: [
    // 1. Main Canvas (fills entire area)
    LayoutBuilder(...),
    
    // 2. Search Bar
    Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: /* Search TextField */
    ),
    
    // 3. Control Panel (Legend + Controls)
    Positioned(
      bottom: 16,
      right: 16,
      child: _buildControlPanel(),
    ),
    
    // 4. Metrics Panel
    Positioned(
      top: 16,
      left: 16,
      child: _buildMetricsPanel(),
    ),
  ],
)
```

## Interactive Elements

### 1. Search Bar Interaction Flow
```
User Types → TextField onChange
           ↓
    Update _searchQuery
           ↓
    Filter _nodes by title/tags
           ↓
    Update _highlightedNodeIds Set
           ↓
    setState() triggers rebuild
           ↓
    Graph painter highlights matching nodes
```

### 2. Visualization Style Change Flow
```
User Selects Style → DropdownButton onChange
                   ↓
            Update _visualStyle
                   ↓
            Call _loadGraphWithAI()
                   ↓
            Recalculate node positions
                   ↓
            setState() triggers rebuild
                   ↓
            Graph updates with new layout
```

### 3. Threshold Adjustment Flow
```
User Drags Slider → Slider onChange
                  ↓
        Update _connectionThreshold
                  ↓
        Call _loadGraphWithAI()
                  ↓
        Filter edges by strength
                  ↓
        setState() triggers rebuild
                  ↓
        Graph shows filtered connections
```

## Responsive Behavior

### Search Bar
- **Width:** Spans from left: 16 to right: 16 (dynamic)
- **Height:** Auto (based on content)
- **Z-Index:** Above graph, below modal dialogs

### Control Panel
- **Width:** Auto (based on content, ~250-300px)
- **Height:** Auto (scales with cluster count)
- **Max Height:** Consider adding constraint for many clusters
- **Position:** Always bottom-right with 16px margin

### Metrics Panel
- **Width:** Auto (based on content, ~150-200px)
- **Height:** Auto (based on metrics shown)
- **Position:** Always top-left with 16px margin

## Color Coding System

### Cluster Colors
```
🔵 Blue     → Trabajo (Work)
🟢 Green    → Personal
🟡 Yellow   → Ideas
🟣 Purple   → Proyectos (Projects)
🔴 Red      → Salud (Health)
🟠 Orange   → Tecnología (Technology)
🟤 Lime     → Finanzas (Finance)
🔵 Cyan     → Educación (Education)
```

### UI Element Colors
```
Background Overlays:
  - Search Bar:    black @ 0.70 opacity
  - Control Panel: black @ 0.45 opacity
  - Metrics Panel: black @ 0.80 opacity

Text Colors:
  - Primary:   white (100%)
  - Secondary: white70 (70%)
  - Tertiary:  white54 (54%)

Borders:
  - All borders: white30 (30%)
```

## Spacing Grid (8px base)

```
Margins:
  - Screen edges:     16px (2 units)
  - Card padding:     12-16px (1.5-2 units)
  - Element spacing:  8-10px (1-1.25 units)
  - Compact spacing:  3-4px (0.375-0.5 units)

Border Radius:
  - Large cards:      16px
  - Medium elements:  12px
  - Small chips:      12px

Shadows:
  - Blur radius:      12-16px
  - Offset Y:         4-6px
  - Spread:           0px
  - Opacity:          0.18-0.22
```

## Typography Scale

```
Level         Size    Weight    Usage
────────────────────────────────────────────
Display       16px    Bold      Panel titles
Heading       15px    Bold      Section headers
Body          12-14px Regular   Main content
Caption       10px    Regular   Labels, metadata
Icon          16-20px -         UI icons
```

## Animation Suggestions

### Entrance Animations (Future)
```dart
// Search Bar: Slide down from top
AnimatedSlide(offset: Offset(0, -1) → Offset(0, 0))

// Panels: Fade + Scale in
AnimatedOpacity(0 → 1) + AnimatedScale(0.95 → 1)

// Cluster items: Staggered fade in
for each cluster with delay
```

### Interaction Animations (Future)
```dart
// Search clear button: Rotate + fade
AnimatedRotation(0 → 0.25) + AnimatedOpacity

// Slider: Smooth value transition
AnimatedValue with curve: Curves.easeInOut

// Dropdown: Ripple effect (already has InkWell)
```

## Accessibility Notes

### Screen Reader Support
- All IconButtons should have tooltips
- Search field has semantic label
- Dropdown has proper labeling
- Slider has value announcements

### Keyboard Navigation
- Tab through interactive elements
- Enter to activate buttons/dropdowns
- Arrow keys for slider adjustment
- Escape to clear search

### Color Contrast
- All text meets WCAG AA standards
- Icons have sufficient contrast
- Focus indicators visible
- Hover states clear

---

**Layout Version:** 1.0  
**Last Updated:** October 20, 2025  
**Compatible With:** Flutter 3.x+
