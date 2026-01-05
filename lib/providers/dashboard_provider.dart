import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_client.dart';

class DashboardProvider extends ChangeNotifier {
  final ApiClient _apiClient;

  DashboardData? _dashboardData;
  bool _isLoading = false;
  String? _error;

  DashboardProvider({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  DashboardData? get dashboardData => _dashboardData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _dashboardData != null;

  Customer? get customer => _dashboardData?.customer;
  Loan? get loan => _dashboardData?.loan;
  Installment? get nextPayment => _dashboardData?.nextPayment;
  int get overdueCount => _dashboardData?.overdueCount ?? 0;
  double get totalOverdueAmount => _dashboardData?.totalOverdueAmount ?? 0;
  DeviceStatus? get deviceStatus => _dashboardData?.deviceStatus;

  Future<void> loadDashboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _dashboardData = await _apiClient.getDashboard();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadDashboard();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
