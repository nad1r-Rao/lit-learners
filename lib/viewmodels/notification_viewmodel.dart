import 'package:flutter/foundation.dart';

import '../models/notification_delivery.dart';
import '../repositories/notification_delivery_repository.dart';
import '../services/notifications/local_notification_service.dart';

/// Backs the in-app notification centre. Opening it also catches up on any
/// reminder that came due while the app was closed, so the list matches what
/// the phone showed on the lock screen.
class NotificationViewModel extends ChangeNotifier {
  NotificationViewModel({
    required NotificationDeliveryRepository repository,
    required LocalNotificationService localNotifications,
  })  : _repository = repository,
        _localNotifications = localNotifications;

  final NotificationDeliveryRepository _repository;
  final LocalNotificationService _localNotifications;

  List<NotificationDelivery> _deliveries = [];
  bool _isLoading = false;
  bool _permissionGranted = false;
  String? _errorMessage;

  List<NotificationDelivery> get deliveries => List.unmodifiable(_deliveries);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Whether the OS will actually show anything. False means the reminders are
  /// saved but silent, which is worth telling the parent about.
  bool get permissionGranted => _permissionGranted;

  int get unreadCount => _deliveries
      .where((d) => d.status != NotificationDeliveryStatus.read)
      .length;

  Future<void> load(String parentId, {DateTime? at}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deliverDueReminders(
        parentId: parentId,
        at: at ?? DateTime.now(),
      );
      _deliveries = await _repository.getDeliveries(parentId);
    } catch (error) {
      _errorMessage = 'Notifications could not load. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshPermission() async {
    _permissionGranted = await _localNotifications.hasPermission();
    notifyListeners();
  }

  Future<bool> requestPermission() async {
    _permissionGranted = await _localNotifications.requestPermission();
    notifyListeners();
    return _permissionGranted;
  }

  Future<void> markRead({
    required String parentId,
    required String deliveryId,
  }) async {
    final readAt = DateTime.now();
    try {
      await _repository.markRead(
        parentId: parentId,
        deliveryId: deliveryId,
        readAt: readAt,
      );
    } catch (error) {
      _errorMessage = 'That notification could not be updated.';
      notifyListeners();
      return;
    }

    _deliveries = [
      for (final delivery in _deliveries)
        if (delivery.id == deliveryId)
          delivery.copyWith(
            status: NotificationDeliveryStatus.read,
            readAt: readAt,
          )
        else
          delivery,
    ];
    notifyListeners();
  }

  Future<void> markAllRead(String parentId) async {
    final unread = _deliveries
        .where((d) => d.status != NotificationDeliveryStatus.read)
        .toList();
    for (final delivery in unread) {
      await markRead(parentId: parentId, deliveryId: delivery.id);
    }
  }

  Future<void> delete({
    required String parentId,
    required String deliveryId,
  }) async {
    try {
      await _repository.deleteDelivery(
        parentId: parentId,
        deliveryId: deliveryId,
      );
    } catch (error) {
      _errorMessage = 'That notification could not be removed.';
      notifyListeners();
      return;
    }

    _deliveries =
        _deliveries.where((delivery) => delivery.id != deliveryId).toList();
    notifyListeners();
  }

  /// Posts a notification immediately so a parent can confirm the phone is set
  /// up, without waiting for the next scheduled slot.
  Future<void> sendTestNotification() async {
    await _localNotifications.showNow(
      title: 'Little Learners',
      body: 'Notifications are switched on. Reminders will look like this.',
      payload: 'test',
    );
  }
}
