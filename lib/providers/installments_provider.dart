import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_client.dart';

class InstallmentsProvider extends ChangeNotifier {
  final ApiClient _apiClient;

  List<Installment> _installments = [];
  InstallmentSummary? _summary;
  bool _isLoading = false;
  String? _error;

  InstallmentsProvider({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  List<Installment> get installments => _installments;
  InstallmentSummary? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Installment> get paidInstallments =>
      _installments.where((i) => i.isPaid).toList();

  List<Installment> get pendingInstallments =>
      _installments.where((i) => i.isPending).toList();

  List<Installment> get overdueInstallments =>
      _installments.where((i) => i.isOverdue).toList();

  Future<void> loadInstallments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiClient.getInstallments();
      _installments = result.installments;
      _summary = result.summary;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadInstallments();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
