import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_client.dart' show ApiClient, ApiException;
import '../services/notification_service.dart';
import '../services/storage_service.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

/// Result of device activation attempt
class ActivationResult {
  final bool success;
  final String? errorMessage;
  final int? statusCode;

  ActivationResult({
    required this.success,
    this.errorMessage,
    this.statusCode,
  });
}

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  final StorageService _storageService;
  final NotificationService _notificationService;

  AuthStatus _status = AuthStatus.initial;
  Customer? _customer;
  Loan? _loan;
  String? _error;
  bool _isDeviceActivated = false;

  AuthProvider({
    ApiClient? apiClient,
    StorageService? storageService,
    NotificationService? notificationService,
  })  : _apiClient = apiClient ?? ApiClient(),
        _storageService = storageService ?? StorageService(),
        _notificationService = notificationService ?? NotificationService();

  AuthStatus get status => _status;
  Customer? get customer => _customer;
  Loan? get loan => _loan;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isDeviceActivated => _isDeviceActivated;

  /// Check if user is already logged in (has valid token)
  Future<void> checkAuthStatus() async {
    // Check if device was previously activated
    _isDeviceActivated = await _storageService.isDeviceActivated();

    final hasToken = await _storageService.hasToken();
    if (hasToken) {
      // Try to fetch dashboard to validate token
      try {
        final dashboard = await _apiClient.getDashboard();
        _customer = dashboard.customer;
        _loan = dashboard.loan;
        _status = AuthStatus.authenticated;

        // Refresh FCM device token on app open
        await _refreshDeviceToken();
      } catch (e) {
        // Token invalid or expired
        await _storageService.clearAll();
        _status = AuthStatus.unauthenticated;
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Activate device with activation code
  /// Returns ActivationResult with success status and error info if failed
  Future<ActivationResult> activateDevice({required String activationCode}) async {
    try {
      debugPrint('AuthProvider: Starting device activation...');

      // Get FCM token
      final fcmToken = _notificationService.fcmToken;
      if (fcmToken == null) {
        debugPrint('AuthProvider: No FCM token available');
        return ActivationResult(
          success: false,
          errorMessage: 'Error de configuración. Reinstale la app.',
          statusCode: 400,
        );
      }

      // Get device info
      final deviceInfo = await _notificationService.getDeviceInfo();

      // Call API to activate device
      final data = await _apiClient.activateDevice(
        activationCode: activationCode,
        fcmToken: fcmToken,
        platform: deviceInfo['platform']!,
        deviceName: deviceInfo['device_name']!,
      );

      debugPrint('AuthProvider: Device activation successful');
      _isDeviceActivated = true;
      await _storageService.saveDeviceActivated(true);

      // Parse customer and loan if present (skip login flow)
      if (data['customer'] != null) {
        debugPrint('AuthProvider: Parsing customer from activation...');
        _customer = Customer.fromJson(data['customer'] as Map<String, dynamic>);
      }
      if (data['loan'] != null) {
        debugPrint('AuthProvider: Parsing loan from activation...');
        _loan = Loan.fromJson(data['loan'] as Map<String, dynamic>);
      }

      // If token was saved, set authenticated status
      if (data['token'] != null) {
        debugPrint('AuthProvider: Token received, setting authenticated status');
        _status = AuthStatus.authenticated;
      }

      notifyListeners();

      return ActivationResult(success: true);
    } on ApiException catch (e) {
      debugPrint('AuthProvider: Activation ApiException: ${e.message}');
      return ActivationResult(
        success: false,
        errorMessage: e.message,
        statusCode: e.statusCode,
      );
    } catch (e) {
      debugPrint('AuthProvider: Activation unexpected error: $e');
      return ActivationResult(
        success: false,
        errorMessage: 'Error de conexión. Verifique su internet.',
      );
    }
  }

  /// Login with identification number and contract number
  Future<bool> login({
    required String identificationNumber,
    required String contractNumber,
  }) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();

    try {
      debugPrint('AuthProvider: Starting login...');
      final data = await _apiClient.login(
        identificationNumber: identificationNumber,
        contractNumber: contractNumber,
      );
      debugPrint('AuthProvider: Login response received');
      debugPrint('AuthProvider: Data keys: ${data.keys}');

      if (data['customer'] == null) {
        throw ApiException('No customer data in response');
      }
      if (data['loan'] == null) {
        throw ApiException('No loan data in response');
      }

      debugPrint('AuthProvider: Parsing customer...');
      _customer = Customer.fromJson(data['customer'] as Map<String, dynamic>);
      debugPrint('AuthProvider: Parsing loan...');
      _loan = Loan.fromJson(data['loan'] as Map<String, dynamic>);
      debugPrint('AuthProvider: Login successful!');
      _status = AuthStatus.authenticated;
      notifyListeners();

      // Register FCM device token after successful login
      await _registerDeviceToken();

      return true;
    } on ApiException catch (e) {
      debugPrint('AuthProvider: ApiException: ${e.message}');
      _error = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e, stackTrace) {
      debugPrint('AuthProvider: Unexpected error: $e');
      debugPrint('AuthProvider: Stack trace: $stackTrace');
      _error = 'Error procesando respuesta: $e';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Request contract number recovery
  Future<String?> forgotContract({required String phone}) async {
    try {
      return await _apiClient.forgotContract(phone: phone);
    } on ApiException catch (e) {
      _error = e.message;
      return null;
    }
  }

  /// Logout
  Future<void> logout() async {
    // Unregister FCM device token before logout
    await _unregisterDeviceToken();

    await _apiClient.logout();
    _customer = null;
    _loan = null;
    _status = AuthStatus.unauthenticated;
    _error = null;
    notifyListeners();
  }

  /// Register FCM device token with backend
  Future<void> _registerDeviceToken() async {
    try {
      final token = _notificationService.fcmToken;
      if (token == null) {
        debugPrint('AuthProvider: No FCM token available');
        return;
      }

      final deviceInfo = await _notificationService.getDeviceInfo();
      await _apiClient.registerDeviceToken(
        token: token,
        platform: deviceInfo['platform']!,
        deviceName: deviceInfo['device_name']!,
        osVersion: deviceInfo['os_version']!,
        appVersion: deviceInfo['app_version']!,
      );
    } catch (e) {
      debugPrint('AuthProvider: Failed to register device token: $e');
    }
  }

  /// Unregister FCM device token from backend
  Future<void> _unregisterDeviceToken() async {
    try {
      final token = _notificationService.fcmToken;
      if (token == null) return;

      await _apiClient.unregisterDeviceToken(token);
      await _notificationService.deleteToken();
    } catch (e) {
      debugPrint('AuthProvider: Failed to unregister device token: $e');
    }
  }

  /// Refresh FCM device token (call on app open)
  /// If token doesn't exist in backend, register it
  Future<void> _refreshDeviceToken() async {
    final token = await _notificationService.refreshToken();
    if (token == null) {
      debugPrint('AuthProvider: No FCM token available for refresh');
      return;
    }

    // Try to refresh, if it fails (token not found), register it
    final success = await _apiClient.refreshDeviceToken(token);
    if (success) {
      debugPrint('AuthProvider: Device token refreshed');
    } else {
      debugPrint('AuthProvider: Token not found, registering...');
      await _registerDeviceToken();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
