import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_motion.dart';
import '../notification_state.dart';

/// Notification Inbox — live approved events + LGU civic broadcasts.
///
/// Everything on this screen comes from the Supabase `events` stream
/// (`status = 'approved'`); unread badges are device-local so a guest can use
/// the inbox without an account.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  static const Color forest = Color(0xFF033300);
  static const Color gold = Color(0xFFFFC800);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(appNotificationsProvider);
    final controller = ref.watch(notificationsControllerProvider);
    final loading =
        ref.watch(allApprovedEventsProvider).isLoading && notifications.isEmpty;
    final unread = controller.unreadCount(notifications);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            color: forest,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 12, 14),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      tooltip: 'Back',
                      onPressed: () =>
                          context.canPop() ? context.pop() : context.go('/'),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notifications',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            unread == 0
                                ? 'You are all caught up'
                                : '$unread unread announcement'
                                      '${unread == 1 ? '' : 's'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (unread > 0)
                      TextButton(
                        onPressed: () => controller.markAllRead(
                          notifications.map((n) => n.id),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: gold,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ShimmerBox(height: 78),
                        SizedBox(height: 12),
                        ShimmerBox(height: 78),
                        SizedBox(height: 12),
                        ShimmerBox(height: 78),
                      ],
                    ),
                  )
                : notifications.isEmpty
                ? _EmptyInbox()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: notifications.length,
                    itemBuilder: (context, i) {
                      final item = notifications[i];
                      return StaggeredFadeIn(
                        key: ValueKey(item.id),
                        index: i,
                        child: _NotificationTile(
                          notification: item,
                          isRead: controller.isRead(item.id),
                          onTap: () {
                            controller.markRead(item.id);
                            context.push('/event/${item.eventId}');
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final bool isRead;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (icon, tint) = switch (notification.kind) {
      AppNotificationKind.civicBroadcast => (
        Icons.campaign_outlined,
        isDark ? const Color(0xFF3A3115) : const Color(0xFFFFE9A3),
      ),
      AppNotificationKind.newEvent => (
        Icons.auto_awesome_outlined,
        isDark ? const Color(0xFF24352C) : const Color(0xFFDCE8DC),
      ),
      AppNotificationKind.upcomingEvent => (
        Icons.event_available_outlined,
        isDark ? const Color(0xFF24352C) : const Color(0xFFE7F0E4),
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isRead
            ? Theme.of(context).cardColor
            : (isDark ? const Color(0xFF232C1D) : const Color(0xFFFFFDF4)),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isRead
                    ? scheme.outline.withValues(alpha: 0.4)
                    : NotificationsPage.gold.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 21,
                    color: isDark
                        ? const Color(0xFFFFC800)
                        : NotificationsPage.forest,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.25,
                                fontWeight: isRead
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 6),
                              decoration: const BoxDecoration(
                                color: NotificationsPage.gold,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _relativeTime(notification.createdAt),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _relativeTime(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(value);
  }
}

class _EmptyInbox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF24352C)
                    : const Color(0xFFE7F0E4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none,
                size: 36,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No announcements yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Newly approved events and Provincial Tourism advisories will '
              'appear here as soon as the LGU publishes them.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => context.go('/explore'),
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: const Text('Explore Rizal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? scheme.primary
                    : const Color(0xFF033300),
                foregroundColor: isDark
                    ? const Color(0xFF06210F)
                    : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
