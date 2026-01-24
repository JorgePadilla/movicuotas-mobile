import 'customer.dart';
import 'loan.dart';
import 'installment.dart';

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

class DeviceStatus {
  final String imei;
  final String phoneModel;
  final String status;
  final bool isBlocked;

  DeviceStatus({
    required this.imei,
    required this.phoneModel,
    required this.status,
    required this.isBlocked,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      imei: json['imei'] as String? ?? '',
      phoneModel: json['phone_model'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      isBlocked: json['is_blocked'] == true,
    );
  }
}

class DashboardData {
  final Customer customer;
  final Loan loan;
  final Installment? nextPayment;
  final int overdueCount;
  final double totalOverdueAmount;
  final DeviceStatus? deviceStatus;
  final int unreadNotificationsCount;

  DashboardData({
    required this.customer,
    required this.loan,
    this.nextPayment,
    required this.overdueCount,
    required this.totalOverdueAmount,
    this.deviceStatus,
    this.unreadNotificationsCount = 0,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      customer: Customer.fromJson(json['customer'] as Map<String, dynamic>),
      loan: Loan.fromJson(json['loan'] as Map<String, dynamic>),
      nextPayment: json['next_payment'] != null
          ? Installment.fromJson(json['next_payment'] as Map<String, dynamic>)
          : null,
      overdueCount: _parseInt(json['overdue_count']),
      totalOverdueAmount: _parseDouble(json['total_overdue_amount']),
      deviceStatus: json['device_status'] != null
          ? DeviceStatus.fromJson(json['device_status'] as Map<String, dynamic>)
          : null,
      unreadNotificationsCount: _parseInt(json['unread_notifications_count']),
    );
  }

  bool get hasOverduePayments => overdueCount > 0;
  bool get hasUnreadNotifications => unreadNotificationsCount > 0;
}
