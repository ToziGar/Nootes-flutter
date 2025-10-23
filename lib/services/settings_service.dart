import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Global settings service for feature toggles
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const _storage = FlutterSecureStorage();

  static const _smartTagsKey = 'feature_enable_smart_tags';
  static const _autoVersioningKey = 'feature_enable_auto_versioning';

  Future<bool> getEnableSmartTags() async {
    final v = await _storage.read(key: _smartTagsKey);
    return v == null || v == 'true'; // enabled by default
  }

  Future<void> setEnableSmartTags(bool enabled) async {
    await _storage.write(key: _smartTagsKey, value: enabled.toString());
  }

  Future<bool> getEnableAutoVersioning() async {
    final v = await _storage.read(key: _autoVersioningKey);
    return v == null || v == 'true'; // enabled by default
  }

  Future<void> setEnableAutoVersioning(bool enabled) async {
    await _storage.write(key: _autoVersioningKey, value: enabled.toString());
  }
}
