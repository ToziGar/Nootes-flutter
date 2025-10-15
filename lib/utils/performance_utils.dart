// Performance monitoring and optimization utilities
import 'dart:async';
import 'package:nootes/services/logging_service.dart';

/// Utilidad para medir el rendimiento de operaciones
class PerformanceMonitor {
  static final Map<String, DateTime> _startTimes = {};
  static final Map<String, List<Duration>> _metrics = {};

  /// Inicia el monitoreo de una operación
  static void start(String operationName) {
    _startTimes[operationName] = DateTime.now();
    LoggingService.debug('Started monitoring: $operationName', tag: 'Performance');
  }

  /// Finaliza el monitoreo y registra la duración
  static Duration end(String operationName) {
    final startTime = _startTimes.remove(operationName);
    if (startTime == null) {
      LoggingService.warning('No start time found for operation: $operationName', tag: 'Performance');
      return Duration.zero;
    }

    final duration = DateTime.now().difference(startTime);
    
    // Guardar métrica
    _metrics.putIfAbsent(operationName, () => []).add(duration);
    
    LoggingService.logPerformance(operationName, duration);
    
    // Alertar si la operación es muy lenta
    if (duration.inMilliseconds > 5000) {
      LoggingService.warning('Slow operation detected: $operationName took ${duration.inMilliseconds}ms', 
                            tag: 'Performance');
    }
    
    return duration;
  }

  /// Ejecuta una operación con monitoreo automático
  static Future<T> monitor<T>(String operationName, Future<T> Function() operation) async {
    start(operationName);
    try {
      final result = await operation();
      end(operationName);
      return result;
    } catch (e) {
      end(operationName);
      LoggingService.error('Operation failed: $operationName', tag: 'Performance', error: e);
      rethrow;
    }
  }

  /// Obtiene estadísticas de rendimiento
  static Map<String, Map<String, dynamic>> getStats() {
    final stats = <String, Map<String, dynamic>>{};
    
    for (final entry in _metrics.entries) {
      final durations = entry.value;
      if (durations.isEmpty) continue;
      
      final totalMs = durations.fold<int>(0, (sum, d) => sum + d.inMilliseconds);
      final avgMs = totalMs / durations.length;
      final minMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);
      final maxMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);
      
      stats[entry.key] = {
        'count': durations.length,
        'avgMs': avgMs.round(),
        'minMs': minMs,
        'maxMs': maxMs,
        'totalMs': totalMs,
      };
    }
    
    return stats;
  }

  /// Limpia las métricas acumuladas
  static void clearStats() {
    _metrics.clear();
    _startTimes.clear();
  }
}

/// Utilidad para operaciones en lotes (batch operations)
class BatchOperationUtils {
  /// Ejecuta operaciones en lotes para mejorar el rendimiento
  static Future<List<T>> executeBatch<T>(
    List<Future<T> Function()> operations, {
    int batchSize = 10,
    Duration delayBetweenBatches = const Duration(milliseconds: 100),
  }) async {
    final results = <T>[];
    
    for (int i = 0; i < operations.length; i += batchSize) {
      final batchEnd = (i + batchSize > operations.length) ? operations.length : i + batchSize;
      final batch = operations.sublist(i, batchEnd);
      
      LoggingService.debug('Executing batch ${(i / batchSize).floor() + 1}/${((operations.length - 1) / batchSize).floor() + 1}', 
                          tag: 'BatchOperation');
      
      final batchResults = await Future.wait(batch.map((op) => op()));
      results.addAll(batchResults);
      
      // Pausa entre lotes para evitar sobrecargar el servidor
      if (i + batchSize < operations.length) {
        await Future.delayed(delayBetweenBatches);
      }
    }
    
    return results;
  }

  /// Procesa una lista de elementos en lotes
  static Future<List<R>> processBatch<T, R>(
    List<T> items,
    Future<R> Function(T item) processor, {
    int batchSize = 10,
    Duration delayBetweenBatches = const Duration(milliseconds: 100),
  }) async {
    final operations = items.map((item) => () => processor(item)).toList();
    return executeBatch(operations, batchSize: batchSize, delayBetweenBatches: delayBetweenBatches);
  }
}

/// Utilidad para optimizar consultas de Firestore
class FirestoreQueryOptimizer {
  /// Optimiza una consulta dividiéndola en chunks para evitar límites
  static Future<List<T>> executeChunkedQuery<T>(
    List<String> values,
    Future<List<T>> Function(List<String> chunk) queryFunction, {
    int chunkSize = 10, // Firestore permite máximo 10 elementos en whereIn
  }) async {
    if (values.isEmpty) return [];
    
    final results = <T>[];
    
    for (int i = 0; i < values.length; i += chunkSize) {
      final chunk = values.sublist(i, i + chunkSize > values.length ? values.length : i + chunkSize);
      final chunkResults = await queryFunction(chunk);
      results.addAll(chunkResults);
    }
    
    return results;
  }

  /// Optimiza consultas con paginación
  static Stream<List<T>> paginatedQuery<T>(
    Future<List<T>> Function(int limit, String? startAfter) queryFunction, {
    int pageSize = 20,
  }) async* {
    String? lastDocumentId;
    bool hasMore = true;
    
    while (hasMore) {
      final results = await queryFunction(pageSize, lastDocumentId);
      
      if (results.isEmpty) {
        hasMore = false;
      } else {
        yield results;
        
        if (results.length < pageSize) {
          hasMore = false;
        } else {
          // Asumiendo que T tiene un campo 'id'
          lastDocumentId = (results.last as dynamic).id as String?;
        }
      }
    }
  }
}

/// Utilidad para implementar debouncing
class DebounceUtils {
  static final Map<String, Timer> _timers = {};

  /// Ejecuta una función con debouncing
  static void debounce(String key, Duration delay, VoidFunction action) {
    _timers[key]?.cancel();
    _timers[key] = Timer(delay, () {
      action();
      _timers.remove(key);
    });
  }

  /// Cancela un debounce específico
  static void cancelDebounce(String key) {
    _timers[key]?.cancel();
    _timers.remove(key);
  }

  /// Cancela todos los debounces
  static void cancelAllDebounces() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}

/// Utilidad para gestión de memoria y recursos
class ResourceManager {
  static final Map<String, dynamic> _resources = {};

  /// Registra un recurso para seguimiento
  static void registerResource(String key, dynamic resource) {
    _resources[key] = resource;
    LoggingService.debug('Resource registered: $key', tag: 'ResourceManager');
  }

  /// Libera un recurso específico
  static void releaseResource(String key) {
    final resource = _resources.remove(key);
    if (resource != null) {
      // Intentar liberar el recurso si tiene método dispose
      try {
        if (resource is Disposable) {
          resource.dispose();
        } else if (resource.runtimeType.toString().contains('StreamSubscription')) {
          (resource as StreamSubscription).cancel();
        }
      } catch (e) {
        LoggingService.warning('Error disposing resource: $key', tag: 'ResourceManager', data: {'error': e.toString()});
      }
      LoggingService.debug('Resource released: $key', tag: 'ResourceManager');
    }
  }

  /// Libera todos los recursos registrados
  static void releaseAllResources() {
    final keys = _resources.keys.toList();
    for (final key in keys) {
      releaseResource(key);
    }
    LoggingService.info('All resources released', tag: 'ResourceManager');
  }

  /// Obtiene estadísticas de recursos
  static Map<String, int> getResourceStats() {
    final stats = <String, int>{};
    for (final resource in _resources.values) {
      final type = resource.runtimeType.toString();
      stats[type] = (stats[type] ?? 0) + 1;
    }
    return stats;
  }
}

/// Interface para recursos que pueden ser liberados
abstract class Disposable {
  void dispose();
}

/// Función typedef para funciones sin parámetros
typedef VoidFunction = void Function();