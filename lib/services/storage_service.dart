import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _tokenKey = 'jwt_token';
  static const _customerIdKey = 'customer_id';
  static const _deviceActivatedKey = 'device_activated';
  static const _rememberSessionKey = 'remember_session';

  final FlutterSecureStorage _storage;

  StorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> saveCustomerId(int customerId) async {
    await _storage.write(key: _customerIdKey, value: customerId.toString());
  }

  Future<int?> getCustomerId() async {
    final value = await _storage.read(key: _customerIdKey);
    return value != null ? int.tryParse(value) : null;
  }

  Future<void> clearAll() async {
    // Preserve remember session preference
    final remember = await getRememberSession();
    await _storage.deleteAll();
    await saveRememberSession(remember);
  }

  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Save device activation status
  Future<void> saveDeviceActivated(bool activated) async {
    await _storage.write(key: _deviceActivatedKey, value: activated.toString());
  }

  /// Check if device has been activated
  Future<bool> isDeviceActivated() async {
    final value = await _storage.read(key: _deviceActivatedKey);
    return value == 'true';
  }

  /// Save remember session preference
  Future<void> saveRememberSession(bool remember) async {
    await _storage.write(key: _rememberSessionKey, value: remember.toString());
  }

  /// Get remember session preference (default: true)
  Future<bool> getRememberSession() async {
    final value = await _storage.read(key: _rememberSessionKey);
    return value != 'false'; // Default true if not set
  }

  /// Clear only the token (for "don't remember session" case)
  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }
}
