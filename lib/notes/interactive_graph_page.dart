import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../widgets/glass.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Vista de mapa mental/grafo interactivo mejorada
class InteractiveGraphPage extends StatefulWidget {
  const InteractiveGraphPage({super.key});

  @override
  State<InteractiveGraphPage> createState() => _InteractiveGraphPageState();
}

class _InteractiveGraphPageState extends State<InteractiveGraphPage> {
  late Future<void> _init;
  List<GraphNode> _nodes = [];
  List<GraphEdge> _edges = [];
  String? _selectedNodeId;
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  
  String get _uid => AuthService.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _init = _loadGraph();
  }

  Future<void> _loadGraph() async {
    final svc = FirestoreService.instance;
    final notes = await svc.listNotes(uid: _uid);
    final edges = await svc.listEdges(uid: _uid);
    
    // Crear nodos
    final nodes = <GraphNode>[];
    final size = Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height);
    
    for (var i = 0; i < notes.length; i++) {
      final note = notes[i];
      final id = note['id'].toString();
      final title = (note['title']?.toString() ?? 'Sin título').trim();
      final tags = note['tags'] as List?;
      
      // Posición inicial en círculo
      final angle = (i / notes.length) * 2 * math.pi;
      final radius = math.min(size.width, size.height) * 0.3;
      final x = size.width / 2 + radius * math.cos(angle);
      final y = size.height / 2 + radius * math.sin(angle);
      
      nodes.add(GraphNode(
        id: id,
        title: title.isEmpty ? id : title,
        position: Offset(x, y),
        color: _getColorForTags(tags),
        connectionCount: 0,
      ));
    }
    
    // Crear edges y contar conexiones
    final graphEdges = <GraphEdge>[];
    final connectionCounts = <String, int>{};
    
    for (var edge in edges) {
      final from = edge['from'] ?? '';
      final to = edge['to'] ?? '';
      graphEdges.add(GraphEdge(from: from, to: to));
      
      connectionCounts[from] = (connectionCounts[from] ?? 0) + 1;
      connectionCounts[to] = (connectionCounts[to] ?? 0) + 1;
    }
    
    // Actualizar conteo de conexiones
    for (var node in nodes) {
      node.connectionCount = connectionCounts[node.id] ?? 0;
    }
    
    setState(() {
      _nodes = nodes;
      _edges = graphEdges;
    });
  }

  Color _getColorForTags(List? tags) {
    if (tags == null || tags.isEmpty) return const Color(0xFF6366F1);
    
    final firstTag = tags[0].toString().toLowerCase();
    if (firstTag.contains('trabajo') || firstTag.contains('work')) {
      return const Color(0xFF3B82F6);
    } else if (firstTag.contains('personal')) {
      return const Color(0xFF10B981);
    } else if (firstTag.contains('idea')) {
      return const Color(0xFFF59E0B);
    } else if (firstTag.contains('proyecto') || firstTag.contains('project')) {
      return const Color(0xFF8B5CF6);
    }
    return const Color(0xFF6366F1);
  }

  void _onNodeDrag(String nodeId, Offset delta) {
    setState(() {
      final node = _nodes.firstWhere((n) => n.id == nodeId);
      node.position += delta;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa Mental'),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in_rounded),
            onPressed: () => setState(() => _scale = (_scale * 1.2).clamp(0.5, 3.0)),
            tooltip: 'Acercar',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out_rounded),
            onPressed: () => setState(() => _scale = (_scale / 1.2).clamp(0.5, 3.0)),
            tooltip: 'Alejar',
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong_rounded),
            onPressed: () => setState(() {
              _scale = 1.0;
              _offset = Offset.zero;
            }),
            tooltip: 'Centrar',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() => _init = _loadGraph()),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: GlassBackground(
        child: FutureBuilder(
          future: _init,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (_nodes.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hub_rounded, size: 64, color: Colors.white.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    const Text('No hay notas conectadas'),
                    const SizedBox(height: 8),
                    Text(
                      'Crea enlaces entre notas para ver el grafo',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              );
            }
            
            return Stack(
              children: [
                // Graph canvas
                GestureDetector(
                  onPanUpdate: (details) {
                    setState(() => _offset += details.delta);
                  },
                  child: ClipRect(
                    child: Transform(
                      transform: Matrix4.identity()
                        ..translateByDouble(_offset.dx, _offset.dy, 0.0, 0.0)
                        ..scaleByDouble(_scale, _scale, 1.0, 1.0),
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: GraphPainter(
                          nodes: _nodes,
                          edges: _edges,
                          selectedNodeId: _selectedNodeId,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Nodes overlay (draggable)
                ..._nodes.map((node) {
                  final isSelected = node.id == _selectedNodeId;
                  final position = _offset + (node.position * _scale);
                  
                  return Positioned(
                    left: position.dx - 30,
                    top: position.dy - 30,
                    child: GestureDetector(
                      onPanUpdate: (details) => _onNodeDrag(node.id, details.delta / _scale),
                      onTap: () => setState(() {
                        _selectedNodeId = isSelected ? null : node.id;
                      }),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: node.color.withValues(alpha: isSelected ? 1.0 : 0.8),
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.3),
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: node.color.withValues(alpha: 0.4),
                              blurRadius: isSelected ? 20 : 10,
                              spreadRadius: isSelected ? 2 : 0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.note_rounded, color: Colors.white, size: 24),
                              if (node.connectionCount > 0)
                                Text(
                                  '${node.connectionCount}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                
                // Info panel
                if (_selectedNodeId != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildNodeInfo(),
                      ),
                    ),
                  ),
                
                // Legend
                Positioned(
                  top: 16,
                  right: 16,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Leyenda',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          _LegendItem(color: const Color(0xFF3B82F6), label: 'Trabajo'),
                          _LegendItem(color: const Color(0xFF10B981), label: 'Personal'),
                          _LegendItem(color: const Color(0xFFF59E0B), label: 'Ideas'),
                          _LegendItem(color: const Color(0xFF8B5CF6), label: 'Proyectos'),
                          const SizedBox(height: 8),
                          Text(
                            'Zoom: ${_scale.toStringAsFixed(1)}x',
                            style: const TextStyle(fontSize: 11, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNodeInfo() {
    final node = _nodes.firstWhere((n) => n.id == _selectedNodeId);
    final connectedEdges = _edges.where(
      (e) => e.from == node.id || e.to == node.id,
    ).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: node.color,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                node.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => setState(() => _selectedNodeId = null),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Conexiones: ${node.connectionCount}',
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        if (connectedEdges.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Enlaces:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ...connectedEdges.take(3).map((edge) {
            final otherNodeId = edge.from == node.id ? edge.to : edge.from;
            final otherNode = _nodes.firstWhere((n) => n.id == otherNodeId, 
              orElse: () => GraphNode(id: otherNodeId, title: otherNodeId, position: Offset.zero, color: Colors.grey, connectionCount: 0));
            
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    edge.from == node.id ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                    size: 14,
                    color: Colors.white60,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      otherNode.title,
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

class GraphNode {
  final String id;
  final String title;
  Offset position;
  final Color color;
  int connectionCount;

  GraphNode({
    required this.id,
    required this.title,
    required this.position,
    required this.color,
    required this.connectionCount,
  });
}

class GraphEdge {
  final String from;
  final String to;

  GraphEdge({required this.from, required this.to});
}

class GraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final String? selectedNodeId;

  GraphPainter({
    required this.nodes,
    required this.edges,
    this.selectedNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final nodeMap = {for (var node in nodes) node.id: node};

    // Draw edges
    for (var edge in edges) {
      final fromNode = nodeMap[edge.from];
      final toNode = nodeMap[edge.to];

      if (fromNode != null && toNode != null) {
        final isHighlighted = edge.from == selectedNodeId || edge.to == selectedNodeId;
        
        paint.color = isHighlighted
            ? Colors.white.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.2);
        paint.strokeWidth = isHighlighted ? 3 : 1.5;

        canvas.drawLine(fromNode.position, toNode.position, paint);

        // Draw arrow
        if (isHighlighted) {
          _drawArrow(canvas, fromNode.position, toNode.position, paint);
        }
      }
    }
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    final direction = (to - from);
    final distance = direction.distance;
    if (distance == 0) return;
    
    final normalized = direction / distance;
    final arrowPos = to - normalized * 40; // 40 = node radius
    
    final arrowSize = 10.0;
    final angle = math.atan2(direction.dy, direction.dx);
    
    final p1 = arrowPos;
    final p2 = Offset(
      arrowPos.dx - arrowSize * math.cos(angle - math.pi / 6),
      arrowPos.dy - arrowSize * math.sin(angle - math.pi / 6),
    );
    final p3 = Offset(
      arrowPos.dx - arrowSize * math.cos(angle + math.pi / 6),
      arrowPos.dy - arrowSize * math.sin(angle + math.pi / 6),
    );
    
    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
    
    canvas.drawPath(path, paint..style = PaintingStyle.fill);
    paint.style = PaintingStyle.stroke;
  }

  @override
  bool shouldRepaint(GraphPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.edges != edges ||
        oldDelegate.selectedNodeId != selectedNodeId;
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
