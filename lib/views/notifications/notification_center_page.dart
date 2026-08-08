import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/route_names.dart';
import '../../models/notification_delivery.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/notification_viewmodel.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  String? _loadedParentId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = context.watch<AuthViewModel>().parent;
    if (parent != null && _loadedParentId != parent.id) {
      _loadedParentId = parent.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notifications = context.read<NotificationViewModel>();
        notifications.load(parent.id);
        notifications.refreshPermission();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final parent = context.watch<AuthViewModel>().parent;
    final notifications = context.watch<NotificationViewModel>();

    if (parent == null) {
      return const Scaffold(body: Center(child: Text('Parent not signed in.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notifications.unreadCount > 0)
            TextButton(
              onPressed: () => context
                  .read<NotificationViewModel>()
                  .markAllRead(parent.id),
              child: const Text('Mark all read'),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: notifications.isLoading
                ? null
                : () => context.read<NotificationViewModel>().load(parent.id),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              context.read<NotificationViewModel>().load(parent.id),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _NotificationsHeader(unread: notifications.unreadCount),
              const SizedBox(height: 14),
              if (!notifications.permissionGranted) ...[
                const _PermissionCard(),
                const SizedBox(height: 14),
              ],
              if (notifications.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (notifications.deliveries.isEmpty)
                const _EmptyNotifications()
              else
                for (final delivery in notifications.deliveries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _NotificationCard(
                      delivery: delivery,
                      onRead: () =>
                          context.read<NotificationViewModel>().markRead(
                                parentId: parent.id,
                                deliveryId: delivery.id,
                              ),
                      onDelete: () =>
                          context.read<NotificationViewModel>().delete(
                                parentId: parent.id,
                                deliveryId: delivery.id,
                              ),
                    ),
                  ),
              if (notifications.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  notifications.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context)
                    .pushNamed(RouteNames.parentReminders),
                icon: const Icon(Icons.edit_notifications_outlined),
                label: const Text('Manage reminder schedules'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({required this.unread});

  final int unread;

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
            child: const Icon(Icons.notifications_rounded,
                color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notification centre',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  unread == 0 ? 'You are all caught up' : '$unread unread',
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

/// Shown when the OS has not granted permission — without it every reminder is
/// saved and scheduled but silent, which looks like a bug from the outside.
class _PermissionCard extends StatelessWidget {
  const _PermissionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lemon.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.honey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_off_rounded, color: AppColors.coral),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This phone is not showing notifications yet',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Reminders are saved, but nothing will pop up until you allow '
            'notifications.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    final notifications = context.read<NotificationViewModel>();
                    final granted = await notifications.requestPermission();
                    if (granted) await notifications.sendTestNotification();
                  },
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Allow'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.lilac.withValues(alpha: 0.58)),
      ),
      child: const Column(
        children: [
          Icon(Icons.mark_email_read_outlined,
              size: 36, color: AppColors.violet),
          SizedBox(height: 10),
          Text(
            'Nothing here yet',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 4),
          Text(
            'Reminders you set will appear here after they go off.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.delivery,
    required this.onRead,
    required this.onDelete,
  });

  final NotificationDelivery delivery;
  final VoidCallback onRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final unread = delivery.status != NotificationDeliveryStatus.read;

    return Dismissible(
      key: ValueKey(delivery.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.coral,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Material(
        color: unread ? AppColors.lavender : AppColors.panel,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: unread ? onRead : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: unread
                    ? AppColors.lilac
                    : AppColors.line,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: unread ? AppColors.honey : AppColors.mint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    delivery.type == NotificationDeliveryType.learningReminder
                        ? Icons.notifications_active_rounded
                        : Icons.insights_rounded,
                    color: unread ? AppColors.ink : AppColors.forest,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        delivery.title,
                        style: TextStyle(
                          fontWeight:
                              unread ? FontWeight.w900 : FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(delivery.body),
                      const SizedBox(height: 6),
                      Text(
                        _formatWhen(delivery.deliveredAt ??
                            delivery.scheduledFor),
                        style: TextStyle(
                          color: AppColors.ink.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.coral,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatWhen(DateTime when) {
    final now = DateTime.now();
    final difference = now.difference(when);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} h ago';
    if (difference.inDays < 7) return '${difference.inDays} d ago';

    final month = when.month.toString().padLeft(2, '0');
    final day = when.day.toString().padLeft(2, '0');
    return '$day/$month/${when.year}';
  }
}
