import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  late final Dio _dio;
  final StorageService _storageService;

  ApiClient({StorageService? storageService})
      : _storageService = storageService ?? StorageService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storageService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          _storageService.clearAll();
        }
        return handler.next(error);
      },
    ));
  }

  String _extractErrorMessage(DioException e) {
    if (e.response?.data != null && e.response!.data is Map) {
      return e.response!.data['error'] ?? 'Error desconocido';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Tiempo de conexión agotado. Verifica tu conexión a internet.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Sin conexión a internet';
    }
    return 'Error de conexión';
  }

  // ==================== DEVICE ACTIVATION ====================

  /// Activate device with activation code (NO authentication required)
  /// This is called before login to register the device with the backend
  Future<Map<String, dynamic>> activateDevice({
    required String activationCode,
    required String fcmToken,
    required String platform,
    required String deviceName,
  }) async {
    try {
      debugPrint('ApiClient: Sending device activation request...');
      // Use a separate Dio instance without auth interceptor
      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));

      final response = await dio.post('/devices/activate', data: {
        'activation_code': activationCode,
        'fcm_token': fcmToken,
        'platform': platform,
        'device_name': deviceName,
      });

      debugPrint('ApiClient: Activation response status: ${response.statusCode}');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('ApiClient: Activation DioException: ${e.message}');
      debugPrint('ApiClient: Activation Response: ${e.response?.data}');
      throw ApiException(
        _extractErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ==================== AUTH ====================

  /// Login with identification number and contract number
  /// Returns customer and loan data along with JWT token
  Future<Map<String, dynamic>> login({
    required String identificationNumber,
    required String contractNumber,
  }) async {
    try {
      debugPrint('ApiClient: Sending login request...');
      final response = await _dio.post('/auth/login', data: {
        'auth': {
          'identification_number': identificationNumber,
          'contract_number': contractNumber,
        },
      });

      debugPrint('ApiClient: Response status: ${response.statusCode}');
      debugPrint('ApiClient: Response data type: ${response.data.runtimeType}');
      debugPrint('ApiClient: Response data: ${response.data}');

      final data = response.data as Map<String, dynamic>;

      // Save token
      if (data['token'] == null) {
        throw ApiException('No token in response');
      }
      final token = data['token'] as String;
      debugPrint('ApiClient: Saving token...');
      await _storageService.saveToken(token);

      // Save customer ID if present
      if (data['customer'] != null) {
        debugPrint('ApiClient: Parsing customer for ID...');
        final customerData = data['customer'] as Map<String, dynamic>;
        if (customerData['id'] != null) {
          await _storageService.saveCustomerId(customerData['id'] as int);
        }
      }

      debugPrint('ApiClient: Login complete, returning data');
      return data;
    } on DioException catch (e) {
      debugPrint('ApiClient: DioException: ${e.message}');
      debugPrint('ApiClient: Response: ${e.response?.data}');
      throw ApiException(_extractErrorMessage(e), statusCode: e.response?.statusCode);
    } catch (e, stackTrace) {
      debugPrint('ApiClient: Unexpected error: $e');
      debugPrint('ApiClient: Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Request contract number recovery via SMS
  Future<String> forgotContract({required String phone}) async {
    try {
      final response = await _dio.get(
        '/auth/forgot_contract',
        queryParameters: {'phone': phone},
      );
      return response.data['message'] as String;
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e), statusCode: e.response?.statusCode);
    }
  }

  /// Logout - clear local storage
  Future<void> logout() async {
    await _storageService.clearAll();
  }

  // ==================== DASHBOARD ====================

  /// Get dashboard data including customer, loan, next payment, and device status
  Future<DashboardData> getDashboard() async {
    try {
      final response = await _dio.get('/dashboard');
      return DashboardData.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e), statusCode: e.response?.statusCode);
    }
  }

  // ==================== INSTALLMENTS ====================

  /// Get all installments for the active loan
  Future<({List<Installment> installments, InstallmentSummary summary})> getInstallments() async {
    try {
      final response = await _dio.get('/installments');
      final data = response.data as Map<String, dynamic>;

      final installments = (data['installments'] as List)
          .map((json) => Installment.fromJson(json as Map<String, dynamic>))
          .toList();

      final summary = InstallmentSummary.fromJson(data['summary'] as Map<String, dynamic>);

      return (installments: installments, summary: summary);
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e), statusCode: e.response?.statusCode);
    }
  }

  // ==================== PAYMENTS ====================

  /// Submit a payment with optional receipt image
  Future<Map<String, dynamic>> submitPayment({
    required int installmentId,
    required double amount,
    required DateTime paymentDate,
    File? receiptImage,
  }) async {
    try {
      final Map<String, dynamic> paymentData = {
        'installment_id': installmentId,
        'amount': amount,
        'payment_date': paymentDate.toIso8601String().split('T')[0],
      };

      // If there's a receipt image, convert to base64
      if (receiptImage != null) {
        final bytes = await receiptImage.readAsBytes();
        paymentData['receipt_image'] = base64Encode(bytes);
      }

      final response = await _dio.post('/payments', data: {
        'payment': paymentData,
      });

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e), statusCode: e.response?.statusCode);
    }
  }

  // ==================== NOTIFICATIONS ====================

  /// Get paginated notifications
  Future<({List<AppNotification> notifications, NotificationPagination pagination})>
      getNotifications({int page = 1, int perPage = 10}) async {
    try {
      final response = await _dio.get('/notifications', queryParameters: {
        'page': page,
        'per_page': perPage,
      });

      final data = response.data as Map<String, dynamic>;

      final notifications = (data['notifications'] as List)
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();

      final pagination =
          NotificationPagination.fromJson(data['pagination'] as Map<String, dynamic>);

      return (notifications: notifications, pagination: pagination);
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e), statusCode: e.response?.statusCode);
    }
  }

  // ==================== DEVICE TOKENS (FCM) ====================

  /// Register FCM device token with backend
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
    required String deviceName,
    required String osVersion,
    required String appVersion,
  }) async {
    try {
      await _dio.post('/device_tokens', data: {
        'device_token': {
          'token': token,
          'platform': platform,
          'device_name': deviceName,
          'os_version': osVersion,
          'app_version': appVersion,
        },
      });
      debugPrint('ApiClient: Device token registered successfully');
    } on DioException catch (e) {
      debugPrint('ApiClient: Failed to register device token: ${e.message}');
      // Don't throw - token registration failure shouldn't block the user
    }
  }

  /// Unregister FCM device token (on logout)
  Future<void> unregisterDeviceToken(String token) async {
    try {
      await _dio.delete('/device_tokens', queryParameters: {'token': token});
      debugPrint('ApiClient: Device token unregistered successfully');
    } on DioException catch (e) {
      debugPrint('ApiClient: Failed to unregister device token: ${e.message}');
      // Don't throw - unregister failure shouldn't block logout
    }
  }

  /// Refresh device token (call on app open to update last_used_at)
  Future<void> refreshDeviceToken(String token) async {
    try {
      await _dio.put('/device_tokens/refresh', queryParameters: {'token': token});
      debugPrint('ApiClient: Device token refreshed successfully');
    } on DioException catch (e) {
      debugPrint('ApiClient: Failed to refresh device token: ${e.message}');
      // Don't throw - refresh failure shouldn't affect the app
    }
  }
}
