import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_client.dart';

class NotificationsProvider extends ChangeNotifier {
  final ApiClient _apiClient;

  List<AppNotification> _notifications = [];
  NotificationPagination? _pagination;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  NotificationsProvider({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  List<AppNotification> get notifications => _notifications;
  NotificationPagination? get pagination => _pagination;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasMore => _pagination?.hasNextPage ?? false;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> loadNotifications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiClient.getNotifications(page: 1);
      _notifications = result.notifications;
      _pagination = result.pagination;

      // Mark all notifications as read after loading
      if (_notifications.isNotEmpty) {
        _apiClient.markAllNotificationsRead();
        // Update local state to show as read
        _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      }
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = (_pagination?.currentPage ?? 0) + 1;
      final result = await _apiClient.getNotifications(page: nextPage);
      _notifications.addAll(result.notifications);
      _pagination = result.pagination;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadNotifications();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
