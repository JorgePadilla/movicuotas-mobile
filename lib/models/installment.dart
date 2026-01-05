enum InstallmentStatus {
  pending,
  paid,
  overdue,
}

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

class Installment {
  final int id;
  final int loanId;
  final int installmentNumber;
  final DateTime dueDate;
  final double amount;
  final InstallmentStatus status;
  final DateTime? paidDate;
  final int daysOverdue;
  final bool isOverdue;

  Installment({
    required this.id,
    required this.loanId,
    required this.installmentNumber,
    required this.dueDate,
    required this.amount,
    required this.status,
    this.paidDate,
    required this.daysOverdue,
    required this.isOverdue,
  });

  factory Installment.fromJson(Map<String, dynamic> json) {
    return Installment(
      id: _parseInt(json['id']),
      loanId: _parseInt(json['loan_id']),
      installmentNumber: _parseInt(json['installment_number']),
      dueDate: DateTime.parse(json['due_date'] as String),
      amount: _parseDouble(json['amount']),
      status: _parseStatus(json['status'] as String? ?? 'pending'),
      paidDate: json['paid_date'] != null
          ? DateTime.parse(json['paid_date'] as String)
          : null,
      daysOverdue: _parseInt(json['days_overdue']),
      isOverdue: json['is_overdue'] == true,
    );
  }

  static InstallmentStatus _parseStatus(String status) {
    switch (status) {
      case 'paid':
        return InstallmentStatus.paid;
      case 'overdue':
        return InstallmentStatus.overdue;
      default:
        return InstallmentStatus.pending;
    }
  }

  bool get isPaid => status == InstallmentStatus.paid;
  bool get isPending => status == InstallmentStatus.pending;
}

class InstallmentSummary {
  final int totalInstallments;
  final int pending;
  final int paid;
  final int overdue;

  InstallmentSummary({
    required this.totalInstallments,
    required this.pending,
    required this.paid,
    required this.overdue,
  });

  factory InstallmentSummary.fromJson(Map<String, dynamic> json) {
    return InstallmentSummary(
      totalInstallments: _parseInt(json['total_installments']),
      pending: _parseInt(json['pending']),
      paid: _parseInt(json['paid']),
      overdue: _parseInt(json['overdue']),
    );
  }
}
