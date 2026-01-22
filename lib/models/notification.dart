class AppNotification {
  final int id;
  final String title;
  final String message;
  final String notificationType;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.isRead,
    required this.createdAt,
    this.data,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      title: json['title'] as String,
      message: json['message'] as String,
      notificationType: json['notification_type'] as String,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  bool get isPaymentReminder => notificationType == 'payment_reminder';
  bool get isPaymentConfirmed => notificationType == 'payment_confirmed';
  bool get isPaymentOverdue => notificationType == 'payment_overdue';
  bool get isDeviceBlocked => notificationType == 'device_blocked';
  bool get isDeviceUnblocked => notificationType == 'device_unblocked';
}

class NotificationPagination {
  final int currentPage;
  final int totalPages;
  final int totalCount;
  final int perPage;

  NotificationPagination({
    required this.currentPage,
    required this.totalPages,
    required this.totalCount,
    required this.perPage,
  });

  factory NotificationPagination.fromJson(Map<String, dynamic> json) {
    return NotificationPagination(
      currentPage: _parseInt(json['current_page']),
      totalPages: _parseInt(json['total_pages']),
      totalCount: _parseInt(json['total_count']),
      perPage: _parseInt(json['per_page']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.parse(value);
    return 0;
  }

  bool get hasNextPage => currentPage < totalPages;
}
