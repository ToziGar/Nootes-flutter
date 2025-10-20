# Interactive Graph Page - Quick Reference

## Overview
The interactive graph visualization page with advanced UI features including clustering legend, search/filter, and metrics display.

## File Location
`lib/notes/interactive_graph_page.dart`

## Key Features Implemented

### 1. **Clustering Legend** (Bottom Right)
```dart
Widget _buildControlPanel() {
  return Card(
    color: Colors.black.withOpacity(0.45),
    // Shows cluster colors and names
    // Includes visualization style dropdown
    // Connection threshold slider
  );
}
```

**Position:** `Positioned(bottom: 16, right: 16)`

**What it shows:**
- 🎨 Color-coded circles for each cluster
- 📝 Cluster names with readable typography
- 🔄 Visualization style selector (Galaxy/Clusters/Hierarchy/Forces)
- 🎚️ Connection threshold slider

### 2. **Search Bar** (Top Center)
**Position:** `Positioned(top: 16, left: 16, right: 16)`

**Features:**
- 🔍 Real-time search across node titles and tags
- ✨ Highlights matching nodes in `_highlightedNodeIds`
- ❌ Clear button when search is active
- 💎 Glass-morphism design with blur effects

**Usage:**
```dart
onChanged: (query) {
  setState(() {
    _searchQuery = query.trim().toLowerCase();
    _highlightedNodeIds = _nodes
        .where((n) => n.title.toLowerCase().contains(_searchQuery) ||
                      n.tags.any((tag) => tag.toLowerCase().contains(_searchQuery)))
        .map((n) => n.id)
        .toSet();
  });
}
```

### 3. **Metrics Panel** (Top Left)
```dart
Widget _buildMetricsPanel() {
  return Positioned(
    top: 16,
    left: 16,
    child: Card(/* Shows graph statistics */),
  );
}
```

**Displays:**
- 📊 Total nodes count
- 🔗 Total connections count
- 🏷️ Number of clusters
- ⭐ Most central node

## State Variables

### Search & Highlighting
```dart
String _searchQuery = '';
Set<String> _highlightedNodeIds = {};
```

### Graph Data
```dart
List<AIGraphNode> _nodes = [];
List<AIGraphEdge> _edges = [];
List<NodeCluster> _clusters = [];
Map<String, double> _centrality = {};
```

### Visualization Controls
```dart
VisualizationStyle _visualStyle = VisualizationStyle.galaxy;
double _connectionThreshold = 0.5;
```

## Helper Methods

### Style & Display
- `_getStyleName(VisualizationStyle)` → Returns display name for visualization styles
- `_buildInfoChip(String, Color)` → Creates styled info chips
- `_getMostCentralNode()` → Finds the most central node in the graph

### Graph Filtering
- `_getFilteredEdges()` → Filters edges by type and strength
- `_getCategoryColor(String)` → Returns color for category

### UI Builders
- `_buildControlPanel()` → Builds the clustering legend and controls
- `_buildMetricsPanel()` → Builds the metrics display panel
- `_buildNodeInfoPanel()` → Builds detailed node information (when selected)

## Layout Structure

```
Scaffold
└── Stack
    ├── LayoutBuilder (Main Canvas)
    │   └── CustomPaint (AIGraphPainter)
    ├── Positioned (Search Bar - Top)
    │   └── DecoratedBox
    │       └── Material
    │           └── TextField
    ├── Positioned (Control Panel - Bottom Right)
    │   └── _buildControlPanel()
    └── Positioned (Metrics Panel - Top Left)
        └── _buildMetricsPanel()
```

## Styling Constants

### Colors
- **Background overlays:** `Colors.black.withOpacity(0.45-0.8)`
- **Text primary:** `Colors.white`
- **Text secondary:** `Colors.white70`
- **Text tertiary:** `Colors.white54`
- **Borders:** `Colors.white30`

### Spacing
- **Card padding:** `12-16px`
- **Border radius:** `12-16px`
- **Icon size:** `16-20px`
- **Font sizes:** Title (15-16px), Body (12-14px), Label (10px)

### Effects
- **Box shadow blur:** `12-16px`
- **Shadow offset:** `Offset(0, 4-6)`
- **Shadow opacity:** `0.18-0.22`

## Visualization Styles

```dart
enum VisualizationStyle {
  galaxy,    // 🌌 Galaxia - Spiral/orbital layout
  cluster,   // 🏷️ Clusters - Grouped by category
  hierarchy, // 📊 Jerarquía - Tree-based layout
  force      // ⚡ Fuerzas - Force-directed physics
}
```

## Usage Examples

### Updating Search Query
```dart
// In TextField onChanged
setState(() {
  _searchQuery = query.trim().toLowerCase();
  _highlightedNodeIds = _nodes
      .where((n) => /* match condition */)
      .map((n) => n.id)
      .toSet();
});
```

### Changing Visualization Style
```dart
// In DropdownButton onChanged
setState(() => _visualStyle = style);
_loadGraphWithAI();
```

### Adjusting Connection Threshold
```dart
// In Slider onChanged
setState(() => _connectionThreshold = value);
_loadGraphWithAI();
```

## Integration with Graph Painter

The UI overlays work with the `AIGraphPainter`:

```dart
CustomPaint(
  painter: AIGraphPainter(
    nodes: _nodes,
    edges: _getFilteredEdges(),
    highlightedNodeIds: _highlightedNodeIds, // ← From search
    // ... other parameters
  ),
)
```

## Testing Checklist

- [ ] Search bar filters nodes correctly
- [ ] Clear button appears/disappears appropriately
- [ ] Clustering legend displays all clusters
- [ ] Visualization style dropdown works
- [ ] Connection threshold slider updates graph
- [ ] Metrics panel shows correct statistics
- [ ] All UI elements are positioned correctly
- [ ] Shadows and blur effects render properly
- [ ] Text is readable on all backgrounds

## Performance Notes

- Search updates trigger `setState()` - consider debouncing for large graphs
- `_getFilteredEdges()` is called on every build - results could be cached
- Painter should implement proper caching for better performance

## Future Enhancements

1. **Advanced Filtering**
   - Filter by edge type
   - Filter by node category
   - Custom filters

2. **Node Details Panel**
   - Show when node is selected
   - Display connections and metadata
   - Edit node properties

3. **Animation Controls**
   - Play/pause particle effects
   - Speed controls
   - Layout animation toggles

4. **Export Features**
   - Save graph as image
   - Export data as JSON/CSV
   - Share via social media

---

**Last Updated:** October 20, 2025  
**Status:** ✅ Complete and functional
