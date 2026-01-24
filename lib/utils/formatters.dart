import 'package:intl/intl.dart';

class Formatters {
  static final _numberFormat = NumberFormat('#,##0', 'es');

  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final _monthYearFormat = DateFormat('MMMM yyyy', 'es');

  /// Format amount as Honduran Lempiras (e.g., "L. 1,500")
  /// Always puts "L." on the left side
  static String currency(double amount) {
    return 'L. ${_numberFormat.format(amount.ceil())}';
  }

  /// Format date as dd/MM/yyyy
  static String date(DateTime date) {
    return _dateFormat.format(date);
  }

  /// Format datetime as dd/MM/yyyy HH:mm
  static String dateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }

  /// Format as month and year (e.g., "Enero 2026")
  static String monthYear(DateTime date) {
    return _monthYearFormat.format(date);
  }

  /// Get relative date text (e.g., "Hoy", "Mañana", "En 5 días", "Vencida hace 3 días")
  static String relativeDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final difference = due.difference(today).inDays;

    if (difference == 0) {
      return 'Hoy';
    } else if (difference == 1) {
      return 'Mañana';
    } else if (difference > 1 && difference <= 7) {
      return 'En $difference días';
    } else if (difference > 7) {
      return date(dueDate);
    } else if (difference == -1) {
      return 'Ayer';
    } else {
      return 'Hace ${-difference} días';
    }
  }

  /// Format phone number for display
  static String phone(String phone) {
    // Already formatted or international format
    if (phone.startsWith('+')) {
      return phone;
    }
    // Honduran format: XXXX-XXXX
    if (phone.length == 8) {
      return '${phone.substring(0, 4)}-${phone.substring(4)}';
    }
    return phone;
  }

  /// Mask identity number for privacy (show last 4 digits)
  static String maskIdentity(String identity) {
    if (identity.length <= 4) return identity;
    return '****${identity.substring(identity.length - 4)}';
  }
}
