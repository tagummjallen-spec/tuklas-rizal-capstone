import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/notification_state.dart';
import '../constants/app_constants.dart';
import 'ai_guide_button.dart';

/// The one green header used by every main shell tab (Home, Explore, Events,
/// Saved).
///
/// Height, padding and structure are fixed: a 38px utility row (brand mark,
/// search, AI Guide, notifications) and a 56px bottom slot. Each tab supplies
/// only [bottomRow], so switching tabs never changes the header's height or
/// visual rhythm.
class TuklasMainHeader extends ConsumerWidget {
  static const Color _gold = Color(0xFFFFC800);
  static const Color _forest = Color(0xFF033300);

  static const double _topRowHeight = 38;
  static const double _bottomRowHeight = 58;

  /// Total header height excluding the status-bar inset: padding (8 + 14),
  /// utility row (38), gap (10) and the fixed bottom row (58).
  static const double height = 128;

  /// Content of the fixed-height bottom row. Use [TuklasHeaderHeading] for a
  /// title + subtitle, or [TuklasMunicipalitySelector] on Home.
  final Widget bottomRow;

  /// Focuses the page's own search field. Falls back to Explore, which owns a
  /// search field, when the tab has none (Saved).
  final VoidCallback? onSearch;

  const TuklasMainHeader({
    super.key,
    required this.bottomRow,
    this.onSearch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(appNotificationsProvider);
    final unread = ref
        .watch(notificationsControllerProvider)
        .unreadCount(notifications);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF022600), Color(0xFF075A12)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          // 20px left inset and 14px below the bottom row give the section
          // heading ("Saved Collection") room so its glyphs never clip.
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: _topRowHeight,
                child: Row(
                  children: [
                    const Expanded(child: _BrandMark()),
                    _HeaderIconButton(
                      tooltip: 'Search events and places',
                      icon: Icons.search,
                      onPressed: onSearch ?? () => context.go('/explore'),
                    ),
                    const AiGuideButton(),
                    _NotificationBell(unread: unread),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: _bottomRowHeight,
                width: double.infinity,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: bottomRow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gold emblem + TuklasRizal / Province of Rizal wordmark.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: TuklasMainHeader._gold,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.travel_explore,
            color: TuklasMainHeader._forest,
            size: 20,
          ),
        ),
        const SizedBox(width: 8),
        const Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppConstants.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                'Province of Rizal',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      icon: Icon(icon, color: Colors.white, size: 21),
    );
  }
}

/// Bell icon with the live unread badge from the Notification Inbox.
class _NotificationBell extends StatelessWidget {
  final int unread;

  const _NotificationBell({required this.unread});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => context.push('/notifications'),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        backgroundColor: TuklasMainHeader._gold,
        textColor: TuklasMainHeader._forest,
        child: const Icon(
          Icons.notifications_outlined,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

/// Title + subtitle used by the Explore, Events and Saved bottom rows.
class TuklasHeaderHeading extends StatelessWidget {
  final String title;
  final String? subtitle;

  const TuklasHeaderHeading({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.left,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18.5,
            fontWeight: FontWeight.w800,
            height: 1.3,
            letterSpacing: -0.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}

/// Home's bottom row: the interactive `All 14 Towns` selector plus tagline.
class TuklasMunicipalitySelector extends StatelessWidget {
  final String label;
  final bool hasSelection;
  final VoidCallback onTap;

  const TuklasMunicipalitySelector({
    super.key,
    required this.label,
    required this.hasSelection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_city,
                    color: TuklasMainHeader._gold,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (hasSelection)
                    const Text(
                      ' · Rizal',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: TuklasMainHeader._gold,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Discover events & heritage across Rizal',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11.5,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
