// ignore_for_file: unused_element, unused_field

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'edge_editor_dialog.dart';
import 'note_editor_page.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/toast_service.dart';
import '../theme/app_colors.dart';
import '../theme/color_utils.dart';

// ==== TOP-LEVEL CLASSES AND STUBS ====
class AIGraphPainter extends CustomPainter {
  AIGraphPainter({
    required this.nodes,
    required this.edges,
    required this.particles,
    required this.floatingParticles,
    required this.selectedNodeId,
    required this.hoveredNodeId,
    required this.scale,
    required this.offset,
    required this.is3DMode,
    required this.pulseValue,
    required this.rotationValue,
    required this.clusters,
    required this.centrality,
    required this.draggingFromNodeId,
    required this.draggingPosition,
    required this.highlightedNodeIds,
    required this.draggingNodeId,
  });
  final List<AIGraphNode> nodes;
  final List<AIGraphEdge> edges;
  final List<ParticleConnection> particles;
  final List<FloatingParticle> floatingParticles;
  final String? selectedNodeId;
  final String? hoveredNodeId;
  final double scale;
  final Offset offset;
  final bool is3DMode;
  final double pulseValue;
  final double rotationValue;
  final List<NodeCluster> clusters;
  final Map<String, double> centrality;
  final String? draggingFromNodeId;
  final Offset? draggingPosition;
  final Set<String> highlightedNodeIds;
  final String? draggingNodeId;
  @override
  void paint(Canvas canvas, Size size) {
    // Draw enhanced particles with glow and trails
    _drawEnhancedParticles(canvas);
    
    // Draw node glow effects for important nodes
    _drawNodeGlowEffects(canvas);
    
    // Draw drag-to-link line when in link mode
    if (draggingFromNodeId != null && draggingPosition != null) {
      final sourceNode = nodes.firstWhere(
        (n) => n.id == draggingFromNodeId,
        orElse: () => nodes.first,
      );
      
      if (sourceNode.id == draggingFromNodeId) {
        final paint = Paint()
          ..color = Colors.orange.withOpacity(0.7)
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke;
        
        // Draw dashed line from source node to cursor
        final start = (sourceNode.position * scale) + offset;
        final end = (draggingPosition! * scale) + offset;
        
        _drawDashedLine(canvas, start, end, paint);
        
        // Draw arrow at cursor
        final arrowPaint = Paint()
          ..color = Colors.orange
          ..style = PaintingStyle.fill;
        
        final arrowSize = 12.0;
        final angle = (end - start).direction;
        final arrowPath = Path()
          ..moveTo(end.dx, end.dy)
          ..lineTo(
            end.dx - arrowSize * math.cos(angle - math.pi / 6),
            end.dy - arrowSize * math.sin(angle - math.pi / 6),
          )
          ..lineTo(
            end.dx - arrowSize * math.cos(angle + math.pi / 6),
            end.dy - arrowSize * math.sin(angle + math.pi / 6),
          )
          ..close();
        
        canvas.drawPath(arrowPath, arrowPaint);
        
        // Highlight source node
        final highlightPaint = Paint()
          ..color = Colors.orange.withOpacity(0.3)
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(start, 45 * scale, highlightPaint);
      }
    }
  }
  
  void _drawEnhancedParticles(Canvas canvas) {
    for (var particle in floatingParticles) {
      if (particle.life <= 0) continue;
      
      final pos = (particle.position * scale) + offset;
      
      // Draw particle trail
      if (particle.trail.length > 1) {
        final trailPaint = Paint()
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        
        for (int i = 0; i < particle.trail.length - 1; i++) {
          final trailAlpha = (i / particle.trail.length) * particle.life;
          trailPaint.color = particle.color.withOpacity(trailAlpha * 0.3);
          
          final p1 = (particle.trail[i] * scale) + offset;
          final p2 = (particle.trail[i + 1] * scale) + offset;
          canvas.drawLine(p1, p2, trailPaint);
        }
      }
      
      // Draw particle glow (outer halo)
      final glowRadius = particle.size * 3 * particle.glow * scale;
      final glowPaint = Paint()
        ..color = particle.color.withOpacity(particle.life * 0.2 * particle.glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 0.5);
      
      canvas.drawCircle(pos, glowRadius, glowPaint);
      
      // Draw particle core (bright center)
      final corePaint = Paint()
        ..color = particle.color.withOpacity(particle.life * 0.8)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(pos, particle.size * scale, corePaint);
    }
  }
  
  void _drawNodeGlowEffects(Canvas canvas) {
    for (var node in nodes) {
      // Only draw glow for important nodes or selected/hovered nodes
      final isSpecial = node.id == selectedNodeId || 
                       node.id == hoveredNodeId || 
                       highlightedNodeIds.contains(node.id);
      final shouldGlow = node.importance > 0.7 || isSpecial;
      
      if (!shouldGlow) continue;
      
      final pos = (node.position * scale) + offset;
      final glowIntensity = isSpecial ? 1.0 : node.importance;
      final pulseEffect = 0.8 + (math.sin(pulseValue * 2 * math.pi) * 0.2);
      
      // Multiple glow layers for depth
      final layers = [
        (radius: 60.0 * scale, opacity: 0.15 * glowIntensity * pulseEffect),
        (radius: 40.0 * scale, opacity: 0.25 * glowIntensity * pulseEffect),
        (radius: 25.0 * scale, opacity: 0.35 * glowIntensity * pulseEffect),
      ];
      
      for (var layer in layers) {
        final glowPaint = Paint()
          ..color = node.color.withOpacity(layer.opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, layer.radius * 0.4);
        
        canvas.drawCircle(pos, layer.radius, glowPaint);
      }
    }
  }
  
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 8.0;
    const dashSpace = 4.0;
    final distance = (end - start).distance;
    final dashCount = (distance / (dashWidth + dashSpace)).floor();
    
    for (int i = 0; i < dashCount; i++) {
      final dashStart = start + (end - start) * ((i * (dashWidth + dashSpace)) / distance);
      final dashEnd = start + (end - start) * (((i * (dashWidth + dashSpace)) + dashWidth) / distance);
      canvas.drawLine(dashStart, dashEnd, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

Offset _calculateClusterPosition(int index, int total, ContentAnalysis analysis, Size size) {
  // TODO: Implement cluster position logic
  return Offset.zero;
}

Offset _calculateHierarchyPosition(int index, int total, ContentAnalysis analysis, Size size) {
  // TODO: Implement hierarchy position logic
  return Offset.zero;
}

Offset _calculateForcePosition(int index, int total, ContentAnalysis analysis, Size size) {
  // TODO: Implement force-directed position logic
  return Offset.zero;
}

// ==== MODEL CLASSES, ENUMS, EXTENSIONS (must be top-level) ====
class AIGraphNode {
  final String id;
  final String title;
  final String content;
  final List<String> tags;
  Offset position;
  Offset velocity;
  final Color color;
  int connectionCount;
  final ContentAnalysis aiAnalysis;
  final double importance;
  int depth;
  String cluster;

  AIGraphNode({
    required this.id,
    required this.title,
    required this.content,
    required this.tags,
    required this.position,
    required this.velocity,
    required this.color,
    required this.connectionCount,
    required this.aiAnalysis,
    required this.importance,
    required this.depth,
    required this.cluster,
  });
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'tags': tags,
      'position': {'dx': position.dx, 'dy': position.dy},
      'color': color.value,
      'connectionCount': connectionCount,
      'importance': importance,
      'depth': depth,
      'cluster': cluster,
      'aiAnalysis': {
        'themes': aiAnalysis.themes,
        'keywords': aiAnalysis.keywords,
        'sentiment': aiAnalysis.sentiment,
        'importance': aiAnalysis.importance,
        'category': aiAnalysis.category,
        'wordCount': aiAnalysis.wordCount,
        'complexity': aiAnalysis.complexity,
      },
    };
  }
}

class AIGraphEdge {
  final String from;
  final String to;
  final double strength;
  final EdgeType type;
  final String label;
  const AIGraphEdge({
    required this.from,
    required this.to,
    required this.strength,
    required this.type,
    required this.label,
  });
  Map<String, dynamic> toJson() {
    return {
      'from': from,
      'to': to,
      'strength': strength,
      'type': type.toString().split('.').last,
      'label': label,
    };
  }
}

class ParticleConnection {
  final String from;
  final String to;
  final double strength;
  final double phase;
  const ParticleConnection({
    required this.from,
    required this.to,
    required this.strength,
    required this.phase,
  });
}

class FloatingParticle {
  Offset position;
  Offset velocity;
  final double size;
  double life;
  final Color color;
  final List<Offset> trail;
  Offset acceleration;
  double glow;
  
  FloatingParticle({
    required this.position,
    Offset? velocity,
    double? size,
    double? life,
    Color? color,
  }) : velocity =
           velocity ??
           Offset(
             (math.Random().nextDouble() - 0.5) * 2,
             (math.Random().nextDouble() - 0.5) * 2,
           ),
       size = size ?? (2 + math.Random().nextDouble() * 4),
       life = life ?? 1.0,
       color = color ?? Colors.blue.withOpacity(0.6),
       trail = [],
       acceleration = Offset.zero,
       glow = 0.5 + math.Random().nextDouble() * 0.5;
  
  void update({List<AIGraphNode>? nodes, double? deltaTime}) {
    final dt = deltaTime ?? 1.0;
    
    // Add current position to trail
    trail.add(position);
    if (trail.length > 15) {
      trail.removeAt(0);
    }
    
    // Apply node attraction physics
    if (nodes != null && nodes.isNotEmpty) {
      Offset totalForce = Offset.zero;
      for (var node in nodes) {
        final distance = (node.position - position).distance;
        if (distance > 0 && distance < 300) {
          // Attraction force (inverse square law)
          final direction = (node.position - position) / distance;
          final forceMagnitude = (node.importance * 50) / (distance * distance + 1);
          totalForce += direction * forceMagnitude;
        }
      }
      acceleration = totalForce * 0.1;
    }
    
    // Update velocity with acceleration and damping
    velocity += acceleration * dt;
    velocity *= 0.98; // Damping
    
    // Update position
    position += velocity * dt;
    
    // Update life and glow
    life -= 0.008 * dt;
    glow = (0.5 + math.sin(life * math.pi * 4) * 0.3).clamp(0.0, 1.0);
  }
}

class ContentAnalysis {
  double get score => importance;
  final List<String> themes;
  final List<String> keywords;
  final double sentiment;
  final double importance;
  final String category;
  final int wordCount;
  final double complexity;
  const ContentAnalysis({
    required this.themes,
    required this.keywords,
    required this.sentiment,
    required this.importance,
    required this.category,
    required this.wordCount,
    required this.complexity,
  });
}

class NodeCluster {
  final String id;
  final String name;
  final List<String> nodeIds;
  final Color color;
  const NodeCluster({
    required this.id,
    required this.name,
    required this.nodeIds,
    required this.color,
  });
}

enum EdgeType { strong, semantic, thematic, weak, manual }
enum NodeClusteringMode { semantic, connectivity, importance }
enum VisualizationStyle { galaxy, cluster, hierarchy, force }

extension OffsetExtensions on Offset {
  Offset normalized() {
    final d = distance;
    return d > 0 ? this / d : Offset.zero;
  }
}

/// 🧠 Mapa Mental Unificado (IA + Interactivo)
/// Esta implementación reemplaza la versión anterior y combina las
/// capacidades de análisis semántico y renderizado avanzado en una sola
/// página: `InteractiveGraphPage`.
class InteractiveGraphPage extends StatefulWidget {
  const InteractiveGraphPage({super.key});

  @override
  State<InteractiveGraphPage> createState() => _InteractiveGraphPageState();
}

class _InteractiveGraphPageState extends State<InteractiveGraphPage> with TickerProviderStateMixin {
  // Move helpers above first use
  String _getStyleName(VisualizationStyle style) {
    switch (style) {
      case VisualizationStyle.galaxy:
        return '🌌 Galaxia';
      case VisualizationStyle.cluster:
        return '🏷️ Clusters';
      case VisualizationStyle.hierarchy:
        return '📊 Jerarquía';
      case VisualizationStyle.force:
        return '⚡ Fuerzas';
    }
  }

  Widget _buildInfoChip(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacityCompat(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacityCompat(0.5)),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, color: color)),
      ),
    );
  }

  Future<void> _showNodeEdgeManager(String nodeId) async {
    // TODO: Implement node edge manager dialog
  }
  // Search/filter state
  String _searchQuery = '';
  Set<String> _highlightedNodeIds = {};
  // late Future<void> _init; // Reserved for future initialization
  // Keep a FocusNode instead of creating one in build continuously
  final FocusNode _keyboardFocusNode = FocusNode();
  
  // RepaintBoundary key for export
  final GlobalKey _graphKey = GlobalKey();
  
  List<AIGraphNode> _nodes = [];
  List<AIGraphEdge> _edges = [];
  final List<ParticleConnection> _particles = [];
  String? _selectedNodeId;
  String? _hoveredNodeId;
  // Drag-to-link state
  bool _isLinkMode = false;
  String? _draggingFromNodeId;
  Offset? _draggingCurrentPosition; // in canvas coordinates (post-transform)

  // Node dragging state
  String? _draggingNodeId;
  Offset? _nodeDragStartPosition;
  bool _isNodeDragging = false;
  bool _snapToGrid = false;
  final double _gridSize = 50.0;

  // Edge filtering
  final Set<EdgeType> _visibleEdgeTypes = EdgeType.values.toSet();
  double _minEdgeStrength = 0.0;
  bool _showEdgeLabels = true;

  // Controls
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  Offset _lastFocalPoint = Offset.zero;
  final bool _is3DMode = true;
  final bool _showParticles = !kIsWeb; // Disable particles on web by default for better performance
  bool _autoLayout = true;

  // Minimal UI mode to reduce clutter (show only graph)
  bool _minimalMode = true;

  // IA settings
  final NodeClusteringMode _clusteringMode = NodeClusteringMode.semantic;
  VisualizationStyle _visualStyle = VisualizationStyle.galaxy;
  double _connectionThreshold = 0.3;

  // Animations
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _particleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  // Particles
  Timer? _layoutTimer;
  Timer? _particleTimer;
  final List<FloatingParticle> _floatingParticles = [];

  Map<String, double> _centrality = {};
  List<NodeCluster> _clusters = [];

  String get _uid => AuthService.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_pulseController);
    
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_rotationController);
    
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..addListener(_updateParticles);
    _particleController.repeat();
    
    // Initialize particles
    _initializeParticles();
    
    // Load graph data
    _loadGraphWithAI();
  }

  Future<void> _loadGraphWithAI() async {
    try {
      print('[_loadGraphWithAI] starting load');
      // Fetch user notes (exclude trashed)
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('notes')
          .where('trashed', isEqualTo: false)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _nodes = [];
          _edges = [];
        });
        return;
      }

      final List<AIGraphNode> nodes = [];

      // Basic conversion: create node per note and simple content analysis
      for (int idx = 0; idx < querySnapshot.docs.length; idx++) {
        final doc = querySnapshot.docs[idx];
        final data = doc.data();
        final noteId = doc.id;
        final title = (data['title'] as String?) ?? '';
        final content = (data['content'] as String?) ?? '';
        final tags = (data['tags'] as List?)?.whereType<String>().toList() ?? <String>[];

        final analysis = _analyzeContent(title, content, tags);

        // initial position using intelligent position helper
        final position = _calculateIntelligentPosition(idx, querySnapshot.docs.length, analysis, MediaQuery.of(context).size);

        final color = _determineNodeColor(tags, analysis);

        final node = AIGraphNode(
          id: noteId,
          title: title,
          content: content,
          tags: tags,
          position: position,
          velocity: Offset.zero,
          color: color,
          connectionCount: 0,
          aiAnalysis: analysis,
          importance: analysis.importance,
          depth: 0,
          cluster: analysis.category,
        );

        nodes.add(node);
      }

      // Build edges using a simple similarity metric (tag overlap + keyword overlap)
      final List<AIGraphEdge> edges = [];
      for (int i = 0; i < nodes.length; i++) {
        for (int j = i + 1; j < nodes.length; j++) {
          final sim = _calculateSimilarity(nodes[i], nodes[j]);
          if (sim >= _connectionThreshold) {
            final edgeType = _determineEdgeType(sim);
            edges.add(AIGraphEdge(
              from: nodes[i].id,
              to: nodes[j].id,
              strength: sim,
              type: edgeType,
              label: edgeType.toString().split('.').last,
            ));
            nodes[i].connectionCount++;
            nodes[j].connectionCount++;
          }
        }
      }

      _centrality = _calculateCentrality(nodes, edges);
      _clusters = _calculateClusters(nodes, edges);

      if (_autoLayout) {
        _applyLayoutAlgorithm(nodes, edges);
      }

      if (mounted) {
        setState(() {
          _nodes = nodes;
          _edges = edges;
        });
      }
      print('[_loadGraphWithAI] loaded nodes=${nodes.length} edges=${edges.length}');
    } catch (e, st) {
      // Show toast but don't crash
      try {
        ToastService.error('Error cargando grafo: $e');
      } catch (_) {}
      // ignore: avoid_print
      print('Error in _loadGraphWithAI: $e\n$st');
    }
  }

  // Minimal content analysis: extract basic metadata and keywords
  ContentAnalysis _analyzeContent(String title, String content, List<String> tags) {
    final combined = '$title\n$content';
    final words = combined.split(RegExp(r'\W+')).where((s) => s.isNotEmpty).toList();
    final keywords = words.take(10).map((s) => s.toLowerCase()).toSet().toList();
    final themes = tags.toSet().toList();
    final importance = (keywords.length / (words.length + 1)).clamp(0.0, 1.0);
    final sentiment = 0.0; // placeholder
    final category = themes.isNotEmpty ? themes.first : 'general';
    final wordCount = words.length;
    final complexity = _calculateComplexity(content);
    return ContentAnalysis(
      themes: themes,
      keywords: keywords,
      sentiment: sentiment,
      importance: importance,
      category: category,
      wordCount: wordCount,
      complexity: complexity,
    );
  }

  Color _determineNodeColor(List<String> tags, ContentAnalysis analysis) {
    if (tags.isNotEmpty) return AppColors.primary;
    final v = (analysis.importance * 255).toInt();
    return Color.fromARGB(255, 100 + v ~/ 2, 150, 200);
  }

  double _calculateSimilarity(AIGraphNode a, AIGraphNode b) {
    // Simple similarity: tag overlap + keyword overlap normalized
    final tagOverlap = a.tags.toSet().intersection(b.tags.toSet()).length.toDouble();
    final keywordOverlap = a.aiAnalysis.keywords.toSet().intersection(b.aiAnalysis.keywords.toSet()).length.toDouble();
    final denom = (a.tags.length + b.tags.length + a.aiAnalysis.keywords.length + b.aiAnalysis.keywords.length + 1);
    return ((tagOverlap * 2) + keywordOverlap) / denom;
  }

  EdgeType _determineEdgeType(double similarity) {
    if (similarity > 0.7) return EdgeType.strong;
    if (similarity > 0.45) return EdgeType.semantic;
    if (similarity > 0.25) return EdgeType.thematic;
    return EdgeType.weak;
  }

  List<NodeCluster> _calculateClusters(List<AIGraphNode> nodes, List<AIGraphEdge> edges) {
    // Very small heuristic: group by category from analysis
    final Map<String, List<String>> byCat = {};
    for (var n in nodes) {
      byCat.putIfAbsent(n.cluster, () => []).add(n.id);
    }
    final clusters = <NodeCluster>[];
    int i = 0;
    for (var entry in byCat.entries) {
      clusters.add(NodeCluster(id: 'c\$i', name: entry.key, nodeIds: entry.value, color: Colors.primaries[i % Colors.primaries.length]));
      i++;
    }
    return clusters;
  }

  void _applyLayoutAlgorithm(List<AIGraphNode> nodes, List<AIGraphEdge> edges) {
    // Basic force-directed relaxation: small number of iterations
    final int iterations = 200;
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;
    for (int it = 0; it < iterations; it++) {
      for (var n in nodes) {
        final fx = (width / 2 - n.position.dx) * 0.001;
        final fy = (height / 2 - n.position.dy) * 0.001;
        n.velocity = n.velocity + Offset(fx, fy);
      }
      for (var e in edges) {
  final ai = nodes.indexWhere((x) => x.id == e.from);
  final bi = nodes.indexWhere((x) => x.id == e.to);
  if (ai == -1 || bi == -1) continue;
  final AIGraphNode a = nodes[ai];
  final AIGraphNode b = nodes[bi];
  final delta = b.position - a.position;
        final dist = delta.distance;
        final desired = 100.0; // ideal link length
        final diff = (dist - desired) / (dist + 0.0001);
        final shift = delta * (0.01 * diff);
        a.position = a.position + shift;
        b.position = b.position - shift;
      }
    }
  }
  
  void _initializeParticles() {
    // Create initial floating particles
    for (int i = 0; i < 30; i++) {
      _floatingParticles.add(FloatingParticle(
        position: Offset(
          math.Random().nextDouble() * 1000 - 500,
          math.Random().nextDouble() * 1000 - 500,
        ),
        color: _getRandomParticleColor(),
      ));
    }
  }
  
  Color _getRandomParticleColor() {
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.cyan,
      Colors.teal,
      Colors.indigo,
    ];
    return colors[math.Random().nextInt(colors.length)].withOpacity(0.6);
  }
  
  void _updateParticles() {
    if (!_showParticles || _floatingParticles.isEmpty) return;
    
    setState(() {
      // Update all particles with enhanced physics
      for (var particle in _floatingParticles) {
        particle.update(nodes: _nodes, deltaTime: 0.05);
        
        // Respawn dead particles
        if (particle.life <= 0) {
          particle.position = Offset(
            math.Random().nextDouble() * 1000 - 500,
            math.Random().nextDouble() * 1000 - 500,
          );
          particle.velocity = Offset(
            (math.Random().nextDouble() - 0.5) * 2,
            (math.Random().nextDouble() - 0.5) * 2,
          );
          particle.life = 1.0;
          particle.trail.clear();
        }
      }
    });
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _particleController.dispose();
    _layoutTimer?.cancel();
    _particleTimer?.cancel();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  // Helper method for future sentiment analysis features
  double _calculateSentiment(List<String> words) {
    final positiveWords = [
      'bueno',
      'excelente',
      'genial',
      'amazing',
      'good',
      'great',
    ];
    final negativeWords = [
      'malo',
      'terrible',
      'bad',
      'awful',
      'problema',
      'error',
    ];
    double score = 0.0;
    for (var word in words) {
      if (positiveWords.contains(word)) score += 0.1;
      if (negativeWords.contains(word)) score -= 0.1;
    }
    return math.max(-1.0, math.min(1.0, score));
  }

  // Helper method for future complexity analysis
  double _calculateComplexity(String text) {
    final sentences = text.split(RegExp(r'[.!?]')).length;
    final words = text.split(RegExp(r'\W+')).length;
    return sentences > 0 ? words / sentences : 0.0;
  }

  // Helper method for intelligent node positioning
  Offset _calculateIntelligentPosition(
    int index,
    int total,
    ContentAnalysis analysis,
    Size size,
  ) {
    switch (_visualStyle) {
      case VisualizationStyle.galaxy:
        return _calculateGalaxyPosition(index, total, analysis, size);
      case VisualizationStyle.cluster:
        return _calculateClusterPosition(index, total, analysis, size);
      case VisualizationStyle.hierarchy:
        return _calculateHierarchyPosition(index, total, analysis, size);
      case VisualizationStyle.force:
        return _calculateForcePosition(index, total, analysis, size);
    }
  }

  Offset _calculateGalaxyPosition(
    int index,
    int total,
    ContentAnalysis analysis,
    Size size,
  ) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final categoryAngles = {
      'trabajo': 0.0,
      'personal': math.pi / 2,
      'ideas': math.pi,
      'proyectos': 3 * math.pi / 2,
    };
    // Example: Place nodes in a circle by category
    final angle = categoryAngles[analysis.category] ?? (2 * math.pi * index / total);
    final radius = 180.0 + (analysis.score * 60.0);
    final x = centerX + radius * math.cos(angle);
    final y = centerY + radius * math.sin(angle);
    return Offset(x, y);
  }

  // Helper method for semantic similarity calculation
  double _calculateSemanticSimilarity(AIGraphNode node1, AIGraphNode node2) {
    double similarity = 0.0;
    final sharedTags = node1.tags.toSet().intersection(node2.tags.toSet());
    similarity += sharedTags.length * 0.3;
    final sharedThemes = node1.aiAnalysis.themes.toSet().intersection(
      node2.aiAnalysis.themes.toSet(),
    );
    similarity += sharedThemes.length * 0.4;
    final sharedKeywords = node1.aiAnalysis.keywords.toSet().intersection(
      node2.aiAnalysis.keywords.toSet(),
    );
    similarity += (sharedKeywords.length / 10.0) * 0.2;
    if (node1.aiAnalysis.category == node2.aiAnalysis.category) {
      similarity += 0.1;
    }
    return math.min(1.0, similarity);
  }

  EdgeType _determineConnectionType(
    AIGraphNode node1,
    AIGraphNode node2,
    double similarity,
  ) {
    if (similarity > 0.8) return EdgeType.strong;
    if (similarity > 0.6) return EdgeType.semantic;
    if (similarity > 0.4) return EdgeType.thematic;
    return EdgeType.weak;
  }

  String _generateConnectionLabel(AIGraphNode a, AIGraphNode b, EdgeType type) {
    switch (type) {
      case EdgeType.strong:
        return 'Muy relacionado';
      case EdgeType.semantic:
        return 'Contenido similar';
      case EdgeType.thematic:
        return 'Tema común';
      case EdgeType.weak:
        return 'Relacionado';
      case EdgeType.manual:
        return 'Manual';
    }
  }

  List<NodeCluster> _performClustering(
    List<AIGraphNode> nodes,
    List<AIGraphEdge> edges,
  ) {
    switch (_clusteringMode) {
      case NodeClusteringMode.semantic:
        return _clusterBySemantic(nodes);
      case NodeClusteringMode.connectivity:
        return _clusterByConnectivity(nodes, edges);
      case NodeClusteringMode.importance:
        return _clusterByImportance(nodes);
    }
  }

  List<NodeCluster> _clusterBySemantic(List<AIGraphNode> nodes) {
    final clusterMap = <String, List<String>>{};
    for (var node in nodes) {
      final category = node.aiAnalysis.category;
      clusterMap.putIfAbsent(category, () => []).add(node.id);
    }
    return clusterMap.entries
        .map(
          (e) => NodeCluster(
            id: e.key,
            name: e.key.toUpperCase(),
            nodeIds: e.value,
            color: _getCategoryColor(e.key),
          ),
        )
        .toList();
  }

  List<NodeCluster> _clusterByConnectivity(
    List<AIGraphNode> nodes,
    List<AIGraphEdge> edges,
  ) {
    return [
      NodeCluster(
        id: 'main',
        name: 'Principal',
        nodeIds: nodes.map((n) => n.id).toList(),
        color: AppColors.primary,
      ),
    ];
  }

  List<NodeCluster> _clusterByImportance(List<AIGraphNode> nodes) {
    final high = nodes
        .where((n) => n.importance > 0.7)
        .map((n) => n.id)
        .toList();
    final med = nodes
        .where((n) => n.importance > 0.4 && n.importance <= 0.7)
        .map((n) => n.id)
        .toList();
    final low = nodes
        .where((n) => n.importance <= 0.4)
        .map((n) => n.id)
        .toList();
    final out = <NodeCluster>[];
    if (high.isNotEmpty) {
      out.add(
        NodeCluster(
          id: 'high',
          name: 'Alta Importancia',
          nodeIds: high,
          color: Colors.red,
        ),
      );
    }
    if (med.isNotEmpty) {
      out.add(
        NodeCluster(
          id: 'medium',
          name: 'Media Importancia',
          nodeIds: med,
          color: Colors.orange,
        ),
      );
    }
    if (low.isNotEmpty) {
      out.add(
        NodeCluster(
          id: 'low',
          name: 'Baja Importancia',
          nodeIds: low,
          color: Colors.grey,
        ),
      );
    }
    return out;
  }

  Map<String, double> _calculateCentrality(
    List<AIGraphNode> nodes,
    List<AIGraphEdge> edges,
  ) {
    final centrality = <String, double>{};
    for (var node in nodes) {
      final connections = edges.where(
        (e) => e.from == node.id || e.to == node.id,
      );
      final strength = connections.fold(0.0, (sum, e) => sum + e.strength);
      centrality[node.id] = strength / math.max(1, nodes.length);
    }
    return centrality;
  }

  int _calculateNodeDepth(AIGraphNode node, List<AIGraphEdge> edges) {
    final connections = edges
        .where((e) => e.from == node.id || e.to == node.id)
        .length;
    return (connections / 3).ceil();
  }

  void _applyForceDirectedLayout(
    List<AIGraphNode> nodes,
    List<AIGraphEdge> edges,
  ) {
    const iterations = 100;
    const repulsionStrength = 1000.0;
    const attractionStrength = 0.1;
    const damping = 0.9;
    for (int iter = 0; iter < iterations; iter++) {
      for (var node in nodes) {
        node.velocity = Offset.zero;
      }
      for (int i = 0; i < nodes.length; i++) {
        for (int j = i + 1; j < nodes.length; j++) {
          final node1 = nodes[i];
          final node2 = nodes[j];
          final distance = (node1.position - node2.position).distance;
          if (distance > 0) {
            final force = repulsionStrength / (distance * distance);
            final direction = (node1.position - node2.position) / distance;
            node1.velocity += direction * force;
            node2.velocity -= direction * force;
          }
        }
      }
      for (var edge in edges) {
        final node1 = nodes.firstWhere((n) => n.id == edge.from);
        final node2 = nodes.firstWhere((n) => n.id == edge.to);
        final distance = (node1.position - node2.position).distance;
        if (distance > 0) {
          final force = attractionStrength * distance * edge.strength;
          final direction = (node2.position - node1.position) / distance;
          node1.velocity += direction * force;
          node2.velocity -= direction * force;
        }
      }
      for (var node in nodes) {
        node.position += node.velocity * damping;
        node.velocity *= damping;
      }
    }
  }

  Color _getAdvancedColorForNode(ContentAnalysis analysis) {
    final baseColor = _getCategoryColor(analysis.category);
    final brightness = 0.5 + (analysis.importance * 0.5);
    final hue = HSVColor.fromColor(baseColor).hue;
    var saturation = HSVColor.fromColor(baseColor).saturation;
    var value = HSVColor.fromColor(baseColor).value * brightness;
    if (analysis.sentiment > 0) {
      saturation = math.min(1.0, saturation + analysis.sentiment * 0.2);
    } else {
      value = math.max(0.3, value + analysis.sentiment * 0.3);
    }
    return HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'trabajo':
        return AppColors.blue;
      case 'personal':
        return AppColors.green;
      case 'ideas':
        return AppColors.yellow;
      case 'proyectos':
        return AppColors.purple;
      case 'educacion':
        return AppColors.cyan;
      case 'salud':
        return AppColors.red;
      case 'finanzas':
        return AppColors.lime;
      case 'tecnologia':
        return AppColors.orange;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    // If there are no nodes, show a focused empty state and a load button.
    if (_nodes.isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.device_hub, size: 72, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  'No se han cargado notas para el grafo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    await _loadGraphWithAI();
                  },
                  child: const Text('Cargar grafo'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _minimalMode = false),
                  child: const Text('Mostrar interfaz completa', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: Stack(
        children: [
          // Main graph widget with gesture controls
          LayoutBuilder(
            builder: (context, constraints) {
              final canvasSize = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              return GestureDetector(
                onScaleStart: (details) {
                  _lastFocalPoint = details.focalPoint;
                  
                  // Check if starting drag on a node
                  final localPosition = (details.focalPoint - _offset) / _scale;
                  for (var node in _nodes) {
                    final distance = (node.position - localPosition).distance;
                    if (distance < 40) {
                      setState(() {
                        // If in link mode, start drag-to-link
                        if (_isLinkMode) {
                          _draggingFromNodeId = node.id;
                          _draggingCurrentPosition = localPosition;
                        } else {
                          // Otherwise, start node dragging
                          _draggingNodeId = node.id;
                          _nodeDragStartPosition = node.position;
                          _isNodeDragging = true;
                        }
                      });
                      return;
                    }
                  }
                  // If no node found, allow graph pan/zoom
                  _isNodeDragging = false;
                  _draggingFromNodeId = null;
                },
                onScaleUpdate: (details) {
                  setState(() {
                    // If in link mode and dragging from a node
                    if (_isLinkMode && _draggingFromNodeId != null) {
                      final localPosition = (details.focalPoint - _offset) / _scale;
                      _draggingCurrentPosition = localPosition;
                      return;
                    }
                    
                    // If dragging a node, update its position
                    if (_isNodeDragging && _draggingNodeId != null) {
                      final localPosition = (details.focalPoint - _offset) / _scale;
                      final nodeIndex = _nodes.indexWhere((n) => n.id == _draggingNodeId);
                      
                      if (nodeIndex != -1) {
                        Offset newPosition = localPosition;
                        
                        // Apply snap-to-grid if enabled
                        if (_snapToGrid) {
                          newPosition = Offset(
                            (newPosition.dx / _gridSize).round() * _gridSize,
                            (newPosition.dy / _gridSize).round() * _gridSize,
                          );
                        }
                        
                        _nodes[nodeIndex].position = newPosition;
                      }
                      return;
                    }
                    
                    // Otherwise handle zoom and pan
                    final newScale = (_scale * details.scale).clamp(0.1, 5.0);
                    
                    // Handle pan
                    final focalPointDelta = details.focalPoint - _lastFocalPoint;
                    _offset += focalPointDelta / _scale;
                    _lastFocalPoint = details.focalPoint;
                    
                    _scale = newScale;
                  });
                },
                onScaleEnd: (details) {
                  // Complete link creation if in link mode
                  if (_isLinkMode && _draggingFromNodeId != null && _draggingCurrentPosition != null) {
                    // Find node at drop position
                    String? targetNodeId;
                    for (var node in _nodes) {
                      final distance = (node.position - _draggingCurrentPosition!).distance;
                      if (distance < 40 && node.id != _draggingFromNodeId) {
                        targetNodeId = node.id;
                        break;
                      }
                    }
                    
                    // If found target node, show edge creation dialog
                    if (targetNodeId != null) {
                      _showCreateEdgeDialog(_draggingFromNodeId!, targetNodeId);
                    }
                    
                    // Reset drag-to-link state
                    setState(() {
                      _draggingFromNodeId = null;
                      _draggingCurrentPosition = null;
                    });
                    return;
                  }
                  
                  // Reset node dragging state
                  if (_isNodeDragging) {
                    setState(() {
                      _isNodeDragging = false;
                      _draggingNodeId = null;
                      _nodeDragStartPosition = null;
                    });
                  }
                },
                onTapDown: (details) {
                  final localPosition = (details.localPosition - _offset) / _scale;
                  String? tappedNodeId;
                  
                  // Check for node tap
                  for (var node in _nodes) {
                    final distance = (node.position - localPosition).distance;
                    if (distance < 40) {
                      tappedNodeId = node.id;
                      break;
                    }
                  }
                  
                  setState(() {
                    _selectedNodeId = tappedNodeId;
                  });
                },
                onDoubleTapDown: (details) {
                  // Double tap to focus on node
                  final localPosition = (details.localPosition - _offset) / _scale;
                  for (var node in _nodes) {
                    final distance = (node.position - localPosition).distance;
                    if (distance < 40) {
                      setState(() {
                        _selectedNodeId = node.id;
                        // Animate to center the node
                        _offset = Offset(
                          constraints.maxWidth / 2 - node.position.dx * _scale,
                          constraints.maxHeight / 2 - node.position.dy * _scale,
                        );
                      });
                      break;
                    }
                  }
                },
                onLongPressStart: (details) {
                  // Long press for node context menu
                  final localPosition = (details.localPosition - _offset) / _scale;
                  for (var node in _nodes) {
                    final distance = (node.position - localPosition).distance;
                    if (distance < 40) {
                      _showNodeContextMenu(context, node, details.globalPosition);
                      break;
                    }
                  }
                },
                child: RepaintBoundary(
                  key: _graphKey,
                  child: CustomPaint(
                    size: canvasSize,
                    painter: AIGraphPainter(
                      nodes: _nodes,
                      edges: _getFilteredEdges(),
                      particles: _showParticles ? _particles : [],
                      floatingParticles: _showParticles ? _floatingParticles : [],
                      selectedNodeId: _selectedNodeId,
                      hoveredNodeId: _hoveredNodeId,
                      scale: _scale,
                      offset: _offset,
                      is3DMode: _is3DMode,
                      pulseValue: _pulseAnimation.value,
                      rotationValue: _rotationAnimation.value,
                      clusters: _clusters,
                      centrality: _centrality,
                      draggingFromNodeId: _draggingFromNodeId,
                      draggingPosition: _draggingCurrentPosition,
                      highlightedNodeIds: _highlightedNodeIds,
                      draggingNodeId: _draggingNodeId,
                    ),
                  ),
                ),
              );
            },
          ),
          // Search/filter bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.all(Radius.circular(12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  splashColor: Colors.white10,
                  highlightColor: Colors.white10,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.white70),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Buscar nodo o etiqueta...',
                              hintStyle: TextStyle(color: Colors.white54),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            cursorColor: Colors.white70,
                            onChanged: (query) {
                              setState(() {
                                _searchQuery = query.trim().toLowerCase();
                                _highlightedNodeIds = _nodes
                                    .where((n) =>
                                        n.title.toLowerCase().contains(_searchQuery) ||
                                        n.tags.any((tag) => tag.toLowerCase().contains(_searchQuery)))
                                    .map((n) => n.id)
                                    .toSet();
                              });
                            },
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white70),
                            splashRadius: 18,
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _highlightedNodeIds.clear();
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Clustering legend (bottom right) - hide in minimal mode
          if (!_minimalMode)
            Positioned(
              bottom: 16,
              right: 16,
              child: _buildControlPanel(),
            ),
          // Metrics panel (top left) - hide in minimal mode
          if (!_minimalMode) _buildMetricsPanel(),
          // Edge filter panel (middle right) - hide in minimal mode
          if (!_minimalMode)
            Positioned(
              right: 16,
              top: MediaQuery.of(context).size.height * 0.3,
              child: _buildEdgeFilterPanel(),
            ),
          // Node info panel (bottom) - shown when a node is selected
          if (_selectedNodeId != null) _buildNodeInfoPanel(),
          // Minimal mode toggle (top-right)
          Positioned(
            top: 20,
            right: 20,
            child: FloatingActionButton.small(
              heroTag: 'graphModeToggle',
              backgroundColor: Colors.black.withOpacity(0.6),
              onPressed: () => setState(() => _minimalMode = !_minimalMode),
              child: Icon(_minimalMode ? Icons.visibility_off : Icons.visibility, size: 18),
            ),
          ),
          // Debug banner (top-center) — shows node/edge counts and quick actions
          Positioned(
            top: 18,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Grafo: nodos=${_nodes.length} aristas=${_edges.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                      onPressed: () async { await _loadGraphWithAI(); },
                      child: const Text('Recargar', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black54),
                      onPressed: () => setState(() => _minimalMode = !_minimalMode),
                      child: Text(_minimalMode ? 'Modo simple' : 'Modo completo', style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for graph interactions
  String? _nodeIdAt(Offset canvasPos, {double tolerance = 40}) {
    for (var node in _nodes) {
      if ((node.position - canvasPos).distance <= tolerance) return node.id;
    }
    return null;
  }

  Widget _buildControlPanel() {
    return Card(
      color: Colors.black.withOpacity(0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.legend_toggle, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Text('Clusters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            for (final cluster in _clusters)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: cluster.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30, width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      cluster.name,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500, shadows: [Shadow(color: Colors.black54, blurRadius: 2)]),
                    ),
                  ],
                ),
              ),
            DropdownButton<VisualizationStyle>(
              value: _visualStyle,
              items: VisualizationStyle.values.map((style) {
                return DropdownMenuItem(
                  value: style,
                  child: Text(
                    _getStyleName(style),
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
              onChanged: (style) {
                if (style != null) {
                  setState(() => _visualStyle = style);
                  _loadGraphWithAI();
                }
              },
            ),
            const Text('🔗 Umbral:', style: TextStyle(fontSize: 12)),
            Slider(
              value: _connectionThreshold,
              min: 0.1,
              max: 0.9,
              divisions: 8,
              onChanged: (value) {
                setState(() => _connectionThreshold = value);
                _loadGraphWithAI();
              },
            ),
            const SizedBox(height: 8),
            // Snap to grid toggle
            Row(
              children: [
                Checkbox(
                  value: _snapToGrid,
                  onChanged: (value) {
                    setState(() {
                      _snapToGrid = value ?? false;
                    });
                  },
                  fillColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.blue;
                    }
                    return Colors.white30;
                  }),
                ),
                const SizedBox(width: 4),
                const Text(
                  '📐 Snap to Grid',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Link mode toggle
            Row(
              children: [
                Checkbox(
                  value: _isLinkMode,
                  onChanged: (value) {
                    setState(() {
                      _isLinkMode = value ?? false;
                      // Reset any active drag-to-link state
                      if (!_isLinkMode) {
                        _draggingFromNodeId = null;
                        _draggingCurrentPosition = null;
                      }
                    });
                    HapticFeedback.lightImpact();
                  },
                  fillColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.orange;
                    }
                    return Colors.white30;
                  }),
                ),
                const SizedBox(width: 4),
                Text(
                  '🔗 Link Mode',
                  style: TextStyle(
                    color: _isLinkMode ? Colors.orange : Colors.white70,
                    fontSize: 12,
                    fontWeight: _isLinkMode ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white30, height: 1),
            const SizedBox(height: 12),
            // Enhanced export buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showExportDialog,
                    icon: const Icon(Icons.file_download, size: 18),
                    label: const Text('Exportar', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.withOpacity(0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Exportación rápida (3x)',
                  child: ElevatedButton(
                    onPressed: () => _exportGraphAsPNG(quality: 3.0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.withOpacity(0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(40, 40),
                    ),
                    child: const Icon(Icons.bolt, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showGraphStatistics,
                icon: const Icon(Icons.analytics, size: 16),
                label: const Text('Estadísticas', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white30),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeInfoPanel() {
    final node = _nodes.firstWhere((n) => n.id == _selectedNodeId);
    final connections = _edges
        .where((e) => e.from == node.id || e.to == node.id)
        .toList();
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 100.0, end: 0.0),
        builder: (context, offset, child) {
          return Transform.translate(
            offset: Offset(0, offset),
            child: Opacity(
              opacity: 1.0 - (offset / 100.0),
              child: child,
            ),
          );
        },
        child: Card(
          color: Colors.black.withOpacityCompat(0.9),
          elevation: 12,
          shadowColor: Colors.black.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: node.color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      node.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.link, size: 20),
                    tooltip: 'Gestionar Enlaces',
                    onPressed: () => _showNodeEdgeManager(node.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _selectedNodeId = null),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                children: [
                  _buildInfoChip(
                    '⭐ ${(node.importance * 100).toInt()}%',
                    Colors.amber,
                  ),
                  _buildInfoChip(
                    '🏷️ ${node.aiAnalysis.category}',
                    _getCategoryColor(node.aiAnalysis.category),
                  ),
                  _buildInfoChip('🔗 ${connections.length}', Colors.blue),
                  if (node.aiAnalysis.sentiment != 0)
                    _buildInfoChip(
                      node.aiAnalysis.sentiment > 0
                          ? '😊 Positivo'
                          : '😔 Negativo',
                      node.aiAnalysis.sentiment > 0 ? Colors.green : Colors.red,
                    ),
                ],
              ),
              if (node.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  children: node.tags
                      .map(
                        (tag) => Chip(
                          label: Text(
                            tag,
                            style: const TextStyle(fontSize: 10),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
                ),
              ],
              if (connections.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  '🔗 Conexiones:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: connections.take(6).map((edge) {
                    final otherNodeId = edge.from == node.id ? edge.to : edge.from;
                    final otherNode = _nodes.firstWhere((n) => n.id == otherNodeId, orElse: () => node);
                    return InputChip(
                      avatar: Icon(_getEdgeTypeIcon(edge.type), size: 16, color: _getEdgeTypeColor(edge.type)),
                      label: Text('${otherNode.title} ${(edge.strength * 100).toInt()}%'),
                      onPressed: () {
                        // focus/center other node
                        final idx = _nodes.indexWhere((n) => n.id == otherNodeId);
                        if (idx != -1) {
                          final target = _nodes[idx];
                          setState(() {
                            _selectedNodeId = otherNodeId;
                            _offset = Offset(MediaQuery.of(context).size.width / 2 - target.position.dx * _scale,
                                MediaQuery.of(context).size.height / 2 - target.position.dy * _scale);
                          });
                        }
                      },
                      onDeleted: () async {
                        // Edit edge
                        final docs = await FirestoreService.instance.listEdgeDocs(uid: _uid);
                        final match = docs.firstWhere((d) => d['from'] == edge.from && d['to'] == edge.to, orElse: () => <String, dynamic>{});
                        final edgeId = match['id']?.toString();
                        if (!mounted) return;
                        final res = await showDialog(
                          context: context,
                          builder: (ctx) => EdgeEditorDialog(
                            uid: _uid,
                            edgeId: edgeId,
                            fromNoteId: edge.from,
                            toNoteId: edge.to,
                          ),
                        );
                        if (!mounted) return;
                        if (res is EdgeEditorResult && mounted) {
                          await _loadGraphWithAI();
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildMetricsPanel() {
    return Positioned(
      top: 16,
      left: 16,
      child: Card(
        color: Colors.black.withOpacityCompat(0.8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '📊 Métricas',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Nodos: ${_nodes.length}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'Conexiones: ${_edges.length}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'Clusters: ${_clusters.length}',
                style: const TextStyle(fontSize: 12),
              ),
              if (_centrality.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Más central:',
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
                Text(
                  _getMostCentralNode(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getMostCentralNode() {
    if (_centrality.isEmpty) return '';
    final mostCentral = _centrality.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );
    final node = _nodes.firstWhere((n) => n.id == mostCentral.key);
    return node.title;
  }

  IconData _getEdgeTypeIcon(EdgeType type) {
    switch (type) {
      case EdgeType.strong:
        return Icons.link;
      case EdgeType.semantic:
        return Icons.psychology;
      case EdgeType.thematic:
        return Icons.topic;
      case EdgeType.weak:
        return Icons.link_off;
      case EdgeType.manual:
        return Icons.edit;
    }
  }

  Color _getEdgeTypeColor(EdgeType type) {
    switch (type) {
      case EdgeType.strong:
        return Colors.red;
      case EdgeType.semantic:
        return Colors.purple;
      case EdgeType.thematic:
        return Colors.blue;
      case EdgeType.weak:
        return Colors.grey;
      case EdgeType.manual:
        return Colors.green;
    }
  }

  List<AIGraphEdge> _getFilteredEdges() {
    return _edges.where((edge) {
      return _visibleEdgeTypes.contains(edge.type) &&
          edge.strength >= _minEdgeStrength;
    }).toList();
  }

  Widget _buildEdgeFilterPanel() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      tween: Tween(begin: 50.0, end: 0.0),
      builder: (context, offset, child) {
        return Transform.translate(
          offset: Offset(offset, 0),
          child: Opacity(
            opacity: 1.0 - (offset / 50.0),
            child: child,
          ),
        );
      },
      child: Card(
        color: Colors.black.withOpacityCompat(0.8),
        elevation: 10,
        shadowColor: Colors.black.withOpacity(0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280, maxHeight: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🔗 Filtros de Enlaces',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fuerza mínima: ${(_minEdgeStrength * 100).toInt()}%',
                  style: const TextStyle(fontSize: 12),
                ),
                Slider(
                  value: _minEdgeStrength,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  onChanged: (value) =>
                      setState(() => _minEdgeStrength = value),
                ),
                const SizedBox(height: 8),
                const Text('Tipos visibles:', style: TextStyle(fontSize: 12)),
                ...EdgeType.values.map(
                  (type) => CheckboxListTile(
                    dense: true,
                    value: _visibleEdgeTypes.contains(type),
                    onChanged: (enabled) {
                      setState(() {
                        if (enabled == true) {
                          _visibleEdgeTypes.add(type);
                        } else {
                          _visibleEdgeTypes.remove(type);
                        }
                      });
                    },
                    title: Text(
                      _getEdgeTypeName(type),
                      style: const TextStyle(fontSize: 10),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                CheckboxListTile(
                  dense: true,
                  value: _showEdgeLabels,
                  onChanged: (value) =>
                      setState(() => _showEdgeLabels = value ?? true),
                  title: const Text(
                    'Mostrar etiquetas',
                    style: TextStyle(fontSize: 10),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getEdgeTypeName(EdgeType type) {
    switch (type) {
      case EdgeType.strong:
        return '💪 Fuerte';
      case EdgeType.semantic:
        return '🧠 Semántico';
      case EdgeType.thematic:
        return '📝 Temático';
      case EdgeType.weak:
        return '🔸 Débil';
      case EdgeType.manual:
        return '🔗 Manual';
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyR:
          _loadGraphWithAI();
          break;
        case LogicalKeyboardKey.keyC:
          setState(() {
            _offset = Offset.zero;
            _scale = 1.0;
          });
          break;
        case LogicalKeyboardKey.keyL:
          setState(() => _autoLayout = !_autoLayout);
          if (_autoLayout) {
            _applyForceDirectedLayout(_nodes, _getFilteredEdges());
          }
          break;
        case LogicalKeyboardKey.keyF:
          setState(() => _minEdgeStrength = _minEdgeStrength > 0 ? 0.0 : 0.3);
          break;
        case LogicalKeyboardKey.escape:
          setState(() => _selectedNodeId = null);
          break;
      }
    }
  }

  Widget _buildKeyboardShortcutsHelp() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: Card(
        color: Colors.black.withOpacityCompat(0.7),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                '⌨️ Atajos:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
              ),
              Text('R - Recalcular', style: TextStyle(fontSize: 9)),
              Text('C - Centrar', style: TextStyle(fontSize: 9)),
              Text('L - Layout automático', style: TextStyle(fontSize: 9)),
              Text('F - Filtrar enlaces', style: TextStyle(fontSize: 9)),
              Text('ESC - Deseleccionar', style: TextStyle(fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }

  EdgeType _edgeTypeFromString(String s) {
    switch (s) {
      case 'strong':
        return EdgeType.strong;
      case 'semantic':
        return EdgeType.semantic;
      case 'thematic':
        return EdgeType.thematic;
      case 'weak':
        return EdgeType.weak;
      case 'manual':
      default:
        return EdgeType.manual;
    }
  }

  // Edge hit detection for canvas-based editing
  AIGraphEdge? _getEdgeAt(Offset position, {double tolerance = 15}) {
    for (var edge in _edges) {
      final fromNode = _nodes.firstWhere((n) => n.id == edge.from);
      final toNode = _nodes.firstWhere((n) => n.id == edge.to);

      // Simple distance check to line segment
      final distance = _distanceToLineSegment(
        position,
        fromNode.position,
        toNode.position,
      );
      if (distance <= tolerance) return edge;
    }
    return null;
  }

  double _distanceToLineSegment(Offset point, Offset start, Offset end) {
    final A = point.dx - start.dx;
    final B = point.dy - start.dy;
    final C = end.dx - start.dx;
    final D = end.dy - start.dy;

    final dot = A * C + B * D;
    final lenSq = C * C + D * D;

    if (lenSq == 0) return (point - start).distance; // start == end

    final param = dot / lenSq;
    double xx;
    double yy;

    if (param < 0) {
      xx = start.dx;
      yy = start.dy;
    } else if (param > 1) {
      xx = end.dx;
      yy = end.dy;
    } else {
      xx = start.dx + param * C;
      yy = start.dy + param * D;
    }

    final dx = point.dx - xx;
    final dy = point.dy - yy;
    return math.sqrt(dx * dx + dy * dy);
  }

  Future<void> _showCreateEdgeDialog(String fromNoteId, String toNoteId) async {
    // Check if edge already exists
    final docs = await FirestoreService.instance.listEdgeDocs(uid: _uid);
    final existingEdge = docs.firstWhere(
      (d) => d['from'] == fromNoteId && d['to'] == toNoteId,
      orElse: () => <String, dynamic>{},
    );
    
    if (existingEdge.isNotEmpty) {
      ToastService.error('Ya existe un enlace entre estas notas');
      return;
    }

    if (!mounted) return;
    final result = await showDialog<EdgeEditorResult>(
      context: context,
      builder: (ctx) => EdgeEditorDialog(
        uid: _uid,
        edgeId: null, // New edge
        fromNoteId: fromNoteId,
        toNoteId: toNoteId,
      ),
    );
    
    if (!mounted) return;
    if (result != null && !result.deleted && mounted) {
      HapticFeedback.mediumImpact();
      await _loadGraphWithAI();
      ToastService.success('Enlace creado exitosamente');
    }
  }

  // Export & Sharing functionality - Enhanced version
  Future<void> _exportGraphAsPNG({double quality = 3.0, bool showDialog = true}) async {
    try {
      if (showDialog) {
        ToastService.info('🎨 Generando imagen de alta calidad...');
      }
      
      // Get the RenderRepaintBoundary
      final boundary = _graphKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        ToastService.error('No se pudo capturar el gráfico');
        return;
      }
      
      // Capture the image at higher resolution for professional quality
      final image = await boundary.toImage(pixelRatio: quality);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        ToastService.error('Error al generar la imagen');
        return;
      }
      
      final pngBytes = byteData.buffer.asUint8List();
      
      // Generate intelligent filename
      final timestamp = DateTime.now();
      final dateStr = '${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}';
      final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}';
      final nodeCount = _nodes.length;
      final filename = 'nootes_graph_${nodeCount}nodes_${dateStr}_$timeStr.png';
      
      // Save to temporary directory
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsBytes(pngBytes);
        
        HapticFeedback.mediumImpact();
        ToastService.success('Imagen exportada: ${file.path}');
        
        // Offer to share
        await _shareGraphImage(file.path);
      } else {
        // For web, trigger download
        ToastService.success('Imagen generada');
      }
    } catch (e) {
      ToastService.error('Error al exportar: $e');
    }
  }
  
  Future<void> _shareGraphImage(String filePath) async {
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Compartir Gráfico'),
          content: const Text('¿Deseas compartir la imagen del gráfico?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Compartir'),
            ),
          ],
        ),
      );
      
      if (result == true) {
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Mi gráfico de conocimiento - Nootes',
        );
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      ToastService.error('Error al compartir: $e');
    }
  }
  
  // Enhanced export dialog with quality options
  Future<void> _showExportDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.file_download, color: Colors.blue),
            SizedBox(width: 8),
            Text('Exportar Gráfico Profesional'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.analytics, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${_nodes.length} nodos • ${_edges.length} conexiones',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Calidad de Exportación',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.hd, color: Colors.blue),
                title: const Text('Calidad Estándar (2x)'),
                subtitle: const Text('Recomendado para pantalla • ~1MB'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportGraphAsPNG(quality: 2.0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.high_quality, color: Colors.orange),
                title: const Text('Alta Calidad (3x)'),
                subtitle: const Text('Presentaciones y documentos • ~2MB'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportGraphAsPNG(quality: 3.0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.diamond, color: Colors.purple),
                title: const Text('Ultra Calidad (4x)'),
                subtitle: const Text('Impresión profesional • ~4MB'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportGraphAsPNG(quality: 4.0);
                },
              ),
              const Divider(height: 32),
              const Text(
                'Otras Opciones',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.green),
                title: const Text('Compartir Gráfico'),
                subtitle: const Text('Compartir con calidad alta (3x)'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportGraphAsPNG(quality: 3.0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.print, color: Colors.brown),
                title: const Text('Vista Previa de Impresión'),
                subtitle: const Text('Ver antes de imprimir'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPrintPreview();
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.grey),
                title: const Text('Estadísticas del Gráfico'),
                subtitle: const Text('Ver análisis detallado'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showGraphStatistics();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
  
  void _showPrintPreview() {
    // Create print-friendly version (high contrast, no background)
    ToastService.info('Preparando versión para imprimir...');
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          width: 800,
          height: 600,
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Vista Previa de Impresión',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _exportGraphAsPNG();
                        },
                        tooltip: 'Exportar PNG',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                        tooltip: 'Cerrar',
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Center(
                    child: Text(
                      'Gráfico de ${_nodes.length} notas\n'
                      '${_edges.length} conexiones\n'
                      '${_clusters.length} clusters',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tip: Usa "Exportar como PNG" para guardar la imagen\n'
                'y luego imprímela desde tu visor de imágenes',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Advanced graph statistics dialog
  void _showGraphStatistics() {
    // Calculate advanced statistics
    final totalNodes = _nodes.length;
    final totalEdges = _edges.length;
    final totalClusters = _clusters.length;
    
    // Calculate edge type distribution
    final edgeTypeCount = <EdgeType, int>{};
    for (final edge in _edges) {
      edgeTypeCount[edge.type] = (edgeTypeCount[edge.type] ?? 0) + 1;
    }
    
    // Calculate average connections per node
    final avgConnections = totalNodes > 0 ? (totalEdges * 2.0 / totalNodes).toStringAsFixed(1) : '0';
    
    // Find most connected node
    final nodeConnections = <String, int>{};
    for (final edge in _edges) {
      nodeConnections[edge.from] = (nodeConnections[edge.from] ?? 0) + 1;
      nodeConnections[edge.to] = (nodeConnections[edge.to] ?? 0) + 1;
    }
    
    String mostConnectedNodeTitle = 'N/A';
    int maxConnections = 0;
    if (nodeConnections.isNotEmpty) {
      final mostConnectedId = nodeConnections.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      maxConnections = nodeConnections[mostConnectedId] ?? 0;
      final mostConnectedNode = _nodes.firstWhere((n) => n.id == mostConnectedId, orElse: () => _nodes.first);
      mostConnectedNodeTitle = mostConnectedNode.title.length > 30 
          ? '${mostConnectedNode.title.substring(0, 30)}...' 
          : mostConnectedNode.title;
    }
    
    // Calculate graph density
    final maxPossibleEdges = totalNodes * (totalNodes - 1) / 2;
    final density = maxPossibleEdges > 0 ? (totalEdges / maxPossibleEdges * 100).toStringAsFixed(1) : '0';
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.analytics, color: Colors.blue),
            SizedBox(width: 8),
            Text('Estadísticas del Gráfico'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overview section
              _buildStatSection(
                '📊 Resumen General',
                [
                  _buildStatRow('Total de Nodos', '$totalNodes'),
                  _buildStatRow('Total de Conexiones', '$totalEdges'),
                  _buildStatRow('Clusters Detectados', '$totalClusters'),
                  _buildStatRow('Densidad del Gráfico', '$density%'),
                ],
              ),
              const Divider(height: 24),
              
              // Connections section
              _buildStatSection(
                '🔗 Análisis de Conexiones',
                [
                  _buildStatRow('Promedio por Nodo', avgConnections),
                  _buildStatRow('Máximo de Conexiones', '$maxConnections'),
                  _buildStatRow('Nodo más Conectado', mostConnectedNodeTitle),
                ],
              ),
              const Divider(height: 24),
              
              // Edge types section
              _buildStatSection(
                '🏷️ Tipos de Conexiones',
                edgeTypeCount.entries.map((e) {
                  final percentage = (e.value / totalEdges * 100).toStringAsFixed(1);
                  return _buildStatRow(
                    _getEdgeTypeLabel(e.key),
                    '${e.value} ($percentage%)',
                  );
                }).toList(),
              ),
              const Divider(height: 24),
              
              // Visual settings section
              _buildStatSection(
                '🎨 Configuración Visual',
                [
                  _buildStatRow('Estilo Visual', _getVisualStyleLabel(_visualStyle)),
                  _buildStatRow('Umbral de Conexión', _connectionThreshold.toStringAsFixed(2)),
                  _buildStatRow('Snap to Grid', _snapToGrid ? 'Activado' : 'Desactivado'),
                  _buildStatRow('Modo Link', _isLinkMode ? 'Activo' : 'Inactivo'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _exportGraphAsPNG(quality: 3.0);
            },
            icon: const Icon(Icons.download),
            label: const Text('Exportar'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
  
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  String _getEdgeTypeLabel(EdgeType type) {
    switch (type) {
      case EdgeType.strong:
        return '💪 Fuerte';
      case EdgeType.semantic:
        return '💭 Semántico';
      case EdgeType.thematic:
        return '🏷️ Temático';
      case EdgeType.weak:
        return '🔗 Débil';
      case EdgeType.manual:
        return '✋ Manual';
    }
  }
  
  String _getVisualStyleLabel(VisualizationStyle style) {
    switch (style) {
      case VisualizationStyle.galaxy:
        return '🌌 Galaxia';
      case VisualizationStyle.cluster:
        return '🏷️ Clusters';
      case VisualizationStyle.hierarchy:
        return '📊 Jerarquía';
      case VisualizationStyle.force:
        return '⚡ Fuerzas';
    }
  }

  Future<void> _showEdgeEditDialog(AIGraphEdge edge) async {
    // Find existing edge doc if any
    final docs = await FirestoreService.instance.listEdgeDocs(uid: _uid);
    final match = docs.firstWhere(
      (d) => d['from'] == edge.from && d['to'] == edge.to,
      orElse: () => <String, dynamic>{},
    );
    final edgeId = match['id']?.toString();

    if (!mounted) return;
    final result = await showDialog<EdgeEditorResult>(
      context: context,
      builder: (ctx) => EdgeEditorDialog(
        uid: _uid,
        edgeId: edgeId,
        fromNoteId: edge.from,
        toNoteId: edge.to,
      ),
    );
    if (!mounted) return;
    if (result != null && mounted) {
      await _loadGraphWithAI();
      final action = result.deleted
          ? 'eliminado'
          : (edgeId == null ? 'creado' : 'actualizado');
      ToastService.success('Enlace $action');
    }
  }

// Removed duplicate and stray widget code after dialog builder

  void _handleMenuAction(String action) {
    switch (action) {
      case 'recalculate':
        HapticFeedback.lightImpact();
        _loadGraphWithAI();
        break;
      case 'center':
        setState(() {
          _offset = Offset.zero;
          _scale = 1.0;
        });
        break;
      case 'layout':
        setState(() => _autoLayout = !_autoLayout);
        if (_autoLayout) {
          _applyForceDirectedLayout(_nodes, _edges);
          setState(() {});
        }
        break;
    }
  }

  void _showNodeContextMenu(BuildContext context, AIGraphNode node, Offset position) {
    final RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'open',
          child: Row(
            children: [
              Icon(Icons.open_in_new, size: 18),
              SizedBox(width: 8),
              Text('Abrir nota'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18),
              SizedBox(width: 8),
              Text('Editar'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('Eliminar', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share, size: 18),
              SizedBox(width: 8),
              Text('Compartir'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy, size: 18),
              SizedBox(width: 8),
              Text('Copiar enlace'),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'cluster',
          child: Row(
            children: [
              Icon(Icons.hub, size: 18),
              SizedBox(width: 8),
              Text('Ver cluster'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'connections',
          child: Row(
            children: [
              Icon(Icons.device_hub, size: 18),
              SizedBox(width: 8),
              Text('Ver conexiones'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        _handleContextMenuAction(value, node);
      }
    });
  }

  void _handleContextMenuAction(String action, AIGraphNode node) {
    switch (action) {
      case 'open':
        // Navigate to note detail page
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NoteEditorPage(noteId: node.id),
          ),
        );
        break;
      case 'edit':
        // Open edit dialog or page
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NoteEditorPage(noteId: node.id),
          ),
        );
        break;
      case 'delete':
        // Show confirmation dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Eliminar nota'),
            content: Text('¿Estás seguro de que deseas eliminar esta nota?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(_uid)
                        .collection('notes')
                        .doc(node.id)
                        .delete();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Nota eliminada')),
                    );
                    _loadGraphWithAI();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al eliminar: $e')),
                    );
                  }
                },
                child: Text('Eliminar', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        break;
      case 'share':
        // TODO: Implement share functionality
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Función de compartir próximamente')),
        );
        break;
      case 'copy':
        // Copy note ID or link
        Clipboard.setData(ClipboardData(text: node.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ID de nota copiado al portapapeles')),
        );
        break;
      case 'cluster':
        // Focus on cluster
        final cluster = _clusters.firstWhere(
          (c) => c.nodeIds.contains(node.id),
          orElse: () => _clusters.first,
        );
        setState(() {
          _highlightedNodeIds = cluster.nodeIds.toSet();
        });
        break;
      case 'connections':
        // Highlight connections
        final connectedIds = <String>{};
        for (final edge in _edges) {
          if (edge.from == node.id) {
            connectedIds.add(edge.to);
          } else if (edge.to == node.id) {
            connectedIds.add(edge.from);
          }
        }
        setState(() {
          _selectedNodeId = node.id;
          _highlightedNodeIds = {node.id, ...connectedIds};
        });
        break;
    }
  }
}

