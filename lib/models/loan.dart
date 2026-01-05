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
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      branchNumber: json['branch_number'] as String? ?? '',
      device: json['device'] != null
          ? Device.fromJson(json['device'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isDefaulted => status == 'defaulted';
}
