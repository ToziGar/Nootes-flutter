// Logging service for structured logging throughout the application
import 'package:flutter/foundation.dart';

/// Log levels for filtering and categorizing logs
enum LogLevel {
  debug(0, '🐛'),
  info(1, 'ℹ️'),
  warning(2, '⚠️'),
  error(3, '❌'),
  critical(4, '💥');

  const LogLevel(this.value, this.emoji);
  final int value;
  final String emoji;
}

/// Structured logging service
class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  static LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;
  
  /// Set minimum log level
  static void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  /// Log a debug message
  static void debug(String message, {String? tag, Map<String, dynamic>? data}) {
    _log(LogLevel.debug, message, tag: tag, data: data);
  }

  /// Log an info message
  static void info(String message, {String? tag, Map<String, dynamic>? data}) {
    _log(LogLevel.info, message, tag: tag, data: data);
  }

  /// Log a warning message
  static void warning(String message, {String? tag, Map<String, dynamic>? data}) {
    _log(LogLevel.warning, message, tag: tag, data: data);
  }

  /// Log an error message
  static void error(String message, {String? tag, Map<String, dynamic>? data, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag, data: data, error: error, stackTrace: stackTrace);
  }

  /// Log a critical error message
  static void critical(String message, {String? tag, Map<String, dynamic>? data, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.critical, message, tag: tag, data: data, error: error, stackTrace: stackTrace);
  }

  /// Internal logging method
  static void _log(
    LogLevel level, 
    String message, {
    String? tag,
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.value < _minLevel.value) return;

    final timestamp = DateTime.now().toIso8601String();
    final tagStr = tag != null ? '[$tag] ' : '';
    final dataStr = data != null && data.isNotEmpty ? ' | Data: $data' : '';
    final errorStr = error != null ? ' | Error: $error' : '';
    
    final logMessage = '${level.emoji} $timestamp $tagStr$message$dataStr$errorStr';
    
    if (kDebugMode) {
      print(logMessage);
      if (stackTrace != null && level.value >= LogLevel.error.value) {
        print('Stack trace:\n$stackTrace');
      }
    }
    
    // Here you could also send logs to external services like Firebase Crashlytics,
    // Sentry, or other logging providers
    _sendToExternalService(level, message, tag, data, error, stackTrace);
  }

  /// Send logs to external logging services
  static void _sendToExternalService(
    LogLevel level,
    String message,
    String? tag,
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  ) {
    // TODO: Implement external logging service integration
    // Examples:
    // - Firebase Crashlytics for crashes
    // - Custom analytics service for user actions
    // - Remote logging service for production debugging
  }

  /// Log user action for analytics
  static void logUserAction(String action, {Map<String, dynamic>? parameters}) {
    info('User action: $action', tag: 'UserAction', data: parameters);
  }

  /// Log performance metrics
  static void logPerformance(String operation, Duration duration, {Map<String, dynamic>? metadata}) {
    info('Performance: $operation took ${duration.inMilliseconds}ms', 
         tag: 'Performance', 
         data: {'duration_ms': duration.inMilliseconds, ...?metadata});
  }

  /// Log API calls
  static void logApiCall(String endpoint, {String? method, int? statusCode, Duration? duration}) {
    info('API call: ${method ?? 'GET'} $endpoint', 
         tag: 'API', 
         data: {
           'endpoint': endpoint,
           'method': method,
           'status_code': statusCode,
           'duration_ms': duration?.inMilliseconds,
         });
  }
}