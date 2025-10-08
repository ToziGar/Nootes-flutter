import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/glass.dart';
import '../services/duplicate_cleanup_service.dart';
import '../theme/app_colors.dart';

/// 🧹 Página de Administración Avanzada del Sistema
/// Características:
/// - 🔍 Detección y limpieza de duplicados
/// - 📊 Análisis de integridad de datos
/// - 🛠️ Herramientas de mantenimiento
/// - 📈 Estadísticas del sistema
class AdminCleanupPage extends StatefulWidget {
  const AdminCleanupPage({super.key});

  @override
  State<AdminCleanupPage> createState() => _AdminCleanupPageState();
}

class _AdminCleanupPageState extends State<AdminCleanupPage> 
    with TickerProviderStateMixin {
  
  bool _isScanning = false;
  bool _isCleaning = false;
  ComprehensiveCleanupResult? _lastResult;
  DuplicateCleanupResult? _lastFolderScan;
  DuplicateCleanupResult? _lastNoteScan;
  
  late AnimationController _scanController;
  late AnimationController _cleanController;
  late Animation<double> _scanAnimation;
  late Animation<double> _cleanAnimation;
  
  @override
  void initState() {
    super.initState();
    _initAnimations();
    _performInitialScan();
  }
  
  void _initAnimations() {
    _scanController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _cleanController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _scanAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );
    
    _cleanAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _cleanController, curve: Curves.easeInOut),
    );
  }
  
  Future<void> _performInitialScan() async {
    setState(() => _isScanning = true);
    _scanController.repeat();
    
    try {
      // Escanear carpetas
      final folderScan = await DuplicateCleanupService.instance
          .cleanFolderDuplicates(dryRun: true);
      
      // Escanear notas
      final noteScan = await DuplicateCleanupService.instance
          .cleanNoteDuplicates(dryRun: true);
      
      setState(() {
        _lastFolderScan = folderScan;
        _lastNoteScan = noteScan;
      });
      
    } finally {
      setState(() => _isScanning = false);
      _scanController.stop();
    }
  }
  
  Future<void> _performFullCleanup() async {
    // Confirmación
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;
    
    setState(() => _isCleaning = true);
    _cleanController.repeat();
    
    try {
      final result = await DuplicateCleanupService.instance
          .performComprehensiveCleanup(dryRun: false);
      
      setState(() => _lastResult = result);
      
      // Feedback háptico
      HapticFeedback.heavyImpact();
      
      // Mostrar resultado
      _showResultDialog(result);
      
      // Re-escanear después de limpiar
      await Future.delayed(const Duration(seconds: 2));
      await _performInitialScan();
      
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() => _isCleaning = false);
      _cleanController.stop();
    }
  }
  
  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('⚠️ Confirmación Requerida'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de que quieres eliminar los duplicados?'),
            SizedBox(height: 16),
            Text(
              '⚠️ Esta acción NO se puede deshacer',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '✅ Se conservarán las versiones más recientes',
              style: TextStyle(color: Colors.green),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('❌ Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('🗑️ Limpiar Duplicados'),
          ),
        ],
      ),
    ) ?? false;
  }
  
  void _showResultDialog(ComprehensiveCleanupResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        title: Row(
          children: [
            Icon(
              result.success ? Icons.check_circle : Icons.error,
              color: result.success ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(result.success ? '✅ Limpieza Completada' : '❌ Error en Limpieza'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📁 Carpetas: ${result.folderCleanup.duplicatesRemoved} duplicados eliminados'),
            Text('📝 Notas: ${result.noteCleanup.duplicatesRemoved} duplicados eliminados'),
            const SizedBox(height: 16),
            Text(
              '🎉 Total eliminados: ${result.totalDuplicatesRemoved}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('👍 Entendido'),
          ),
        ],
      ),
    );
  }
  
  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('❌ Error'),
          ],
        ),
        content: Text('Error durante la limpieza:\n\n$error'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('👍 Entendido'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧹 Administración del Sistema'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _performInitialScan,
          ),
        ],
      ),
      body: GlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con estadísticas
              _buildStatsHeader(),
              
              const SizedBox(height: 24),
              
              // Sección de duplicados de carpetas
              _buildFolderDuplicatesSection(),
              
              const SizedBox(height: 24),
              
              // Sección de duplicados de notas
              _buildNoteDuplicatesSection(),
              
              const SizedBox(height: 24),
              
              // Botones de acción
              _buildActionButtons(),
              
              const SizedBox(height: 24),
              
              // Resultado de última limpieza
              if (_lastResult != null) _buildLastResultSection(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatsHeader() {
    final totalDuplicates = (_lastFolderScan?.duplicatesFound ?? 0) + 
                           (_lastNoteScan?.duplicatesFound ?? 0);
    
    return Card(
      color: Colors.black.withOpacity(0.8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  '📊 Estado del Sistema',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '🔍 Duplicados',
                    '$totalDuplicates',
                    totalDuplicates > 0 ? Colors.orange : Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    '🏥 Estado',
                    totalDuplicates == 0 ? 'Limpio' : 'Requiere limpieza',
                    totalDuplicates == 0 ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.1),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFolderDuplicatesSection() {
    return Card(
      color: Colors.black.withOpacity(0.8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.folder_copy, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  '📁 Duplicados de Carpetas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (_isScanning)
              AnimatedBuilder(
                animation: _scanAnimation,
                builder: (context, child) {
                  return Column(
                    children: [
                      LinearProgressIndicator(
                        value: null,
                        backgroundColor: Colors.grey.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('🔍 Escaneando carpetas...'),
                    ],
                  );
                },
              )
            else if (_lastFolderScan != null)
              _buildFolderResults(_lastFolderScan!)
            else
              const Text('⏳ Iniciando escaneo...'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFolderResults(DuplicateCleanupResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Duplicados encontrados: ${result.duplicatesFound}'),
            if (result.duplicatesFound > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '⚠️ ${result.duplicatesFound}',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        
        if (result.groups != null && result.groups!.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Grupos con duplicados:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          ...result.groups!.take(5).map((group) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.folder, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${group.folderName} (${group.totalCount} copias)',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          )),
          if (result.groups!.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '... y ${result.groups!.length - 5} grupos más',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ],
    );
  }
  
  Widget _buildNoteDuplicatesSection() {
    return Card(
      color: Colors.black.withOpacity(0.8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.content_copy, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '📝 Duplicados de Notas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (_isScanning)
              const Column(
                children: [
                  LinearProgressIndicator(),
                  SizedBox(height: 8),
                  Text('🔍 Escaneando notas...'),
                ],
              )
            else if (_lastNoteScan != null)
              _buildNoteResults(_lastNoteScan!)
            else
              const Text('⏳ Preparando escaneo...'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNoteResults(DuplicateCleanupResult result) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Duplicados encontrados: ${result.duplicatesFound}'),
        if (result.duplicatesFound > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '⚠️ ${result.duplicatesFound}',
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildActionButtons() {
    final totalDuplicates = (_lastFolderScan?.duplicatesFound ?? 0) + 
                           (_lastNoteScan?.duplicatesFound ?? 0);
    
    return Column(
      children: [
        // Botón principal de limpieza
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: (_isCleaning || _isScanning || totalDuplicates == 0) 
                ? null 
                : _performFullCleanup,
            style: ElevatedButton.styleFrom(
              backgroundColor: totalDuplicates > 0 ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isCleaning
                ? AnimatedBuilder(
                    animation: _cleanAnimation,
                    builder: (context, child) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('🧹 Limpiando sistema...'),
                        ],
                      );
                    },
                  )
                : totalDuplicates > 0
                    ? Text('🗑️ Limpiar $totalDuplicates duplicados')
                    : const Text('✅ Sistema limpio'),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Botón secundario de re-escaneo
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isScanning ? null : _performInitialScan,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isScanning
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('🔍 Escaneando...'),
                    ],
                  )
                : const Text('🔄 Re-escanear sistema'),
          ),
        ),
      ],
    );
  }
  
  Widget _buildLastResultSection() {
    final result = _lastResult!;
    
    return Card(
      color: Colors.black.withOpacity(0.8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.error,
                  color: result.success ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                const Text(
                  '📋 Última Limpieza',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            Text('📁 Carpetas: ${result.folderCleanup.duplicatesRemoved} eliminados'),
            Text('📝 Notas: ${result.noteCleanup.duplicatesRemoved} eliminados'),
            const SizedBox(height: 8),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Text(
                '🎉 Total: ${result.totalDuplicatesRemoved} duplicados eliminados',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _scanController.dispose();
    _cleanController.dispose();
    super.dispose();
  }
}