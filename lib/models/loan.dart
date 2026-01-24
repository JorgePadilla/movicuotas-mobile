import 'device.dart';

/// Helper to parse numbers that may come as String or num
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class Loan {
  final int id;
  final String contractNumber;
  final int customerId;
  final String status;
  final double totalAmount;
  final double approvedAmount;
  final double downPaymentPercentage;
  final double downPaymentAmount;
  final double financedAmount;
  final double interestRate;
  final int numberOfInstallments;
  final double installmentAmount;
  final DateTime startDate;
  final DateTime endDate;
  final String branchNumber;
  final Device? device;

  Loan({
    required this.id,
    required this.contractNumber,
    required this.customerId,
    required this.status,
    required this.totalAmount,
    required this.approvedAmount,
    required this.downPaymentPercentage,
    required this.downPaymentAmount,
    required this.financedAmount,
    required this.interestRate,
    required this.numberOfInstallments,
    required this.installmentAmount,
    required this.startDate,
    required this.endDate,
    required this.branchNumber,
    this.device,
  });

  factory Loan.fromJson(Map<String, dynamic> json) {
    return Loan(
      id: _parseInt(json['id']),
      contractNumber: json['contract_number'] as String? ?? '',
      customerId: _parseInt(json['customer_id']),
      status: json['status'] as String? ?? 'pending',
      totalAmount: _parseDouble(json['total_amount']),
      approvedAmount: _parseDouble(json['approved_amount']),
      downPaymentPercentage: _parseDouble(json['down_payment_percentage']),
      downPaymentAmount: _parseDouble(json['down_payment_amount']),
      financedAmount: _parseDouble(json['financed_amount']),
      interestRate: _parseDouble(json['interest_rate']),
      numberOfInstallments: _parseInt(json['number_of_installments']),
      installmentAmount: _parseDouble(json['installment_amount']),
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : DateTime.now(),
      branchNumber: json['branch_number'] as String? ?? '',
      device: json['device'] != null
          ? Device.fromJson(json['device'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isDefaulted => status == 'defaulted';

  /// Monthly payment amount (from backend calculation with interest)
  /// Falls back to simple division only if installmentAmount is not available
  double get monthlyPayment =>
      installmentAmount > 0 ? installmentAmount : (numberOfInstallments > 0 ? financedAmount / numberOfInstallments : 0.0);

  /// Device name for display
  String get deviceName => device?.fullName ?? 'Dispositivo';

  /// Next payment date (estimated based on start date and installment count)
  /// This is a fallback - actual next payment should come from installments
  DateTime? get nextPaymentDate => null;
}
