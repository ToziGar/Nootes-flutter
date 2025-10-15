import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;
import 'edge_editor_dialog.dart';
import '../widgets/glass.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/toast_service.dart';
import '../theme/app_colors.dart';
import '../theme/color_utils.dart';

/// 🧠 Mapa Mental Unificado (IA + Interactivo)
/// Esta implementación reemplaza la versión anterior y combina las
/// capacidades de análisis semántico y renderizado avanzado en una sola
/// página: `InteractiveGraphPage`.
class InteractiveGraphPage extends StatefulWidget {
  const InteractiveGraphPage({super.key});

  @override
  State<InteractiveGraphPage> createState() => _InteractiveGraphPageState();
}

class _InteractiveGraphPageState extends State<InteractiveGraphPage>
    with TickerProviderStateMixin {
  late Future<void> _init;
  // Keep a FocusNode instead of creating one in build continuously
  final FocusNode _keyboardFocusNode = FocusNode();
  List<AIGraphNode> _nodes = [];
  List<AIGraphEdge> _edges = [];
  final List<ParticleConnection> _particles = [];
  String? _selectedNodeId;
  String? _hoveredNodeId;
  // Drag-to-link state
  String? _draggingFromNodeId;
  Offset? _draggingCurrentPosition; // in canvas coordinates (post-transform)

  // Edge filtering
  final Set<EdgeType> _visibleEdgeTypes = EdgeType.values.toSet();
  double _minEdgeStrength = 0.0;
  bool _showEdgeLabels = true;

  // Controls
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  bool _is3DMode = true;
  bool _showParticles =
      !kIsWeb; // Disable particles on web by default for better performance
  bool _autoLayout = true;

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
    _initAnimations();
    _init = _loadGraphWithAI();
    _startParticleSystem();
    // Focus the keyboard listener
    _keyboardFocusNode.requestFocus();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _particleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );
  }

  void _startParticleSystem() {
    // Cancel previous timer if exists
    _particleTimer?.cancel();

    // Reduce frequency on web for better performance
    final duration = kIsWeb
        ? const Duration(milliseconds: 200)
        : const Duration(milliseconds: 100);

    _particleTimer = Timer.periodic(duration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _updateParticles();

      // Only update particles if they're visible and we're not on web or have few particles
      if (_showParticles && (!kIsWeb || _floatingParticles.length < 20)) {
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  void _updateParticles() {
    _floatingParticles.removeWhere((p) => p.life <= 0);
    for (var particle in _floatingParticles) {
      particle.update();
    }

    // Reduce particle count on web for better performance
    final maxParticles = kIsWeb ? 20 : 50;

    if (_floatingParticles.length < maxParticles && _showParticles) {
      final size = MediaQuery.of(context).size;
      _floatingParticles.add(
        FloatingParticle(
          position: Offset(
            math.Random().nextDouble() * size.width,
            math.Random().nextDouble() * size.height,
          ),
        ),
      );
    }
    _particles.clear();
    for (var edge in _edges) {
      if (edge.strength > 0.5) {
        _particles.add(
          ParticleConnection(
            from: edge.from,
            to: edge.to,
            strength: edge.strength,
            phase: math.Random().nextDouble() * 2 * math.pi,
          ),
        );
      }
    }
  }

  Future<void> _loadGraphWithAI() async {
    // Capture layout size first to avoid using BuildContext across async gaps.
    Size size = MediaQuery.of(context).size;
    if (size.width == 0 || size.height == 0) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      size = MediaQueryData.fromView(
        ui.PlatformDispatcher.instance.views.first,
      ).size;
    }

    final svc = FirestoreService.instance;
    final notes = await svc.listNotes(uid: _uid);
    // Prefer explicit edge documents (with metadata) when available
    final edgeDocs = await svc.listEdgeDocs(uid: _uid);
    final existingEdgesLegacy = await svc.listEdges(uid: _uid);

    final nodes = <AIGraphNode>[];

    for (var i = 0; i < notes.length; i++) {
      final note = notes[i];
      final id = note['id'].toString();
      final title = (note['title']?.toString() ?? 'Sin título').trim();
      final content = (note['content']?.toString() ?? '').trim();
      final tags = (note['tags'] as List?)?.cast<String>() ?? [];
      final aiAnalysis = _analyzeContentWithAI(title, content, tags);
      final position = _calculateIntelligentPosition(
        i,
        notes.length,
        aiAnalysis,
        size,
      );
      nodes.add(
        AIGraphNode(
          id: id,
          title: title.isEmpty ? id : title,
          content: content,
          tags: tags,
          position: position,
          velocity: Offset.zero,
          color: _getAdvancedColorForNode(aiAnalysis),
          connectionCount: 0,
          aiAnalysis: aiAnalysis,
          importance: aiAnalysis.importance,
          depth: 0,
          cluster: '',
        ),
      );
    }

    final smartEdges = await _generateSmartConnections(nodes);

    // Map edge docs into AIGraphEdge
    final allEdges = <AIGraphEdge>[];
    final seenPairs = <String>{};
    for (final doc in edgeDocs) {
      final from = doc['from']?.toString() ?? '';
      final to = doc['to']?.toString() ?? '';
      if (from.isEmpty || to.isEmpty) continue;
      final strength = (doc['strength'] is num)
          ? (doc['strength'] as num).toDouble()
          : 1.0;
      final typeStr = doc['type']?.toString() ?? 'manual';
      final type = _edgeTypeFromString(typeStr);
      final label = doc['label']?.toString() ?? '';
      allEdges.add(
        AIGraphEdge(
          from: from,
          to: to,
          strength: strength,
          type: type,
          label: label,
        ),
      );
      seenPairs.add('$from|$to');
      // If bidirectional, also add reverse
      if (doc['bidirectional'] == true) {
        allEdges.add(
          AIGraphEdge(
            from: to,
            to: from,
            strength: strength,
            type: type,
            label: label,
          ),
        );
        seenPairs.add('$to|$from');
      }
    }

    // Add legacy note-level links if they aren't represented by an edge doc
    for (var edge in existingEdgesLegacy) {
      final from = (edge['from'] ?? '').toString();
      final to = (edge['to'] ?? '').toString();
      if (from.isEmpty || to.isEmpty) continue;
      if (seenPairs.contains('$from|$to')) continue;
      allEdges.add(
        AIGraphEdge(
          from: from,
          to: to,
          strength: 1.0,
          type: EdgeType.manual,
          label: 'Manual',
        ),
      );
    }

    // Finally add AI-suggested edges (don't override existing ones)
    for (var se in smartEdges) {
      final key = '${se.from}|${se.to}';
      if (!seenPairs.contains(key)) {
        allEdges.add(se);
      }
    }

    final clusters = _performClustering(nodes, allEdges);
    final centrality = _calculateCentrality(nodes, allEdges);

    final connectionCounts = <String, int>{};
    for (var edge in allEdges) {
      connectionCounts[edge.from] = (connectionCounts[edge.from] ?? 0) + 1;
      connectionCounts[edge.to] = (connectionCounts[edge.to] ?? 0) + 1;
    }

    for (var node in nodes) {
      node.connectionCount = connectionCounts[node.id] ?? 0;
      node.depth = _calculateNodeDepth(node, allEdges);
    }

    if (_autoLayout) {
      _applyForceDirectedLayout(nodes, allEdges);
    }

    if (!mounted) return;
    setState(() {
      _nodes = nodes;
      _edges = allEdges;
      _clusters = clusters;
      _centrality = centrality;
    });
  }

  // (The rest of methods are the same as in AI implementation: _analyzeContentWithAI, positions, clustering,
  // centrality, force layout, color helpers, etc.)

  ContentAnalysis _analyzeContentWithAI(
    String title,
    String content,
    List<String> tags,
  ) {
    final text = '$title $content ${tags.join(' ')}';
    final words = text.toLowerCase().split(RegExp(r'\W+'));
    final themes = <String>[];
    if (words.any((w) => ['trabajo', 'work', 'job', 'empresa'].contains(w))) {
      themes.add('trabajo');
    }
    if (words.any((w) => ['personal', 'vida', 'family'].contains(w))) {
      themes.add('personal');
    }
    if (words.any((w) => ['idea', 'concept', 'innovation'].contains(w))) {
      themes.add('ideas');
    }
    if (words.any((w) => ['proyecto', 'project', 'plan'].contains(w))) {
      themes.add('proyectos');
    }
    if (words.any((w) => ['study', 'learn', 'education'].contains(w))) {
      themes.add('educacion');
    }
    if (words.any((w) => ['health', 'salud', 'medicina'].contains(w))) {
      themes.add('salud');
    }
    if (words.any((w) => ['money', 'finanzas', 'economia'].contains(w))) {
      themes.add('finanzas');
    }
    if (words.any((w) => ['tech', 'tecnologia', 'software'].contains(w))) {
      themes.add('tecnologia');
    }
    final keywords = words.where((w) => w.length > 3).take(10).toList();
    final sentiment = _calculateSentiment(words);
    final importance = math.min(
      1.0,
      (content.length / 500.0) + (tags.length * 0.1) + (keywords.length * 0.05),
    );
    final category = themes.isNotEmpty ? themes.first : 'general';
    return ContentAnalysis(
      themes: themes,
      keywords: keywords,
      sentiment: sentiment,
      importance: importance,
      category: category,
      wordCount: words.length,
      complexity: _calculateComplexity(text),
    );
  }

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

  double _calculateComplexity(String text) {
    final sentences = text.split(RegExp(r'[.!?]')).length;
    final words = text.split(RegExp(r'\W+')).length;
    return sentences > 0 ? words / sentences : 0.0;
  }

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
      'general': math.pi / 4,
    };
    final baseAngle = categoryAngles[analysis.category] ?? 0.0;
    final angle = baseAngle + (index / total) * 2 * math.pi * 0.2;
    final baseRadius = math.min(size.width, size.height) * 0.2;
    final radius = baseRadius + (1.0 - analysis.importance) * baseRadius * 2;
    final noise = math.sin(index * 1.7) * 30;
    return Offset(
      centerX + radius * math.cos(angle) + noise,
      centerY + radius * math.sin(angle) + noise,
    );
  }

  Offset _calculateClusterPosition(
    int index,
    int total,
    ContentAnalysis analysis,
    Size size,
  ) {
    final clusterCenters = {
      'trabajo': Offset(size.width * 0.2, size.height * 0.2),
      'personal': Offset(size.width * 0.8, size.height * 0.2),
      'ideas': Offset(size.width * 0.2, size.height * 0.8),
      'proyectos': Offset(size.width * 0.8, size.height * 0.8),
      'general': Offset(size.width * 0.5, size.height * 0.5),
    };
    final center =
        clusterCenters[analysis.category] ??
        Offset(size.width * 0.5, size.height * 0.5);
    final angle = (index / total) * 2 * math.pi;
    final radius = 50 + math.Random().nextDouble() * 100;
    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
  }

  Offset _calculateHierarchyPosition(
    int index,
    int total,
    ContentAnalysis analysis,
    Size size,
  ) {
    final levels = 5;
    final level = (analysis.importance * levels).floor();
    final nodesInLevel = total ~/ levels;
    final positionInLevel = index % math.max(1, nodesInLevel);
    final y = size.height * 0.1 + (level / levels) * size.height * 0.8;
    final x = (positionInLevel / math.max(1, nodesInLevel)) * size.width;
    return Offset(x, y);
  }

  Offset _calculateForcePosition(
    int index,
    int total,
    ContentAnalysis analysis,
    Size size,
  ) {
    return Offset(
      size.width * 0.2 + math.Random().nextDouble() * size.width * 0.6,
      size.height * 0.2 + math.Random().nextDouble() * size.height * 0.6,
    );
  }

  Future<List<AIGraphEdge>> _generateSmartConnections(
    List<AIGraphNode> nodes,
  ) async {
    final connections = <AIGraphEdge>[];
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final node1 = nodes[i];
        final node2 = nodes[j];
        final similarity = _calculateSemanticSimilarity(node1, node2);
        if (similarity > _connectionThreshold) {
          final connectionType = _determineConnectionType(
            node1,
            node2,
            similarity,
          );
          connections.add(
            AIGraphEdge(
              from: node1.id,
              to: node2.id,
              strength: similarity,
              type: connectionType,
              label: _generateConnectionLabel(node1, node2, connectionType),
            ),
          );
        }
      }
    }
    return connections;
  }

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧠 Mapa Mental IA'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: Icon(_is3DMode ? Icons.view_in_ar : Icons.view_module),
            onPressed: () => setState(() => _is3DMode = !_is3DMode),
          ),
          IconButton(
            icon: Icon(
              _showParticles ? Icons.auto_awesome : Icons.auto_awesome_outlined,
            ),
            onPressed: () => setState(() => _showParticles = !_showParticles),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'recalculate',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Recalcular Conexiones'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'center',
                child: ListTile(
                  leading: Icon(Icons.center_focus_strong),
                  title: Text('Centrar Vista'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'layout',
                child: ListTile(
                  leading: Icon(Icons.account_tree),
                  title: Text('Reorganizar Layout'),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: KeyboardListener(
        focusNode: _keyboardFocusNode,
        onKeyEvent: _handleKeyEvent,
        child: GlassBackground(
          child: FutureBuilder<void>(
            future: _init,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('🤖 Analizando contenido con IA...'),
                      SizedBox(height: 8),
                      Text(
                        'Generando conexiones inteligentes...',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              }

              if (_nodes.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.psychology, size: 64, color: Colors.white54),
                      SizedBox(height: 16),
                      Text('🧠 Mapa Mental Vacío'),
                      SizedBox(height: 8),
                      Text(
                        'Crea algunas notas para ver la magia de la IA',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              }

              return Stack(
                children: [
                  _buildMainCanvas(),
                  _buildControlPanel(),
                  _buildEdgeFilterPanel(),
                  if (_selectedNodeId != null) _buildNodeInfoPanel(),
                  _buildMetricsPanel(),
                  _buildKeyboardShortcutsHelp(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMainCanvas() {
    return GestureDetector(
      // Use scale gestures for both zoom and pan. ScaleGestureRecognizer
      // is a superset of pan; having both pan and scale handlers causes
      // an assertion in Flutter. We update scale and also apply the
      // focal point delta to implement panning when no node is selected.
      onScaleUpdate: (details) {
        setState(() {
          // Update scale
          _scale = (_scale * details.scale).clamp(0.1, 3.0);

          // Update offset (pan) only when no node is selected. Use
          // focalPointDelta which represents the movement of the
          // gesture focal point in screen coordinates.
          if (_selectedNodeId == null) {
            _offset += details.focalPointDelta;
          }
        });
      },
      onTapDown: (details) {
        final localPosition = (details.localPosition - _offset) / _scale;
        String? tappedNodeId;
        AIGraphEdge? tappedEdge;

        // Check for node tap first
        for (var node in _nodes) {
          final distance = (node.position - localPosition).distance;
          if (distance < 40) {
            tappedNodeId = node.id;
            break;
          }
        }

        // If no node was tapped, check for edge tap
        if (tappedNodeId == null) {
          tappedEdge = _getEdgeAt(localPosition, tolerance: 15);
        }

        setState(() {
          _selectedNodeId = tappedNodeId;
          if (tappedEdge != null) {
            // Show edge info or edit directly
            _showEdgeEditDialog(tappedEdge);
          }
        });
      },
      onLongPressStart: (details) {
        // Begin drag-to-link if started on a node
        final localPosition = (details.localPosition - _offset) / _scale;
        final startNode = _nodeIdAt(localPosition, tolerance: 40);
        if (startNode != null) {
          setState(() {
            _draggingFromNodeId = startNode;
            _draggingCurrentPosition = localPosition;
            _selectedNodeId = startNode;
          });
        }
      },
      onLongPressMoveUpdate: (details) {
        if (_draggingFromNodeId == null) return;
        final localPosition = (details.localPosition - _offset) / _scale;
        setState(() {
          _draggingCurrentPosition = localPosition;
        });
      },
      onLongPressEnd: (details) async {
        if (_draggingFromNodeId == null) return;
        final localPosition = (details.localPosition - _offset) / _scale;
        final targetNode = _nodeIdAt(localPosition, tolerance: 40);
        final fromId = _draggingFromNodeId!;
        setState(() {
          _draggingFromNodeId = null;
          _draggingCurrentPosition = null;
        });
        if (targetNode != null && targetNode != fromId) {
          // Confirm quickly with a snackbar action
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Crear enlace'),
              content: Text(
                'Crear enlace desde "${_nodes.firstWhere((n) => n.id == fromId).title}" hacia "${_nodes.firstWhere((n) => n.id == targetNode).title}"?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Crear'),
                ),
              ],
            ),
          );
          if (!mounted) return;
          if (confirmed == true) {
            try {
              await FirestoreService.instance.addLink(
                uid: _uid,
                fromNoteId: fromId,
                toNoteId: targetNode,
              );
              await _loadGraphWithAI();
              ToastService.success('Enlace creado');
            } catch (e) {
              ToastService.error('Error creando enlace: $e');
            }
          }
        }
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _rotationAnimation]),
        builder: (context, child) {
          // Use LayoutBuilder to ensure the painter receives a finite size
          // and the render box is properly laid out before hit-testing.
          return LayoutBuilder(
            builder: (context, constraints) {
              final canvasSize = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              return CustomPaint(
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
                  // New drag visual state
                  draggingFromNodeId: _draggingFromNodeId,
                  draggingPosition: _draggingCurrentPosition,
                ),
              );
            },
          );
        },
      ),
    );
  }

  String? _nodeIdAt(Offset canvasPos, {double tolerance = 40}) {
    for (var node in _nodes) {
      if ((node.position - canvasPos).distance <= tolerance) return node.id;
    }
    return null;
  }

  Widget _buildControlPanel() {
    return Positioned(
      top: 16,
      right: 16,
      child: Card(
        color: Colors.black.withOpacityCompat(0.8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🎮 Controles',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.zoom_out),
                    onPressed: () =>
                        setState(() => _scale = (_scale * 0.8).clamp(0.1, 3.0)),
                  ),
                  Text(
                    '${(_scale * 100).toInt()}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_in),
                    onPressed: () =>
                        setState(() => _scale = (_scale * 1.2).clamp(0.1, 3.0)),
                  ),
                ],
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
            ],
          ),
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
      child: Card(
        color: Colors.black.withOpacityCompat(0.9),
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
                ...connections.take(3).map((edge) {
                  final otherNodeId = edge.from == node.id
                      ? edge.to
                      : edge.from;
                  final otherNode = _nodes.firstWhere(
                    (n) => n.id == otherNodeId,
                  );
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      _getEdgeTypeIcon(edge.type),
                      size: 16,
                      color: _getEdgeTypeColor(edge.type),
                    ),
                    title: Text(
                      otherNode.title,
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: Text(
                      edge.label,
                      style: const TextStyle(fontSize: 10),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(edge.strength * 100).toInt()}%',
                          style: const TextStyle(fontSize: 10),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 16),
                          onPressed: () async {
                            // try to find an existing edge doc
                            final docs = await FirestoreService.instance
                                .listEdgeDocs(uid: _uid);
                            final match = docs.firstWhere(
                              (d) =>
                                  d['from'] == edge.from && d['to'] == edge.to,
                              orElse: () => <String, dynamic>{},
                            );
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
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
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

  List<AIGraphEdge> _getFilteredEdges() {
    return _edges.where((edge) {
      return _visibleEdgeTypes.contains(edge.type) &&
          edge.strength >= _minEdgeStrength;
    }).toList();
  }

  Widget _buildEdgeFilterPanel() {
    return Positioned(
      top: 16,
      right: 16,
      child: Card(
        color: Colors.black.withOpacityCompat(0.8),
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

  Future<void> _showNodeEdgeManager(String nodeId) async {
    final allConnections = _edges
        .where((e) => e.from == nodeId || e.to == nodeId)
        .toList();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Enlaces de ${_nodes.firstWhere((n) => n.id == nodeId).title}',
        ),
        content: SizedBox(
          width: 400,
          height: 300,
          child: allConnections.isEmpty
              ? const Center(child: Text('No hay enlaces'))
              : ListView.builder(
                  itemCount: allConnections.length,
                  itemBuilder: (context, index) {
                    final edge = allConnections[index];
                    final isOutgoing = edge.from == nodeId;
                    final otherNodeId = isOutgoing ? edge.to : edge.from;
                    final otherNode = _nodes.firstWhere(
                      (n) => n.id == otherNodeId,
                    );
                    return ListTile(
                      leading: Icon(
                        isOutgoing ? Icons.arrow_forward : Icons.arrow_back,
                        color: _getEdgeTypeColor(edge.type),
                      ),
                      title: Text(otherNode.title),
                      subtitle: Text(
                        '${edge.label} • ${(edge.strength * 100).toInt()}%',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 16),
                            onPressed: () async {
                              if (mounted) Navigator.pop(ctx);
                              if (mounted) await _showEdgeEditDialog(edge);
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              size: 16,
                              color: Colors.red,
                            ),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: ctx,
                                builder: (deleteCtx) => AlertDialog(
                                  title: const Text('Eliminar enlace'),
                                  content: Text(
                                    '¿Eliminar enlace con "${otherNode.title}"?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(deleteCtx, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(deleteCtx, true),
                                      child: const Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              );
                              if (!mounted) return;
                              if (confirmed == true && mounted) {
                                try {
                                  await FirestoreService.instance.removeLink(
                                    uid: _uid,
                                    fromNoteId: edge.from,
                                    toNoteId: edge.to,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) await _loadGraphWithAI();
                                  ToastService.success('Enlace eliminado');
                                } catch (e) {
                                  ToastService.error('Error: $e');
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
    // Removed stray widget code after dialog builder
  }

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

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    _particleController.dispose();
    _layoutTimer?.cancel();
    _particleTimer?.cancel();
    super.dispose();
  }
}

/// Painter and models follow (copied from IA implementation)
class AIGraphPainter extends CustomPainter {
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

  const AIGraphPainter({
    required this.nodes,
    required this.edges,
    required this.particles,
    required this.floatingParticles,
    this.selectedNodeId,
    this.hoveredNodeId,
    required this.scale,
    required this.offset,
    required this.is3DMode,
    required this.pulseValue,
    required this.rotationValue,
    required this.clusters,
    required this.centrality,
    this.draggingFromNodeId,
    this.draggingPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    _drawFloatingParticles(canvas);
    _drawClusters(canvas);
    _drawConnections(canvas);
    _drawConnectionParticles(canvas);
    _drawNodes(canvas);
    canvas.restore();
  }

  void _drawFloatingParticles(Canvas canvas) {
    final baseOpacity = 0.1;
    final paint = Paint()
      ..color = Colors.white.withOpacityCompat(baseOpacity)
      ..style = PaintingStyle.fill;
    for (var particle in floatingParticles) {
      // particle.life may drift outside 0..1 during updates; clamp to valid range
      final life = particle.life.clamp(0.0, 1.0);
      final opacity = (baseOpacity * life).clamp(0.0, 1.0);
      canvas.drawCircle(
        particle.position,
        particle.size * life,
        paint..color = Colors.white.withOpacityCompat(opacity),
      );
    }
  }

  void _drawClusters(Canvas canvas) {
    for (var cluster in clusters) {
      final clusterNodes = nodes
          .where((n) => cluster.nodeIds.contains(n.id))
          .toList();
      if (clusterNodes.length < 2) continue;
      final positions = clusterNodes.map((n) => n.position).toList();
      final bounds = _calculateBounds(positions);
      final paint = Paint()
        ..color = cluster.color.withOpacityCompat(0.1)
        ..style = PaintingStyle.fill;
      final strokePaint = Paint()
        ..color = cluster.color.withOpacityCompat(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final rect = RRect.fromRectAndRadius(bounds, const Radius.circular(20));
      canvas.drawRRect(rect, paint);
      canvas.drawRRect(rect, strokePaint);
    }
  }

  Rect _calculateBounds(List<Offset> positions) {
    if (positions.isEmpty) return Rect.zero;
    double minX = positions.first.dx;
    double maxX = positions.first.dx;
    double minY = positions.first.dy;
    double maxY = positions.first.dy;
    for (var pos in positions) {
      minX = math.min(minX, pos.dx);
      maxX = math.max(maxX, pos.dx);
      minY = math.min(minY, pos.dy);
      maxY = math.max(maxY, pos.dy);
    }
    const padding = 40.0;
    return Rect.fromLTRB(
      minX - padding,
      minY - padding,
      maxX + padding,
      maxY + padding,
    );
  }

  void _drawConnections(Canvas canvas) {
    for (var edge in edges) {
      final fromNode = nodes.firstWhere((n) => n.id == edge.from);
      final toNode = nodes.firstWhere((n) => n.id == edge.to);
      final isHighlighted =
          selectedNodeId == edge.from || selectedNodeId == edge.to;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      if (edge.type == EdgeType.strong) {
        paint.shader = ui.Gradient.linear(fromNode.position, toNode.position, [
          fromNode.color,
          toNode.color,
        ]);
        paint.strokeWidth = 4 * edge.strength;
      } else if (edge.type == EdgeType.semantic) {
        paint.color = Colors.purple.withOpacityCompat(0.6 * edge.strength);
        paint.strokeWidth = 3 * edge.strength;
      } else {
        paint.color = Colors.white.withOpacityCompat(0.3 * edge.strength);
        paint.strokeWidth = 2 * edge.strength;
      }
      if (isHighlighted) {
        paint.strokeWidth *= 1.5;
        paint.color = paint.color.withOpacityCompat(
          math.min(1.0, paint.color.a * 2),
        );
      }
      final controlPoint = _calculateControlPoint(
        fromNode.position,
        toNode.position,
      );
      final path = Path()
        ..moveTo(fromNode.position.dx, fromNode.position.dy)
        ..quadraticBezierTo(
          controlPoint.dx,
          controlPoint.dy,
          toNode.position.dx,
          toNode.position.dy,
        );
      canvas.drawPath(path, paint);
      if (isHighlighted || edge.strength > 0.7) {
        _drawArrow(canvas, fromNode.position, toNode.position, paint);
      }
    }
    // Draw dragging ghost line on top of connections if active
    if (draggingFromNodeId != null && draggingPosition != null) {
      try {
        final fromNode = nodes.firstWhere((n) => n.id == draggingFromNodeId);
        final paint = Paint()
          ..color = Colors.white.withOpacityCompat(0.7)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        final path = Path()
          ..moveTo(fromNode.position.dx, fromNode.position.dy)
          ..lineTo(draggingPosition!.dx, draggingPosition!.dy);
        canvas.drawPath(path, paint);
        // small target indicator
        canvas.drawCircle(
          draggingPosition!,
          6,
          Paint()
            ..color = Colors.white.withOpacityCompat(0.9)
            ..style = PaintingStyle.fill,
        );
      } catch (_) {}
    }
  }

  Offset _calculateControlPoint(Offset from, Offset to) {
    final midpoint = (from + to) / 2;
    final perpendicular =
        Offset(-(to.dy - from.dy), to.dx - from.dx).normalized() * 20;
    return midpoint + perpendicular;
  }

  void _drawConnectionParticles(Canvas canvas) {
    for (var particle in particles) {
      final fromNode = nodes.firstWhere((n) => n.id == particle.from);
      final toNode = nodes.firstWhere((n) => n.id == particle.to);
      final t = (math.sin(rotationValue + particle.phase) + 1) / 2;
      final position = Offset.lerp(fromNode.position, toNode.position, t)!;
      final paint = Paint()
        ..color = Colors.cyan.withOpacityCompat(0.8 * particle.strength)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(position, 3 * particle.strength, paint);
      final trailPaint = Paint()
        ..color = Colors.cyan.withOpacityCompat(0.3 * particle.strength)
        ..style = PaintingStyle.fill;
      for (int i = 1; i <= 3; i++) {
        final trailT = math.max(0.0, t - i * 0.1);
        final trailPos = Offset.lerp(
          fromNode.position,
          toNode.position,
          trailT,
        )!;
        canvas.drawCircle(trailPos, (3 - i) * particle.strength, trailPaint);
      }
    }
  }

  void _drawNodes(Canvas canvas) {
    for (var node in nodes) {
      final isSelected = node.id == selectedNodeId;
      final isHovered = node.id == hoveredNodeId;
      final centralityValue = centrality[node.id] ?? 0.0;
      final baseSize = 30.0;
      final importanceMultiplier = 1.0 + node.importance * 0.5;
      final centralityMultiplier = 1.0 + centralityValue * 0.3;
      final nodeSize = baseSize * importanceMultiplier * centralityMultiplier;
      var finalSize = nodeSize;
      if (isSelected) {
        finalSize *= pulseValue;
      }
      if (isHovered) {
        finalSize *= 1.1;
      }
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacityCompat(0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);
      final glowPaint = Paint()
        ..color = node.color.withOpacityCompat(0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, finalSize * 0.5);
      final nodePaint = Paint()..style = PaintingStyle.fill;
      if (is3DMode) {
        nodePaint.shader = ui.Gradient.radial(
          node.position,
          finalSize,
          [
            node.color.withOpacityCompat(1.0),
            node.color.withOpacityCompat(0.7),
            node.color.withOpacityCompat(0.3),
          ],
          [0.0, 0.7, 1.0],
        );
      } else {
        nodePaint.color = node.color;
      }
      final strokePaint = Paint()
        ..color = isSelected
            ? Colors.white
            : Colors.white.withOpacityCompat(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 4 : 2;
      if (is3DMode) {
        canvas.drawCircle(
          node.position + const Offset(3, 3),
          finalSize,
          shadowPaint,
        );
        if (isSelected || isHovered) {
          canvas.drawCircle(node.position, finalSize * 1.2, glowPaint);
        }
      }
      canvas.drawCircle(node.position, finalSize, nodePaint);
      canvas.drawCircle(node.position, finalSize, strokePaint);
      if (node.connectionCount > 0) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: node.connectionCount.toString(),
            style: TextStyle(
              color: Colors.white,
              fontSize: finalSize * 0.4,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          node.position - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }
      if (node.importance > 0.7) {
        final starPaint = Paint()
          ..color = Colors.amber
          ..style = PaintingStyle.fill;
        _drawStar(
          canvas,
          node.position + Offset(finalSize * 0.7, -finalSize * 0.7),
          8,
          starPaint,
        );
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    const points = 5;
    const angle = 2 * math.pi / points;
    for (int i = 0; i < points; i++) {
      final x = center.dx + size * math.cos(i * angle - math.pi / 2);
      final y = center.dy + size * math.sin(i * angle - math.pi / 2);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      final innerX =
          center.dx + (size * 0.4) * math.cos((i + 0.5) * angle - math.pi / 2);
      final innerY =
          center.dy + (size * 0.4) * math.sin((i + 0.5) * angle - math.pi / 2);
      path.lineTo(innerX, innerY);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    final direction = to - from;
    final distance = direction.distance;
    if (distance == 0) return;
    final normalized = direction / distance;
    final arrowPos = to - normalized * 40;
    const arrowSize = 12.0;
    final angle = math.atan2(direction.dy, direction.dx);
    final path = Path();
    path.moveTo(arrowPos.dx, arrowPos.dy);
    path.lineTo(
      arrowPos.dx - arrowSize * math.cos(angle - math.pi / 6),
      arrowPos.dy - arrowSize * math.sin(angle - math.pi / 6),
    );
    path.lineTo(
      arrowPos.dx - arrowSize * math.cos(angle + math.pi / 6),
      arrowPos.dy - arrowSize * math.sin(angle + math.pi / 6),
    );
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant AIGraphPainter oldDelegate) {
    return nodes != oldDelegate.nodes ||
        edges != oldDelegate.edges ||
        selectedNodeId != oldDelegate.selectedNodeId ||
        scale != oldDelegate.scale ||
        offset != oldDelegate.offset ||
        pulseValue != oldDelegate.pulseValue ||
        rotationValue != oldDelegate.rotationValue;
  }
}

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
  final Offset velocity;
  final double size;
  double life;
  FloatingParticle({
    required this.position,
    Offset? velocity,
    double? size,
    double? life,
  }) : velocity =
           velocity ??
           Offset(
             (math.Random().nextDouble() - 0.5) * 2,
             (math.Random().nextDouble() - 0.5) * 2,
           ),
       size = size ?? (2 + math.Random().nextDouble() * 4),
       life = life ?? 1.0;
  void update() {
    position += velocity;
    life -= 0.01;
  }
}

class ContentAnalysis {
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

// Legend widget removed (unused) — kept out to reduce analyzer noise
