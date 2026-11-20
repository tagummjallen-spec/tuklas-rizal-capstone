import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/categories.dart';
import '../../../core/constants/municipalities.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/interest_matcher.dart';
import '../../../core/utils/promotion_reason.dart';
import '../../../core/widgets/ai_guide_button.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/event_card.dart';
import '../../../core/widgets/hero_carousel.dart';
import '../../../core/widgets/municipality_chip.dart';
import '../../../core/widgets/section_header.dart';
import '../../../models/event_item.dart';
import '../../../models/municipality.dart';
import '../../../services/lookup_service.dart';
import '../../notifications/notification_state.dart';

/// Home / Discovery Hub — live civic broadcast banner, featured events,
/// "Promote Towns and Events", municipality + barangay + category filters.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const String _allTownsSentinel = '__all_towns__';

  String? _selectedMunicipalityId;
  String? _selectedBarangayName;
  String? _selectedCategoryId;
  String _searchQuery = '';
  final Set<String> _dismissedBroadcasts = {};

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _quickSearchKey = GlobalKey();

  final dateFormat = DateFormat('MMM d, yyyy');

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discovery = ref.watch(discoveryServiceProvider);
    final labels = ref.watch(lookupsProvider).valueOrNull ?? LookupTables.empty;
    final saved = ref.watch(savedPlacesProvider);
    final settings = ref.watch(appSettingsProvider);
    final onboarding = ref.watch(onboardingControllerProvider);

    // Guest interests (welcome flow) or the signed-in user's live
    // `public.user_interests` rows feed the "Recommended for You" boost while
    // Rizal Events Hub Recommendations stay enabled in Settings.
    final recommended = settings.recommendationsEnabled
        ? resolveRecommendations(
            ref.watch(recommendedInterestCategoriesProvider).valueOrNull ??
                onboarding.interests,
            labels,
          )
        : RecommendationInterests.empty;
    bool isRecommendedEvent(EventItem event) => recommended.matches(
      event.categoryId,
      labels.category(event.categoryId),
    );

    final municipalities =
        ref.watch(municipalitiesProvider).valueOrNull ?? const <Municipality>[];
    final barangays = _selectedMunicipalityId != null
        ? RizalBarangays.forMunicipality(_selectedMunicipalityId!)
        : <String>[];
    Municipality? selectedMunicipality;
    for (final municipality in municipalities) {
      if (municipality.id == _selectedMunicipalityId) {
        selectedMunicipality = municipality;
        break;
      }
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          104 + MediaQuery.of(context).padding.top,
        ),
        child: _HomeHeader(
          selectedMunicipality: selectedMunicipality,
          onPickMunicipality: () => _pickMunicipality(municipalities),
          onSearch: _focusQuickSearch,
          onMenuSelected: (value) => _openFromMenu(context, value),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => refreshTravelData(ref),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _QuickSearchBar(
                key: _quickSearchKey,
                controller: _searchCtrl,
                focusNode: _searchFocus,
                query: _searchQuery,
                selectedCategoryId: _selectedCategoryId,
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim()),
                onClearQuery: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
                onCategorySelected: (id) =>
                    setState(() => _selectedCategoryId = id),
              ),
              const SizedBox(height: 16),
              _CivicBroadcastBanner(
                announcements: discovery.promoteTownsAndEvents,
                dismissedIds: _dismissedBroadcasts,
                onDismiss: (id) => setState(() => _dismissedBroadcasts.add(id)),
              ),
              const HeroCarousel(),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => context.go('/assistant'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF033300), Color(0xFF0A5A16)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFC800)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC800),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Color(0xFF033300),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ask the AI Tour Guide',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Festivals, heritage, food & routes — '
                              'answers from verified records',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Color(0xFFFFC800),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                selectedMunicipality == null
                    ? 'Discover Rizal'
                    : 'Discover ${selectedMunicipality.name}',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                selectedMunicipality == null
                    ? 'All 14 municipalities of the Province of Rizal'
                    : '${selectedMunicipality.description}',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),

              // Active municipality / barangay sub-filter
              if (_selectedMunicipalityId != null) ...[
                _ActiveTownFilter(
                  municipality: selectedMunicipality,
                  onClear: () => setState(() {
                    _selectedMunicipalityId = null;
                    _selectedBarangayName = null;
                  }),
                ),
                const SizedBox(height: 10),
                if (barangays.isNotEmpty) ...[
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: barangays.length,
                      itemBuilder: (_, i) {
                        final b = barangays[i];
                        final selected = _selectedBarangayName == b;
                        final scheme = Theme.of(context).colorScheme;
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(b),
                            selected: selected,
                            onSelected: (_) {
                              setState(
                                () =>
                                    _selectedBarangayName = selected ? null : b,
                              );
                            },
                            selectedColor: const Color(0xFFFFC800),
                            backgroundColor: isDark
                                ? const Color(0xFF1A2420)
                                : Colors.white,
                            labelStyle: TextStyle(
                              color: selected
                                  ? const Color(0xFF033300)
                                  : scheme.onSurface,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? const Color(0xFFFFC800)
                                  : scheme.outline.withValues(alpha: 0.6),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],

              // "Promote Towns and Events" — Form I: never "Recommendations"
              SectionHeader(
                title: AppConstants.promoteTownsAndEventsTitle,
                subtitle: AppConstants.promoteTownsAndEventsSubtitle,
              ),
              SizedBox(
                height: 244,
                child: StreamBuilder<List<EventItem>>(
                  stream: discovery.promoteTownsAndEvents,
                  builder: (context, snap) {
                    final events = _applyFilters(snap.data ?? []);
                    // Visit counts start empty until the visits table is wired.
                    // The scorer and the explanation pills share them so the
                    // stated reason always matches the actual ranking.
                    final visitCounts = <String, int>{};
                    final interestIds = _selectedCategoryId != null
                        ? <String>[_selectedCategoryId!]
                        : recommended.categoryIds;
                    bool isInterestMatch(EventItem event) =>
                        event.categoryId != null &&
                        interestIds.contains(event.categoryId);
                    final promoted = discovery.scorePromoteTownsAndEvents(
                      events: events,
                      userInterestCategoryIds: interestIds,
                      municipalityVisitCounts: visitCounts,
                    );
                    if (promoted.isEmpty) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const EventRailSkeleton();
                      }
                      return _EmptyRail(
                        label: _hasFilters
                            ? 'No promoted events match these filters.'
                            : 'No promoted events yet.',
                        onClear: _hasFilters ? _clearFilters : null,
                      );
                    }
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: promoted.length,
                      itemBuilder: (_, i) {
                        final e = promoted[i];
                        return StaggeredFadeIn(
                          key: ValueKey('promoted-${e.id}'),
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: SizedBox(
                              width: 216,
                              child: EventCard(
                                title: e.title,
                                municipality: labels.municipality(
                                  e.municipalityId,
                                ),
                                date: dateFormat.format(e.startDate),
                                category: labels.category(e.categoryId),
                                categoryKey: labels.category(e.categoryId),
                                municipalityKey: labels.municipality(
                                  e.municipalityId,
                                ),
                                imageUrl: e.imageUrl,
                                isPromoted: e.promotedRank > 0,
                                isFeatured: e.isFeatured,
                                isRecommended: isRecommendedEvent(e),
                                promotionReason: eventPromotionReason(
                                  event: e,
                                  isInterestMatch: isInterestMatch(e),
                                  visitCount:
                                      visitCounts[e.municipalityId] ?? 0,
                                ),
                                isSaved: saved.isEventSaved(e.id),
                                onToggleSave: () => _toggleSavedEvent(e),
                                onTap: () => context.push(
                                  '/event/${e.id}?hero=home-promoted-${e.id}',
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Featured Events
              SectionHeader(
                title: AppConstants.featuredEvents,
                onSeeAll: () => context.go('/events'),
              ),
              SizedBox(
                height: 244,
                child: StreamBuilder<List<EventItem>>(
                  stream: discovery.featuredEvents,
                  builder: (context, snap) {
                    final events = _interestFirst(
                      _applyFilters(snap.data ?? []),
                      isRecommendedEvent,
                    );
                    if (events.isEmpty) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const EventRailSkeleton();
                      }
                      return _EmptyRail(
                        label: _hasFilters
                            ? 'No featured events match these filters.'
                            : 'No featured events yet.',
                        onClear: _hasFilters ? _clearFilters : null,
                      );
                    }
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: events.length,
                      itemBuilder: (_, i) {
                        final e = events[i];
                        return StaggeredFadeIn(
                          key: ValueKey('featured-${e.id}'),
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: SizedBox(
                              width: 216,
                              child: EventCard(
                                title: e.title,
                                municipality: labels.municipality(
                                  e.municipalityId,
                                ),
                                date: dateFormat.format(e.startDate),
                                category: labels.category(e.categoryId),
                                categoryKey: labels.category(e.categoryId),
                                municipalityKey: labels.municipality(
                                  e.municipalityId,
                                ),
                                imageUrl: e.imageUrl,
                                isFeatured: true,
                                isRecommended: isRecommendedEvent(e),
                                promotionReason: eventPromotionReason(
                                  event: e,
                                  isInterestMatch: isRecommendedEvent(e),
                                  visitCount: 0,
                                ),
                                isSaved: saved.isEventSaved(e.id),
                                onToggleSave: () => _toggleSavedEvent(e),
                                onTap: () => context.push(
                                  '/event/${e.id}?hero=home-featured-${e.id}',
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasFilters =>
      _selectedMunicipalityId != null ||
      _selectedBarangayName != null ||
      _selectedCategoryId != null ||
      _searchQuery.isNotEmpty;

  /// Applies the live municipality / barangay / category / keyword filters to
  /// the event rails. Barangay matching uses the record's barangay id plus its
  /// venue and directions text, because `events.barangay_id` is a UUID that is
  /// not always populated.
  List<EventItem> _applyFilters(List<EventItem> events) {
    if (!_hasFilters) return events;
    final barangay = _selectedBarangayName?.toLowerCase();
    final query = _searchQuery.toLowerCase();
    return events.where((event) {
      if (_selectedMunicipalityId != null &&
          event.municipalityId != _selectedMunicipalityId) {
        return false;
      }
      if (_selectedCategoryId != null &&
          event.categoryId != _selectedCategoryId) {
        return false;
      }
      if (barangay != null) {
        final haystack = [
          event.barangayId ?? '',
          event.venueName ?? '',
          event.howToGetThere ?? '',
        ].join(' ').toLowerCase();
        if (!haystack.contains(barangay)) return false;
      }
      if (query.isNotEmpty) {
        final haystack = [
          event.title,
          event.description ?? '',
          event.venueName ?? '',
          event.municipalityId,
          event.categoryId ?? '',
        ].join(' ').toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _selectedMunicipalityId = null;
      _selectedBarangayName = null;
      _selectedCategoryId = null;
      _searchQuery = '';
    });
  }

  void _focusQuickSearch() {
    final target = _quickSearchKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: 0.02,
      );
    }
    _searchFocus.requestFocus();
  }

  Future<void> _pickMunicipality(List<Municipality> municipalities) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _MunicipalityPickerSheet(
        municipalities: municipalities,
        selectedMunicipalityId: _selectedMunicipalityId,
        allTownsSentinel: _allTownsSentinel,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _selectedMunicipalityId = result == _allTownsSentinel ? null : result;
      _selectedBarangayName = null;
    });
  }

  /// Interest matches rise to the top while the discover order of the rest is
  /// preserved (the Dart sort is not stable, so no comparator is used).
  List<EventItem> _interestFirst(
    List<EventItem> events,
    bool Function(EventItem) isMatch,
  ) {
    if (events.isEmpty) return events;
    final matches = <EventItem>[];
    final rest = <EventItem>[];
    for (final event in events) {
      (isMatch(event) ? matches : rest).add(event);
    }
    return [...matches, ...rest];
  }

  /// Root-level pages are pushed, shell tabs are switched with `go`.
  void _openFromMenu(BuildContext context, String location) {
    const shellTabs = {'/assistant', '/coordinators'};
    if (shellTabs.contains(location)) {
      context.go(location);
    } else {
      context.push(location);
    }
  }

  Future<void> _toggleSavedEvent(EventItem event) async {
    final saved = await ref.read(savedPlacesProvider).toggleEvent(event);
    final user = ref.read(verifiedAuthUserProvider);
    if (user != null) {
      // Signed-in saves also register interest in event_participation; removing
      // the bookmark clears that row again.
      try {
        final discovery = ref.read(discoveryServiceProvider);
        if (saved) {
          await discovery.rsvpEvent(event.id, 'interested', user.id);
        } else {
          await discovery.removeRsvp(event.id, user.id);
        }
      } catch (_) {
        // Bookmarking must never fail because the RSVP write failed.
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved ? 'Saved to Saved Places & Events' : 'Removed from saved',
        ),
        backgroundColor: const Color(0xFF033300),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Branded, interactive Home header
// ---------------------------------------------------------------------------
class _HomeHeader extends StatelessWidget {
  final Municipality? selectedMunicipality;
  final VoidCallback onPickMunicipality;
  final VoidCallback onSearch;
  final ValueChanged<String> onMenuSelected;

  const _HomeHeader({
    required this.selectedMunicipality,
    required this.onPickMunicipality,
    required this.onSearch,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    final pillLabel = selectedMunicipality?.name ?? 'All 14 Towns';

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
          padding: const EdgeInsets.fromLTRB(16, 8, 6, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: _BrandMark()),
                  _HeaderIconButton(
                    tooltip: 'Search events and places',
                    icon: Icons.search,
                    onPressed: onSearch,
                  ),
                  const AiGuideButton(),
                  const _NotificationBell(),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    onSelected: onMenuSelected,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: '/assistant',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.chat_bubble_outline,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: const Text('AI Assistant'),
                        ),
                      ),
                      PopupMenuItem(
                        value: '/coordinators',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.business,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: const Text('Tourism Coordinators'),
                        ),
                      ),
                      PopupMenuItem(
                        value: '/settings',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.settings_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: const Text('App Settings'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _MunicipalityPill(
                label: pillLabel,
                hasSelection: selectedMunicipality != null,
                onTap: onPickMunicipality,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
            color: Color(0xFFFFC800),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.travel_explore,
            color: Color(0xFF033300),
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
                  fontSize: 16,
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

class _MunicipalityPill extends StatelessWidget {
  final String label;
  final bool hasSelection;
  final VoidCallback onTap;

  const _MunicipalityPill({
    required this.label,
    required this.hasSelection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_city,
                color: Color(0xFFFFC800),
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
              const SizedBox(width: 4),
              Text(
                hasSelection ? '· Rizal' : '',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFFFFC800),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search + interest chips that sit directly under the Home header.
class _QuickSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String query;
  final String? selectedCategoryId;
  final ValueChanged<String> onChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<String?> onCategorySelected;

  const _QuickSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.query,
    required this.selectedCategoryId,
    required this.onChanged,
    required this.onClearQuery,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: isDark
            ? Border.all(color: scheme.outline.withValues(alpha: 0.45))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Column(
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.search,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: 'Search events, towns, festivals…',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              prefixIcon: Icon(
                Icons.search,
                color: scheme.primary,
                size: 21,
              ),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: onClearQuery,
                      icon: const Icon(Icons.close, size: 18),
                    ),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: selectedCategoryId == null,
                    onSelected: (_) => onCategorySelected(null),
                    selectedColor: const Color(0xFFFFC800),
                    backgroundColor: isDark
                        ? const Color(0xFF24352C)
                        : const Color(0xFFF7F6F2),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: selectedCategoryId == null
                          ? const Color(0xFF033300)
                          : scheme.onSurface,
                      fontWeight: selectedCategoryId == null
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    side: BorderSide(
                      color: selectedCategoryId == null
                          ? const Color(0xFFFFC800)
                          : scheme.outline.withValues(alpha: 0.6),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
                for (final category in TourismCategories.all)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CategoryChip(
                      id: category.id,
                      name: category.name,
                      color: category.color,
                      isSelected: selectedCategoryId == category.id,
                      onSelected: () => onCategorySelected(
                        selectedCategoryId == category.id ? null : category.id,
                      ),
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

/// Compact banner shown when Home is scoped to one municipality.
class _ActiveTownFilter extends StatelessWidget {
  final Municipality? municipality;
  final VoidCallback onClear;

  const _ActiveTownFilter({required this.municipality, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24352C) : const Color(0xFFE8F0E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.pin_drop, color: scheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing ${municipality?.name ?? 'selected town'}, Rizal'
              '${municipality != null ? ' · ${municipality!.officeName}' : ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF9FE7B5) : const Color(0xFF033300),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Clear town filter',
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Municipality picker bottom sheet
// ---------------------------------------------------------------------------
class _MunicipalityPickerSheet extends StatelessWidget {
  final List<Municipality> municipalities;
  final String? selectedMunicipalityId;
  final String allTownsSentinel;

  const _MunicipalityPickerSheet({
    required this.municipalities,
    required this.selectedMunicipalityId,
    required this.allTownsSentinel,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.66,
      minChildSize: 0.42,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFC800),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_city,
                        color: Color(0xFF033300),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filter Home by Municipality',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Narrow promoted and featured events to one town.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                  children: [
                    _MunicipalityOption(
                      label: 'All 14 Towns',
                      subtitle: 'Show every Rizal municipality',
                      initials: '14',
                      selected: selectedMunicipalityId == null,
                      onTap: () => Navigator.of(context).pop(allTownsSentinel),
                    ),
                    for (final m in municipalities)
                      _MunicipalityOption(
                        label: m.name,
                        subtitle:
                            m.description ??
                            '${m.name} Municipal Tourism Office',
                        initials: _initials(m.name),
                        selected: selectedMunicipalityId == m.id,
                        onTap: () => Navigator.of(context).pop(m.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _initials(String name) {
    final parts = name
        .split(RegExp(r'[\s\-]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }
}

class _MunicipalityOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final String initials;
  final bool selected;
  final VoidCallback onTap;

  const _MunicipalityOption({
    required this.label,
    required this.subtitle,
    required this.initials,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? (isDark ? const Color(0xFF24352C) : const Color(0xFFE8F0E5))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? (isDark ? scheme.primary : const Color(0xFF033300))
                        : (isDark
                              ? const Color(0xFF24352C)
                              : const Color(0xFFF1F3EE)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? (isDark
                                ? const Color(0xFF06210F)
                                : Colors.white)
                          : scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_circle, color: scheme.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bell icon with a live unread badge for the Notification Inbox.
class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(appNotificationsProvider);
    final controller = ref.watch(notificationsControllerProvider);
    final unread = controller.unreadCount(notifications);

    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => context.push('/notifications'),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      icon: Badge(
        // The badge is hidden entirely when there is nothing unread.
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        backgroundColor: const Color(0xFFFFC800),
        textColor: const Color(0xFF033300),
        child: const Icon(
          Icons.notifications_outlined,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

/// Provincial tourism banner fed by the web admin's Civic Broadcast action.
///
/// Broadcasts are approved, featured civic events whose title starts with
/// "Civic Broadcast:" and whose 24-hour window includes now. Dismissal is local.
class _CivicBroadcastBanner extends StatelessWidget {
  final Stream<List<EventItem>> announcements;
  final Set<String> dismissedIds;
  final ValueChanged<String> onDismiss;

  const _CivicBroadcastBanner({
    required this.announcements,
    required this.dismissedIds,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventItem>>(
      stream: announcements,
      builder: (context, snap) {
        final now = DateTime.now();
        final live = (snap.data ?? []).where((event) {
          final isBroadcast = event.title.startsWith('Civic Broadcast:');
          final inWindow =
              !now.isBefore(event.startDate) && !now.isAfter(event.endDate);
          return isBroadcast && inWindow && !dismissedIds.contains(event.id);
        }).toList();

        if (live.isEmpty) return const SizedBox.shrink();
        final broadcast = live.first;
        final headline = broadcast.title
            .replaceFirst('Civic Broadcast:', '')
            .trim();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4CC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFC800)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.campaign, color: Color(0xFF033300), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Provincial Tourism Advisory',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: Color(0xFF7A5A00),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        headline.isEmpty ? 'Civic broadcast' : headline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF033300),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        broadcast.description ?? '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: Color(0xFF4A3B00),
                        ),
                      ),
                      if (broadcast.venueName != null &&
                          broadcast.venueName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            broadcast.venueName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF7A5A00),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Dismiss advisory',
                  onPressed: () => onDismiss(broadcast.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyRail extends StatelessWidget {
  final String label;
  final VoidCallback? onClear;

  const _EmptyRail({required this.label, this.onClear});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          if (onClear != null)
            TextButton(
              onPressed: onClear,
              child: Text(
                'Clear filters',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
