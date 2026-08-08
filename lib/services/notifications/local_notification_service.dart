import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../models/learning_reminder.dart';

/// The device-level half of reminders: the OS alarms that fire even when the
/// app is closed. Everything the app knows *about* a notification still lives
/// in [NotificationDeliveryRepository]; this only makes the phone buzz.
abstract class LocalNotificationService {
  /// Sets up channels and the timezone database. Safe to call more than once.
  Future<void> initialize();

  /// Asks the OS for permission. Returns false when the parent declines or the
  /// platform does not support notifications.
  Future<bool> requestPermission();

  /// True once the OS has granted permission.
  Future<bool> hasPermission();

  /// Makes the OS schedule exactly the reminders in [reminders] for this
  /// parent and nothing else: disabled, deleted and edited ones are cleared
  /// first, so this can be called after any change.
  Future<void> syncReminders(List<LearningReminder> reminders);

  /// Drops every alarm belonging to [reminderId].
  Future<void> cancelReminder(String reminderId);

  /// Clears every alarm this app scheduled, e.g. on sign-out.
  Future<void> cancelAll();

  /// Posts a notification right now — used by "Send a test notification".
  Future<void> showNow({
    required String title,
    required String body,
    String? payload,
  });

  /// Payloads of notifications the parent tapped.
  Stream<String> get selections;
}

/// Stand-in for tests and for `USE_FIREBASE=false` runs on desktop, where the
/// plugin has no implementation.
class NoopLocalNotificationService implements LocalNotificationService {
  final _selections = StreamController<String>.broadcast();

  /// Every reminder the last [syncReminders] call asked for, so tests can
  /// assert on scheduling without a platform channel.
  List<LearningReminder> scheduledReminders = const [];

  @override
  Future<void> cancelAll() async => scheduledReminders = const [];

  @override
  Future<void> cancelReminder(String reminderId) async {
    scheduledReminders = scheduledReminders
        .where((reminder) => reminder.id != reminderId)
        .toList();
  }

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Stream<String> get selections => _selections.stream;

  @override
  Future<void> showNow({
    required String title,
    required String body,
    String? payload,
  }) async {}

  @override
  Future<void> syncReminders(List<LearningReminder> reminders) async {
    scheduledReminders = List.unmodifiable(
      reminders.where((reminder) => reminder.enabled),
    );
  }
}

class FlutterLocalNotificationService implements LocalNotificationService {
  FlutterLocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const channelId = 'learning_reminders';
  static const _channelName = 'Learning reminders';
  static const _channelDescription =
      'Gentle nudges when it is time for a Little Learners session.';

  /// Immediate notifications get ids above every scheduled one, which are
  /// derived from reminder ids and capped well below this.
  static const _instantIdBase = 2000000000;

  final FlutterLocalNotificationsPlugin _plugin;
  final _selections = StreamController<String>.broadcast();
  bool _initialized = false;
  int _instantIdOffset = 0;

  @override
  Stream<String> get selections => _selections.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (error) {
      // UTC is a poor guess but better than crashing on launch; reminders
      // would only be scheduled at the wrong hour, not lost.
      debugPrint('Could not resolve the local timezone: $error');
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Asked for explicitly in `requestPermission`, next to an
          // explanation, rather than the instant the app first opens.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _selections.add(payload);
        }
      },
    );

    await _androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();

    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _androidPlugin?.requestNotificationsPermission() ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  @override
  Future<bool> hasPermission() async {
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _androidPlugin?.areNotificationsEnabled() ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Read-only on purpose: calling requestPermissions here would pop the
      // system prompt the moment a screen loads, with no explanation first.
      final options = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return options?.isEnabled ?? false;
    }
    return false;
  }

  @override
  Future<void> syncReminders(List<LearningReminder> reminders) async {
    await initialize();

    // Rescheduling from scratch is cheaper to reason about than diffing, and
    // the list is a handful of entries.
    await _plugin.cancelAll();

    for (final reminder in reminders) {
      if (!reminder.enabled) continue;
      for (final weekday in reminder.weekdays) {
        await _plugin.zonedSchedule(
          id: notificationIdFor(reminder.id, weekday),
          title: reminder.title,
          body: 'It is time for a gentle Little Learners session.',
          scheduledDate: _nextInstanceOf(weekday, reminder.hour,
              reminder.minute),
          notificationDetails: _details,
          // Inexact keeps this off Android 12's SCHEDULE_EXACT_ALARM
          // permission, which is refused for anything but alarms and
          // calendars. A learning nudge does not need to-the-second timing.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'reminder:${reminder.id}',
        );
      }
    }
  }

  @override
  Future<void> cancelReminder(String reminderId) async {
    await initialize();
    for (var weekday = 1; weekday <= 7; weekday++) {
      await _plugin.cancel(id: notificationIdFor(reminderId, weekday));
    }
  }

  @override
  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  @override
  Future<void> showNow({
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();
    await _plugin.show(
      id: _instantIdBase + (_instantIdOffset++ % 1000),
      title: title,
      body: body,
      notificationDetails: _details,
      payload: payload,
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin {
    return _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  tz.TZDateTime _nextInstanceOf(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

/// A stable 31-bit id per reminder-and-weekday, which is what both Android and
/// iOS want. The reminder half is masked to 28 bits so seven weekdays always
/// fit under `int32.max`.
@visibleForTesting
int notificationIdFor(String reminderId, int weekday) {
  final base = reminderId.hashCode & 0xFFFFFFF;
  return base * 8 + (weekday % 8);
}
