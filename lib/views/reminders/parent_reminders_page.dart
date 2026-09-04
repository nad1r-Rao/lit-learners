import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/route_names.dart';
import '../../models/koala_guide_message.dart';
import '../../models/learning_reminder.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/learning_reminder_viewmodel.dart';
import '../../viewmodels/notification_viewmodel.dart';
import '../../widgets/koala_guide.dart';
import '../../widgets/play/play.dart';

class ParentRemindersPage extends StatefulWidget {
  const ParentRemindersPage({super.key});

  @override
  State<ParentRemindersPage> createState() => _ParentRemindersPageState();
}

class _ParentRemindersPageState extends State<ParentRemindersPage> {
  @override
  Widget build(BuildContext context) {
    final parent = context.watch<AuthViewModel>().parent;
    final reminders = context.watch<LearningReminderViewModel>();

    if (parent == null) {
      return const Scaffold(body: Center(child: Text('Parent not signed in.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Reminders'),
        actions: [
          IconButton(
            tooltip: 'Refresh reminders',
            onPressed: reminders.isLoading
                ? null
                : () => context
                    .read<LearningReminderViewModel>()
                    .loadReminders(parent.id),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: const SafeArea(
        child: LearningRemindersPanel(),
      ),
    );
  }
}

class LearningRemindersPanel extends StatefulWidget {
  const LearningRemindersPanel({
    this.showGuide = true,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final bool showGuide;
  final EdgeInsets padding;

  @override
  State<LearningRemindersPanel> createState() => _LearningRemindersPanelState();
}

class _LearningRemindersPanelState extends State<LearningRemindersPanel> {
  final _titleController = TextEditingController(text: 'Learning time');
  final Set<int> _selectedWeekdays = {1, 2, 3, 4, 5};
  TimeOfDay _selectedTime = const TimeOfDay(hour: 18, minute: 0);
  String? _loadedParentId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = context.watch<AuthViewModel>().parent;
    if (parent != null && _loadedParentId != parent.id) {
      _loadedParentId = parent.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<LearningReminderViewModel>().loadReminders(parent.id);
        context.read<NotificationViewModel>().refreshPermission();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parent = context.watch<AuthViewModel>().parent;
    final reminders = context.watch<LearningReminderViewModel>();

    if (parent == null) {
      return const Center(child: Text('Parent not signed in.'));
    }

    return ListView(
      padding: widget.padding,
      children: [
        _RemindersHeader(count: reminders.reminders.length),
        const SizedBox(height: 14),
        const _DeliveryStatusCard(),
        const SizedBox(height: 14),
        if (widget.showGuide) ...[
          const ContextualKoalaGuide(
            trigger: KoalaGuideTrigger.reminderSetup,
            audience: KoalaGuideAudience.parent,
            fallbackMessage: 'Set gentle learning reminders. These '
                'preferences sync to the backend and can later drive push '
                'notifications.',
          ),
          const SizedBox(height: 16),
        ],
        if (reminders.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (reminders.reminders.isEmpty)
          const _EmptyReminderCard()
        else
          for (final reminder in reminders.reminders)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReminderCard(reminder: reminder),
            ),
        if (reminders.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            reminders.errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (reminders.infoMessage != null) ...[
          const SizedBox(height: 8),
          Text(reminders.infoMessage!),
        ],
        const SizedBox(height: 16),
        _CreateReminderCard(
          titleController: _titleController,
          selectedTime: _selectedTime,
          selectedWeekdays: _selectedWeekdays,
          onPickTime: () => _pickTime(context),
          onToggleDay: _toggleDay,
          onSubmit: () => _createReminder(context, parent.id),
        ),
      ],
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked == null) return;
    setState(() => _selectedTime = picked);
  }

  void _toggleDay(int weekday, bool selected) {
    setState(() {
      if (selected) {
        _selectedWeekdays.add(weekday);
      } else {
        _selectedWeekdays.remove(weekday);
      }
    });
  }

  Future<void> _createReminder(BuildContext context, String parentId) async {
    final created =
        await context.read<LearningReminderViewModel>().createReminder(
              parentId: parentId,
              title: _titleController.text,
              hour: _selectedTime.hour,
              minute: _selectedTime.minute,
              weekdays: _selectedWeekdays.toList()..sort(),
            );
    if (!created || !context.mounted) return;

    _titleController.text = 'Learning time';
  }
}

/// Answers the question a parent actually has about this screen: will the
/// phone really buzz? A saved schedule with notifications switched off at the
/// OS level looks identical to a working one otherwise.
class _DeliveryStatusCard extends StatelessWidget {
  const _DeliveryStatusCard();

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<NotificationViewModel>();
    final granted = notifications.permissionGranted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: granted
            ? AppColors.mint
            : AppColors.lemon.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: granted ? AppColors.leaf : AppColors.honey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                granted
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
                color: granted ? AppColors.forest : AppColors.coral,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  granted
                      ? 'This phone will show your reminders'
                      : 'Notifications are switched off on this phone',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            granted
                ? 'Reminders are scheduled on the device, so they arrive even '
                    'when the app is closed.'
                : 'Schedules below are saved, but nothing will pop up until '
                    'you allow notifications.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!granted)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final model = context.read<NotificationViewModel>();
                      final allowed = await model.requestPermission();
                      if (allowed) await model.sendTestNotification();
                    },
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Allow notifications'),
                  ),
                )
              else
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context
                        .read<NotificationViewModel>()
                        .sendTestNotification(),
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Send a test'),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed(
                    RouteNames.parentNotifications,
                  ),
                  icon: const Icon(Icons.inbox_outlined),
                  label: const Text('History'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyReminderCard extends StatelessWidget {
  const _EmptyReminderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.lilac.withValues(alpha: 0.58)),
      ),
      child: const Row(
        children: [
          Icon(Icons.notifications_none, color: AppColors.violet),
          SizedBox(width: 12),
          Expanded(child: Text('No learning reminders yet.')),
        ],
      ),
    );
  }
}

class _RemindersHeader extends StatelessWidget {
  const _RemindersHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.grape, AppColors.violet],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.honey,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Learning reminders',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  count == 1 ? '1 active schedule' : '$count saved schedules',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderIconBox extends StatelessWidget {
  const _ReminderIconBox({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: enabled ? AppColors.honey : AppColors.lavender,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        enabled ? Icons.notifications_active : Icons.notifications_off,
        color: enabled ? AppColors.ink : AppColors.violet,
      ),
    );
  }
}

class _ReminderShell extends StatelessWidget {
  const _ReminderShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.lilac.withValues(alpha: 0.48)),
        boxShadow: [
          BoxShadow(
            color: AppColors.grape.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ReminderTitleField extends StatelessWidget {
  const _ReminderTitleField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cloud,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Title',
          prefixIcon: Icon(Icons.edit_notifications),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

class _ReminderTimeButton extends StatelessWidget {
  const _ReminderTimeButton({
    required this.selectedTime,
    required this.onPressed,
  });

  final TimeOfDay selectedTime;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.lemon.withValues(alpha: 0.52),
        side: BorderSide(color: AppColors.honey.withValues(alpha: 0.8)),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.schedule, color: AppColors.coral),
      label: Text(selectedTime.format(context)),
    );
  }
}

class _ReminderWeekdayChip extends StatelessWidget {
  const _ReminderWeekdayChip({
    required this.option,
    required this.selected,
    required this.onSelected,
  });

  final _WeekdayOption option;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(option.label),
      selected: selected,
      selectedColor: AppColors.honey,
      checkmarkColor: AppColors.coral,
      labelStyle: TextStyle(
        color: selected ? AppColors.coral : AppColors.ink,
        fontWeight: FontWeight.w900,
      ),
      onSelected: onSelected,
    );
  }
}

class _CreateReminderHeader extends StatelessWidget {
  const _CreateReminderHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.coral.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.add_alert, color: AppColors.coral),
        ),
        const SizedBox(width: 10),
        Text(
          'Add reminder',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _ReminderStatusPill extends StatelessWidget {
  const _ReminderStatusPill({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.honey.withValues(alpha: 0.34)
            : AppColors.line.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        enabled ? 'On' : 'Off',
        style: TextStyle(
          color: enabled ? AppColors.coral : AppColors.ink,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReminderDetails extends StatelessWidget {
  const _ReminderDetails({required this.reminder});

  final LearningReminder reminder;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  reminder.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              _ReminderStatusPill(enabled: reminder.enabled),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${_formatReminderTime(reminder.hour, reminder.minute)} - '
            '${_weekdaySummary(reminder.weekdays)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.ink.withValues(alpha: 0.62),
                ),
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder});

  final LearningReminder reminder;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<LearningReminderViewModel>();

    return _ReminderShell(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _ReminderIconBox(enabled: reminder.enabled),
            const SizedBox(width: 12),
            _ReminderDetails(reminder: reminder),
            Switch(
              value: reminder.enabled,
              activeThumbColor: AppColors.honey,
              activeTrackColor: AppColors.violet,
              onChanged: (enabled) {
                viewModel.toggleReminder(reminder, enabled);
              },
            ),
            IconButton(
              tooltip: 'Delete reminder',
              onPressed: () {
                viewModel.deleteReminder(
                  parentId: reminder.parentId,
                  reminderId: reminder.id,
                );
              },
              icon: const Icon(Icons.delete_outline, color: AppColors.coral),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateReminderCard extends StatelessWidget {
  const _CreateReminderCard({
    required this.titleController,
    required this.selectedTime,
    required this.selectedWeekdays,
    required this.onPickTime,
    required this.onToggleDay,
    required this.onSubmit,
  });

  final TextEditingController titleController;
  final TimeOfDay selectedTime;
  final Set<int> selectedWeekdays;
  final VoidCallback onPickTime;
  final void Function(int weekday, bool selected) onToggleDay;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _ReminderShell(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CreateReminderHeader(),
            const SizedBox(height: 12),
            _ReminderTitleField(controller: titleController),
            const SizedBox(height: 12),
            _ReminderTimeButton(
              selectedTime: selectedTime,
              onPressed: onPickTime,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in _weekdayOptions)
                  _ReminderWeekdayChip(
                    option: option,
                    selected: selectedWeekdays.contains(option.weekday),
                    onSelected: (selected) {
                      onToggleDay(option.weekday, selected);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            PlayButton(
              icon: Icons.add_alert,
              label: 'Save reminder',
              onPressed: onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayOption {
  const _WeekdayOption(this.weekday, this.label);

  final int weekday;
  final String label;
}

const _weekdayOptions = [
  _WeekdayOption(1, 'Mon'),
  _WeekdayOption(2, 'Tue'),
  _WeekdayOption(3, 'Wed'),
  _WeekdayOption(4, 'Thu'),
  _WeekdayOption(5, 'Fri'),
  _WeekdayOption(6, 'Sat'),
  _WeekdayOption(7, 'Sun'),
];

String _formatReminderTime(int hour, int minute) {
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
}

String _weekdaySummary(List<int> weekdays) {
  if (weekdays.length == 7) return 'Every day';
  if (_setsEqual(weekdays, const [1, 2, 3, 4, 5])) return 'Weekdays';
  if (_setsEqual(weekdays, const [6, 7])) return 'Weekends';

  return weekdays.map((weekday) {
    return _weekdayOptions
        .firstWhere((option) => option.weekday == weekday)
        .label;
  }).join(', ');
}

bool _setsEqual(List<int> values, List<int> expected) {
  final valueSet = values.toSet();
  final expectedSet = expected.toSet();
  return valueSet.length == expectedSet.length &&
      valueSet.containsAll(expectedSet);
}
