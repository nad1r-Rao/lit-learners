import '../models/notification_delivery.dart';
import '../services/remote/notification_delivery_remote_data_source.dart';
import 'learning_reminder_repository.dart';

abstract class NotificationDeliveryRepository {
  Future<List<NotificationDelivery>> deliverDueReminders({
    required String parentId,
    required DateTime at,
  });

  Future<List<NotificationDelivery>> getDeliveries(String parentId);

  Future<void> markRead({
    required String parentId,
    required String deliveryId,
    required DateTime readAt,
  });

  Future<void> deleteDelivery({
    required String parentId,
    required String deliveryId,
  });
}

class ReminderNotificationDeliveryRepository
    implements NotificationDeliveryRepository {
  ReminderNotificationDeliveryRepository({
    required LearningReminderRepository reminderRepository,
    required NotificationDeliveryRemoteDataSource remoteDataSource,
  })  : _reminderRepository = reminderRepository,
        _remoteDataSource = remoteDataSource;

  final LearningReminderRepository _reminderRepository;
  final NotificationDeliveryRemoteDataSource _remoteDataSource;

  @override
  Future<void> deleteDelivery({
    required String parentId,
    required String deliveryId,
  }) {
    return _remoteDataSource.deleteDelivery(
      parentId: parentId,
      deliveryId: deliveryId,
    );
  }

  @override
  Future<List<NotificationDelivery>> deliverDueReminders({
    required String parentId,
    required DateTime at,
  }) async {
    // Every occurrence up to [at] counts, not only the one landing on this
    // exact minute: the app is usually closed when a reminder fires, so the
    // notification centre has to catch up the next time it opens.
    final reminders = await _reminderRepository.getReminders(parentId);
    final deliveries = <NotificationDelivery>[];

    for (final reminder in reminders) {
      final occurrence = reminder.lastOccurrenceOnOrBefore(at);
      if (occurrence == null) continue;

      final triggeredAt = reminder.lastTriggeredAt;
      if (triggeredAt != null && !triggeredAt.isBefore(occurrence)) continue;

      final delivery = NotificationDelivery(
        id: _deliveryId(reminder.id, occurrence),
        parentId: parentId,
        type: NotificationDeliveryType.learningReminder,
        sourceId: reminder.id,
        title: reminder.title,
        body: 'It is time for a gentle Little Learners session.',
        scheduledFor: occurrence,
        status: NotificationDeliveryStatus.delivered,
        createdAt: DateTime.now(),
        deliveredAt: occurrence,
      );
      deliveries.add(await _remoteDataSource.createDelivery(delivery));
      await _reminderRepository.markTriggered(
        parentId: parentId,
        reminderId: reminder.id,
        triggeredAt: occurrence,
      );
    }

    return deliveries;
  }

  @override
  Future<List<NotificationDelivery>> getDeliveries(String parentId) {
    return _remoteDataSource.getDeliveries(parentId);
  }

  @override
  Future<void> markRead({
    required String parentId,
    required String deliveryId,
    required DateTime readAt,
  }) {
    return _remoteDataSource.markRead(
      parentId: parentId,
      deliveryId: deliveryId,
      readAt: readAt,
    );
  }

  /// Deterministic on purpose: if the same occurrence is ever delivered twice
  /// the second write lands on the same document instead of adding a duplicate
  /// row to the parent's notification list.
  String _deliveryId(String reminderId, DateTime at) {
    return '$reminderId-${at.toIso8601String()}'
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '-');
  }
}
