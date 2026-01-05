import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_client.dart' show ApiClient, ApiException;
import '../services/storage_service.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  final StorageService _storageService;

  AuthStatus _status = AuthStatus.initial;
  Customer? _customer;
  Loan? _loan;
  String? _error;

  AuthProvider({ApiClient? apiClient, StorageService? storageService})
      : _apiClient = apiClient ?? ApiClient(),
        _storageService = storageService ?? StorageService();

  AuthStatus get status => _status;
  Customer? get customer => _customer;
  Loan? get loan => _loan;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  /// Check if user is already logged in (has valid token)
  Future<void> checkAuthStatus() async {
    final hasToken = await _storageService.hasToken();
    if (hasToken) {
      // Try to fetch dashboard to validate token
      try {
        final dashboard = await _apiClient.getDashboard();
        _customer = dashboard.customer;
        _loan = dashboard.loan;
        _status = AuthStatus.authenticated;
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
    await _apiClient.logout();
    _customer = null;
    _loan = null;
    _status = AuthStatus.unauthenticated;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
