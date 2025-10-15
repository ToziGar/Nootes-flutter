import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;
import '../widgets/glass.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';
import '../theme/color_utils.dart';

/// 🧠 Mapa Mental Ultra-Avanzado con IA y Conexiones Inteligentes
/// Características:
/// - ✨ Conexiones automáticas basadas en contenido
/// - 🎨 Renderizado 3D con efectos de partículas
/// - 🤖 Análisis semántico inteligente
/// - 🌊 Animaciones fluidas y transiciones cinematográficas
/// - 📊 Clustering automático y métricas de red
/// - 🎯 Sistema de filtros avanzados
class AIInteractiveGraphPage extends StatefulWidget {
  const AIInteractiveGraphPage({super.key});

  @override
  State<AIInteractiveGraphPage> createState() => _AIInteractiveGraphPageState();
}

class _AIInteractiveGraphPageState extends State<AIInteractiveGraphPage>
    with TickerProviderStateMixin {
  late Future<void> _init;
  List<AIGraphNode> _nodes = [];
  List<AIGraphEdge> _edges = [];
  final List<ParticleConnection> _particles = [];
  String? _selectedNodeId;
  String? _hoveredNodeId;

  // 🎮 Controles de vista
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  bool _is3DMode = true;
  bool _showParticles = true;
  bool _autoLayout = true;

  // 🤖 Configuración IA
  final NodeClusteringMode _clusteringMode = NodeClusteringMode.semantic;
  VisualizationStyle _visualStyle = VisualizationStyle.galaxy;
  double _connectionThreshold = 0.3;

  // 🎭 Animaciones
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _particleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  // 📊 Métricas y análisis
  Map<String, double> _centrality = {};
  List<NodeCluster> _clusters = [];

  // 🎨 Efectos visuales
  Timer? _layoutTimer;
  final List<FloatingParticle> _floatingParticles = [];

  String get _uid => AuthService.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _init = _loadGraphWithAI();
    // Iniciar sistema de partículas después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startParticleSystem();
      }
    });
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
    _layoutTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _updateParticles();
      if (_showParticles) {
        setState(() {});
      }
    });
  }

  void _updateParticles() {
    // Actualizar partículas flotantes
    _floatingParticles.removeWhere((p) => p.life <= 0);
    for (var particle in _floatingParticles) {
      particle.update();
    }

    // Añadir nuevas partículas
    if (_floatingParticles.length < 50 && _showParticles) {
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

    // Actualizar partículas de conexión
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

  /// 🤖 Carga el grafo con análisis de IA
  Future<void> _loadGraphWithAI() async {
    final svc = FirestoreService.instance;
    final notes = await svc.listNotes(uid: _uid);
    final existingEdges = await svc.listEdges(uid: _uid);

    // 📝 Procesar notas y crear nodos inteligentes
    if (!mounted) return;
    final nodes = <AIGraphNode>[];
    final size = Size(
      MediaQuery.of(context).size.width,
      MediaQuery.of(context).size.height,
    );

    for (var i = 0; i < notes.length; i++) {
      final note = notes[i];
      final id = note['id'].toString();
      final title = (note['title']?.toString() ?? 'Sin título').trim();
      final content = (note['content']?.toString() ?? '').trim();
      final tags = (note['tags'] as List?)?.cast<String>() ?? [];

      // 🧠 Análisis de contenido con IA
      final aiAnalysis = _analyzeContentWithAI(title, content, tags);

      // 📍 Posición inicial inteligente
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

    // 🔗 Crear conexiones inteligentes automáticas
    final smartEdges = await _generateSmartConnections(nodes);

    // 📊 Combinar con conexiones existentes
    final allEdges = <AIGraphEdge>[];

    // Añadir conexiones existentes
    for (var edge in existingEdges) {
      allEdges.add(
        AIGraphEdge(
          from: edge['from'] ?? '',
          to: edge['to'] ?? '',
          strength: 1.0,
          type: EdgeType.manual,
          label: 'Manual',
        ),
      );
    }

    // Añadir conexiones inteligentes
    allEdges.addAll(smartEdges);

    // 🏷️ Análisis de clustering
    final clusters = _performClustering(nodes, allEdges);

    // 📈 Calcular métricas de centralidad
    final centrality = _calculateCentrality(nodes, allEdges);

    // 🎯 Actualizar nodos con información calculada
    final connectionCounts = <String, int>{};
    for (var edge in allEdges) {
      connectionCounts[edge.from] = (connectionCounts[edge.from] ?? 0) + 1;
      connectionCounts[edge.to] = (connectionCounts[edge.to] ?? 0) + 1;
    }

    for (var node in nodes) {
      node.connectionCount = connectionCounts[node.id] ?? 0;
      node.depth = _calculateNodeDepth(node, allEdges);
    }

    // 🌌 Aplicar layout automático si está habilitado
    if (_autoLayout) {
      _applyForceDirectedLayout(nodes, allEdges);
    }

    setState(() {
      _nodes = nodes;
      _edges = allEdges;
      _clusters = clusters;
      _centrality = centrality;
    });
  }

  /// 🧠 Análisis de contenido con IA simulada
  ContentAnalysis _analyzeContentWithAI(
    String title,
    String content,
    List<String> tags,
  ) {
    final text = '$title $content ${tags.join(' ')}';
    final words = text.toLowerCase().split(RegExp(r'\W+'));

    // 📊 Análisis de temas
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

    // 📝 Palabras clave
    final keywords = words.where((w) => w.length > 3).take(10).toList();

    // 💡 Sentimiento (simulado)
    final sentiment = _calculateSentiment(words);

    // ⭐ Importancia basada en longitud, tags y palabras clave
    final importance = math.min(
      1.0,
      (content.length / 500.0) + (tags.length * 0.1) + (keywords.length * 0.05),
    );

    // 🏷️ Categoría principal
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

  /// 📍 Posición inteligente basada en análisis
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

    // Diferentes "brazos" de la galaxia según categoría
    final categoryAngles = {
      'trabajo': 0.0,
      'personal': math.pi / 2,
      'ideas': math.pi,
      'proyectos': 3 * math.pi / 2,
      'general': math.pi / 4,
    };

    final baseAngle = categoryAngles[analysis.category] ?? 0.0;
    final angle =
        baseAngle +
        (index / total) * 2 * math.pi * 0.2; // Dispersión en el brazo

    // Radio basado en importancia (nodos más importantes cerca del centro)
    final baseRadius = math.min(size.width, size.height) * 0.2;
    final radius = baseRadius + (1.0 - analysis.importance) * baseRadius * 2;

    // Añadir ruido para aspecto más orgánico
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
    final positionInLevel = index % nodesInLevel;

    final y = size.height * 0.1 + (level / levels) * size.height * 0.8;
    final x = (positionInLevel / nodesInLevel) * size.width;

    return Offset(x, y);
  }

  Offset _calculateForcePosition(
    int index,
    int total,
    ContentAnalysis analysis,
    Size size,
  ) {
    // Posición inicial aleatoria, se ajustará con el algoritmo de fuerzas
    return Offset(
      size.width * 0.2 + math.Random().nextDouble() * size.width * 0.6,
      size.height * 0.2 + math.Random().nextDouble() * size.height * 0.6,
    );
  }

  /// 🔗 Genera conexiones inteligentes automáticas
  Future<List<AIGraphEdge>> _generateSmartConnections(
    List<AIGraphNode> nodes,
  ) async {
    final connections = <AIGraphEdge>[];

    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final node1 = nodes[i];
        final node2 = nodes[j];

        // 🧠 Calcular similitud semántica
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

  /// 🎯 Calcula similitud semántica entre dos nodos
  double _calculateSemanticSimilarity(AIGraphNode node1, AIGraphNode node2) {
    double similarity = 0.0;

    // Similitud por tags compartidos
    final sharedTags = node1.tags.toSet().intersection(node2.tags.toSet());
    similarity += sharedTags.length * 0.3;

    // Similitud por temas
    final sharedThemes = node1.aiAnalysis.themes.toSet().intersection(
      node2.aiAnalysis.themes.toSet(),
    );
    similarity += sharedThemes.length * 0.4;

    // Similitud por palabras clave
    final sharedKeywords = node1.aiAnalysis.keywords.toSet().intersection(
      node2.aiAnalysis.keywords.toSet(),
    );
    similarity += (sharedKeywords.length / 10.0) * 0.2;

    // Similitud por categoría
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

  String _generateConnectionLabel(
    AIGraphNode node1,
    AIGraphNode node2,
    EdgeType type,
  ) {
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

  /// 🏷️ Realiza clustering de nodos
  List<NodeCluster> _performClustering(
    List<AIGraphNode> nodes,
    List<AIGraphEdge> edges,
  ) {
    final clusters = <NodeCluster>[];

    switch (_clusteringMode) {
      case NodeClusteringMode.semantic:
        clusters.addAll(_clusterBySemantic(nodes));
        break;
      case NodeClusteringMode.connectivity:
        clusters.addAll(_clusterByConnectivity(nodes, edges));
        break;
      case NodeClusteringMode.importance:
        clusters.addAll(_clusterByImportance(nodes));
        break;
    }

    return clusters;
  }

  List<NodeCluster> _clusterBySemantic(List<AIGraphNode> nodes) {
    final clusterMap = <String, List<String>>{};

    for (var node in nodes) {
      final category = node.aiAnalysis.category;
      clusterMap.putIfAbsent(category, () => []).add(node.id);
    }

    return clusterMap.entries
        .map(
          (entry) => NodeCluster(
            id: entry.key,
            name: entry.key.toUpperCase(),
            nodeIds: entry.value,
            color: _getCategoryColor(entry.key),
          ),
        )
        .toList();
  }

  List<NodeCluster> _clusterByConnectivity(
    List<AIGraphNode> nodes,
    List<AIGraphEdge> edges,
  ) {
    // Implementación simplificada de clustering por conectividad
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
    final highImportance = nodes
        .where((n) => n.importance > 0.7)
        .map((n) => n.id)
        .toList();
    final mediumImportance = nodes
        .where((n) => n.importance > 0.4 && n.importance <= 0.7)
        .map((n) => n.id)
        .toList();
    final lowImportance = nodes
        .where((n) => n.importance <= 0.4)
        .map((n) => n.id)
        .toList();

    return [
      if (highImportance.isNotEmpty)
        NodeCluster(
          id: 'high',
          name: 'Alta Importancia',
          nodeIds: highImportance,
          color: Colors.red,
        ),
      if (mediumImportance.isNotEmpty)
        NodeCluster(
          id: 'medium',
          name: 'Media Importancia',
          nodeIds: mediumImportance,
          color: Colors.orange,
        ),
      if (lowImportance.isNotEmpty)
        NodeCluster(
          id: 'low',
          name: 'Baja Importancia',
          nodeIds: lowImportance,
          color: Colors.grey,
        ),
    ];
  }

  /// 📊 Calcula métricas de centralidad
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
      centrality[node.id] = strength / nodes.length;
    }

    return centrality;
  }

  int _calculateNodeDepth(AIGraphNode node, List<AIGraphEdge> edges) {
    // Profundidad basada en número de conexiones
    final connections = edges
        .where((e) => e.from == node.id || e.to == node.id)
        .length;
    return (connections / 3).ceil();
  }

  /// 🌊 Aplica layout de fuerzas dirigidas
  void _applyForceDirectedLayout(
    List<AIGraphNode> nodes,
    List<AIGraphEdge> edges,
  ) {
    const iterations = 100;
    const repulsionStrength = 1000.0;
    const attractionStrength = 0.1;
    const damping = 0.9;

    for (int iter = 0; iter < iterations; iter++) {
      // Reset velocities
      for (var node in nodes) {
        node.velocity = Offset.zero;
      }

      // Repulsion between all nodes
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

      // Attraction along edges
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

      // Apply velocities with damping
      for (var node in nodes) {
        node.position += node.velocity * damping;
        node.velocity *= damping;
      }
    }
  }

  /// 🎨 Color avanzado basado en análisis de IA
  Color _getAdvancedColorForNode(ContentAnalysis analysis) {
    // Color base por categoría
    final baseColor = _getCategoryColor(analysis.category);

    // Modificar por importancia (más brillante = más importante)
    final brightness = 0.5 + (analysis.importance * 0.5);

    // Modificar por sentimiento
    final hue = HSVColor.fromColor(baseColor).hue;
    var saturation = HSVColor.fromColor(baseColor).saturation;
    var value = HSVColor.fromColor(baseColor).value * brightness;

    // Ajustar por sentimiento
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
      body: GlassBackground(
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
                // Canvas principal con efectos
                _buildMainCanvas(),

                // Panel de control flotante
                _buildControlPanel(),

                // Panel de información del nodo seleccionado
                if (_selectedNodeId != null) _buildNodeInfoPanel(),

                // Métricas flotantes
                _buildMetricsPanel(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainCanvas() {
    return GestureDetector(
      onPanUpdate: _selectedNodeId == null
          ? (details) {
              setState(() => _offset += details.delta);
            }
          : null,
      onScaleUpdate: (details) {
        setState(() {
          _scale = (_scale * details.scale).clamp(0.1, 3.0);
        });
      },
      onTapDown: (details) {
        // Detectar tap en nodos
        final localPosition = (details.localPosition - _offset) / _scale;
        String? tappedNodeId;

        for (var node in _nodes) {
          final distance = (node.position - localPosition).distance;
          if (distance < 40) {
            // Radio del nodo
            tappedNodeId = node.id;
            break;
          }
        }

        setState(() {
          _selectedNodeId = tappedNodeId;
        });
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: Listenable.merge([_pulseAnimation, _rotationAnimation]),
            builder: (context, child) {
              return CustomPaint(
                size: Size(
                  constraints.maxWidth.isFinite ? constraints.maxWidth : 800,
                  constraints.maxHeight.isFinite ? constraints.maxHeight : 600,
                ),
                painter: AIGraphPainter(
                  nodes: _nodes,
                  edges: _edges,
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
                ),
              );
            },
          );
        },
      ),
    );
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

              // Zoom
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

              // Estilo visual
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

              // Umbral de conexión
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
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _selectedNodeId = null),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Información de IA
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
                    trailing: Text(
                      '${(edge.strength * 100).toInt()}%',
                      style: const TextStyle(fontSize: 10),
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
    _pulseController.dispose();
    _rotationController.dispose();
    _particleController.dispose();
    _layoutTimer?.cancel();
    super.dispose();
  }
}

/// 🎨 Painter avanzado para el mapa mental con IA
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
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    // Dibujar partículas flotantes
    _drawFloatingParticles(canvas);

    // Dibujar clusters de fondo
    _drawClusters(canvas);

    // Dibujar conexiones con efectos
    _drawConnections(canvas);

    // Dibujar partículas de conexión
    _drawConnectionParticles(canvas);

    // Dibujar nodos con efectos 3D
    _drawNodes(canvas);

    canvas.restore();
  }

  void _drawFloatingParticles(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.white.withOpacityCompat(0.1)
      ..style = PaintingStyle.fill;

    for (var particle in floatingParticles) {
      canvas.drawCircle(
        particle.position,
        particle.size * particle.life,
        paint..color = Colors.white.withOpacityCompat(0.1 * particle.life),
      );
    }
  }

  void _drawClusters(Canvas canvas) {
    for (var cluster in clusters) {
      final clusterNodes = nodes
          .where((n) => cluster.nodeIds.contains(n.id))
          .toList();
      if (clusterNodes.length < 2) continue;

      // Calcular envolvente convexa simplificada
      final positions = clusterNodes.map((n) => n.position).toList();
      final bounds = _calculateBounds(positions);

      final paint = Paint()
        ..color = cluster.color.withOpacityCompat(0.1)
        ..style = PaintingStyle.fill;

      final strokePaint = Paint()
        ..color = cluster.color.withOpacityCompat(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      // Dibujar área del cluster
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

    // Añadir padding
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

      // Configurar paint según tipo de conexión
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

      // Dibujar línea con curvatura suave
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

      // Dibujar flecha direccional
      if (isHighlighted || edge.strength > 0.7) {
        _drawArrow(canvas, fromNode.position, toNode.position, paint);
      }
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

      // Calcular posición de la partícula a lo largo de la conexión
      final t = (math.sin(rotationValue + particle.phase) + 1) / 2;
      final position = Offset.lerp(fromNode.position, toNode.position, t)!;

      final paint = Paint()
        ..color = Colors.cyan.withOpacityCompat(0.8 * particle.strength)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(position, 3 * particle.strength, paint);

      // Efecto de estela
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

      // Tamaño basado en importancia y centralidad
      final baseSize = 30.0;
      final importanceMultiplier = 1.0 + node.importance * 0.5;
      final centralityMultiplier = 1.0 + centralityValue * 0.3;
      final nodeSize = baseSize * importanceMultiplier * centralityMultiplier;

      // Efectos de selección y hover
      var finalSize = nodeSize;
      if (isSelected) finalSize *= pulseValue;
      if (isHovered) finalSize *= 1.1;

      // Configurar paints
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacityCompat(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      final glowPaint = Paint()
        ..color = node.color.withOpacityCompat(0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, finalSize * 0.5);

      final nodePaint = Paint()..style = PaintingStyle.fill;

      if (is3DMode) {
        // Gradiente 3D
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

      // Dibujar efectos
      if (is3DMode) {
        // Sombra
        canvas.drawCircle(
          node.position + const Offset(3, 3),
          finalSize,
          shadowPaint,
        );

        // Resplandor
        if (isSelected || isHovered) {
          canvas.drawCircle(node.position, finalSize * 1.2, glowPaint);
        }
      }

      // Nodo principal
      canvas.drawCircle(node.position, finalSize, nodePaint);
      canvas.drawCircle(node.position, finalSize, strokePaint);

      // Indicador de conexiones
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

      // Indicador de importancia
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

      // Punto interior
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

/// 🧠 Modelo de nodo con IA
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

/// 🔗 Modelo de conexión inteligente
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

/// 🎨 Partícula de conexión
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

/// ✨ Partícula flotante
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

/// 🧠 Análisis de contenido con IA
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

/// 🏷️ Cluster de nodos
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

/// 🎭 Enums para configuración
enum EdgeType { strong, semantic, thematic, weak, manual }

enum NodeClusteringMode { semantic, connectivity, importance }

enum VisualizationStyle { galaxy, cluster, hierarchy, force }

/// 🔧 Extensiones útiles
extension OffsetExtensions on Offset {
  Offset normalized() {
    final d = distance;
    return d > 0 ? this / d : Offset.zero;
  }
}
