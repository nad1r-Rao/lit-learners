import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/learning_reminder.dart';
import 'package:little_learners/models/notification_delivery.dart';
import 'package:little_learners/repositories/learning_reminder_repository.dart';
import 'package:little_learners/repositories/notification_delivery_repository.dart';
import 'package:little_learners/services/notifications/local_notification_service.dart';
import 'package:little_learners/services/remote/notification_delivery_remote_data_source.dart';
import 'package:little_learners/viewmodels/learning_reminder_viewmodel.dart';
import 'package:little_learners/viewmodels/notification_viewmodel.dart';

void main() {
  group('reminder scheduling', () {
    test('a saved reminder is handed to the device scheduler', () async {
      final notifications = NoopLocalNotificationService();
      final viewModel = LearningReminderViewModel(
        InMemoryLearningReminderRepository(),
        localNotifications: notifications,
      );

      await viewModel.createReminder(
        parentId: 'parent-1',
        title: 'Story time',
        hour: 18,
        minute: 30,
        weekdays: const [1, 3, 5],
      );

      expect(notifications.scheduledReminders, hasLength(1));
      expect(notifications.scheduledReminders.single.title, 'Story time');
    });

    test('switching a reminder off unschedules it', () async {
      final notifications = NoopLocalNotificationService();
      final repository = InMemoryLearningReminderRepository();
      final viewModel = LearningReminderViewModel(
        repository,
        localNotifications: notifications,
      );
      await viewModel.createReminder(
        parentId: 'parent-1',
        title: 'Story time',
        hour: 18,
        minute: 30,
        weekdays: const [1],
      );

      await viewModel.toggleReminder(viewModel.reminders.single, false);

      expect(notifications.scheduledReminders, isEmpty);
    });

    test('deleting a reminder unschedules it', () async {
      final notifications = NoopLocalNotificationService();
      final viewModel = LearningReminderViewModel(
        InMemoryLearningReminderRepository(),
        localNotifications: notifications,
      );
      await viewModel.createReminder(
        parentId: 'parent-1',
        title: 'Story time',
        hour: 18,
        minute: 30,
        weekdays: const [1],
      );

      await viewModel.deleteReminder(
        parentId: 'parent-1',
        reminderId: viewModel.reminders.single.id,
      );

      expect(notifications.scheduledReminders, isEmpty);
    });

    test('every reminder-and-weekday pair gets its own OS notification id', () {
      final ids = <int>{};
      for (final reminderId in ['reminder-a', 'reminder-b', 'reminder-c']) {
        for (var weekday = 1; weekday <= 7; weekday++) {
          ids.add(notificationIdFor(reminderId, weekday));
        }
      }

      expect(ids, hasLength(21));
      // Android and iOS both take a 32-bit signed id.
      expect(ids.every((id) => id > 0 && id <= 2147483647), isTrue);
    });
  });

  group('missed reminder catch-up', () {
    test('lastOccurrenceOnOrBefore finds the slot that already passed', () {
      final reminder = _reminder(hour: 18, minute: 0, weekdays: const [1, 3]);

      // Wednesday 2026-01-07, three hours after the 18:00 slot.
      final occurrence = reminder.lastOccurrenceOnOrBefore(
        DateTime.utc(2026, 1, 7, 21),
      );

      expect(occurrence, DateTime.utc(2026, 1, 7, 18));
    });

    test('lastOccurrenceOnOrBefore ignores a disabled reminder', () {
      final reminder = _reminder(
        hour: 18,
        minute: 0,
        weekdays: const [1, 3],
        enabled: false,
      );

      expect(
        reminder.lastOccurrenceOnOrBefore(DateTime.utc(2026, 1, 7, 21)),
        isNull,
      );
    });

    test('opening the centre delivers a reminder that fired while closed',
        () async {
      final reminderRepository = InMemoryLearningReminderRepository();
      final repository = ReminderNotificationDeliveryRepository(
        reminderRepository: reminderRepository,
        remoteDataSource: InMemoryNotificationDeliveryRemoteDataSource(),
      );
      final viewModel = NotificationViewModel(
        repository: repository,
        localNotifications: NoopLocalNotificationService(),
      );
      await reminderRepository.createReminder(
        parentId: 'parent-1',
        title: 'Practice math',
        hour: 18,
        minute: 0,
        weekdays: const [3],
        enabled: true,
      );

      // Opened at 21:00, three hours after the notification actually fired.
      await viewModel.load('parent-1', at: DateTime.utc(2026, 1, 7, 21));

      expect(viewModel.deliveries, hasLength(1));
      expect(viewModel.deliveries.single.title, 'Practice math');
      expect(viewModel.unreadCount, 1);
      expect(
        viewModel.deliveries.single.deliveredAt,
        DateTime.utc(2026, 1, 7, 18),
      );
    });

    test('a second visit does not duplicate the same occurrence', () async {
      final reminderRepository = InMemoryLearningReminderRepository();
      final repository = ReminderNotificationDeliveryRepository(
        reminderRepository: reminderRepository,
        remoteDataSource: InMemoryNotificationDeliveryRemoteDataSource(),
      );
      final viewModel = NotificationViewModel(
        repository: repository,
        localNotifications: NoopLocalNotificationService(),
      );
      await reminderRepository.createReminder(
        parentId: 'parent-1',
        title: 'Practice math',
        hour: 18,
        minute: 0,
        weekdays: const [3],
        enabled: true,
      );

      await viewModel.load('parent-1', at: DateTime.utc(2026, 1, 7, 21));
      await viewModel.load('parent-1', at: DateTime.utc(2026, 1, 7, 22));

      expect(viewModel.deliveries, hasLength(1));
    });

    test('marking read clears the unread badge', () async {
      final reminderRepository = InMemoryLearningReminderRepository();
      final repository = ReminderNotificationDeliveryRepository(
        reminderRepository: reminderRepository,
        remoteDataSource: InMemoryNotificationDeliveryRemoteDataSource(),
      );
      final viewModel = NotificationViewModel(
        repository: repository,
        localNotifications: NoopLocalNotificationService(),
      );
      await reminderRepository.createReminder(
        parentId: 'parent-1',
        title: 'Practice math',
        hour: 18,
        minute: 0,
        weekdays: const [3],
        enabled: true,
      );
      await viewModel.load('parent-1', at: DateTime.utc(2026, 1, 7, 21));

      await viewModel.markAllRead('parent-1');

      expect(viewModel.unreadCount, 0);
      expect(
        viewModel.deliveries.single.status,
        NotificationDeliveryStatus.read,
      );
    });
  });
}

LearningReminder _reminder({
  required int hour,
  required int minute,
  required List<int> weekdays,
  bool enabled = true,
}) {
  return LearningReminder(
    id: 'reminder-1',
    parentId: 'parent-1',
    title: 'Learning time',
    hour: hour,
    minute: minute,
    weekdays: weekdays,
    enabled: enabled,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}
