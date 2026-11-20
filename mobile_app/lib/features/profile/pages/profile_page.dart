import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/categories.dart';
import '../../../core/constants/municipalities.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/input_validation.dart';
import '../../../core/utils/logout_confirmation.dart';
import '../../../models/municipality.dart';
import '../../../models/user_profile.dart';

/// TuklasRizal — My Profile.
///
/// A forest-green gradient identity card with a gold-ringed avatar, a tappable
/// three-column activity row, and structured About / Home & Style / Interests /
/// Account cards. Personal details persist to `public.users` (bio via auth
/// metadata) with a namespaced local fallback for travel style and home town.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  static const Color _forest = Color(0xFF033300);
  static const Color _gold = Color(0xFFFFC800);
  static const List<String> _travelStyles = [
    'Day Tripper',
    'Weekend Explorer',
    'Culture Seeker',
    'Food Hunter',
    'Nature Trekker',
  ];

  String? _bio;
  String? _avatarOverride;
  String? _travelStyle;
  String? _homeMunicipalityOverride;
  bool _uploadingAvatar = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _bio = ref.read(authServiceProvider).currentBio;
    _loadLocalProfilePrefs();
  }

  String? get _currentUserId {
    final state = ref.read(authStateProvider).valueOrNull;
    return state?.id ?? ref.read(authServiceProvider).currentUser?.id;
  }

  String get _scope => _currentUserId ?? 'guest';

  Future<void> _loadLocalProfilePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final travel = prefs.getString('profile_travel_style_$_scope');
      final town = prefs.getString('profile_home_municipality_$_scope');
      if (!mounted) return;
      setState(() {
        _travelStyle = travel;
        _homeMunicipalityOverride = town;
      });
    } catch (_) {
      // Local fallback unavailable: keep the profile usable.
    }
  }

  Future<void> _persistLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_travelStyle == null || _travelStyle!.isEmpty) {
        await prefs.remove('profile_travel_style_$_scope');
      } else {
        await prefs.setString('profile_travel_style_$_scope', _travelStyle!);
      }
      if (_homeMunicipalityOverride == null ||
          _homeMunicipalityOverride!.isEmpty) {
        await prefs.remove('profile_home_municipality_$_scope');
      } else {
        await prefs.setString(
          'profile_home_municipality_$_scope',
          _homeMunicipalityOverride!,
        );
      }
    } catch (_) {
      // Best-effort local persistence.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user =
        ref.watch(authStateProvider).valueOrNull ??
        ref.read(authServiceProvider).currentUser;
    final saved = ref.watch(savedPlacesProvider);
    final interests = ref.watch(onboardingControllerProvider).interests;
    final inquiries = ref.watch(myInquiriesProvider).valueOrNull ?? const [];
    final replied = inquiries
        .where((i) => (i.coordinatorReply ?? '').isNotEmpty)
        .length;
    final homeMunicipalityId =
        _homeMunicipalityOverride ?? user?.municipalityId;
    // The saved home town may be a live `public.municipalities` UUID or a
    // local seed slug, so resolve against live data first and fall back to the
    // static seed.
    final liveMunicipalities =
        ref.watch(municipalitiesProvider).valueOrNull ?? const <Municipality>[];
    Municipality? liveHome;
    for (final municipality in liveMunicipalities) {
      if (municipality.id == homeMunicipalityId) {
        liveHome = municipality;
        break;
      }
    }
    final staticHome = homeMunicipalityId == null
        ? null
        : RizalMunicipalities.byId(homeMunicipalityId);
    final homeMunicipalityName =
        liveHome?.name ?? staticHome?.name; // null when unset/unresolved

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildIdentityHeader(user),
          // The avatar straddles the header edge, so leave room for its
          // lower half before the stats card.
          const SizedBox(height: 54),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ActivityStatsRow(
              savedEvents: saved.savedEvents.length,
              placesFollowed: saved.savedPois.length,
              inquiriesSent: inquiries.length,
              onSaved: () => context.go('/saved'),
              onPlaces: () => context.go('/saved'),
              onInquiries: user == null
                  ? () => context.push('/login')
                  : () => context.go('/coordinators'),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileSectionCard(
                  title: 'ABOUT',
                  action: _SectionAction(
                    label: user == null ? 'Sign in' : 'Edit',
                    onTap: () => user == null
                        ? context.push('/login')
                        : _openEditSheet(user),
                  ),
                  child: Text(
                    (_bio == null || _bio!.isEmpty)
                        ? (user == null
                              ? 'Sign in and share a short introduction about yourself.'
                              : 'No bio yet. Tap Edit to add one.')
                        : _bio!,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                _ProfileSectionCard(
                  title: 'HOME MUNICIPALITY & TRAVEL STYLE',
                  action: _SectionAction(
                    label: user == null ? 'Sign in' : 'Edit',
                    onTap: () => user == null
                        ? context.push('/login')
                        : _openEditSheet(user),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_city,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              homeMunicipalityName == null
                                  ? 'Home municipality not set'
                                  : '$homeMunicipalityName, Rizal',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.hiking_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _travelStyle == null || _travelStyle!.isEmpty
                                  ? 'Choose your travel style'
                                  : _travelStyle!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (_travelStyle != null && _travelStyle!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _gold,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Explorer',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _forest,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                _ProfileSectionCard(
                  title: 'INTERESTS & PREFERENCES',
                  action: _SectionAction(
                    label: '+ Edit Interests',
                    onTap: () => user == null
                        ? context.push('/login')
                        : _openEditSheet(user),
                  ),
                  child: interests.isEmpty
                      ? Text(
                          user == null
                              ? 'Sign in or finish onboarding to pick your interests.'
                              : 'No interests selected yet. Tap + Edit Interests.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: interests
                              .map(
                                (id) => _InterestPill(
                                  label: _interestLabel(id),
                                  onTap: user == null
                                      ? () => context.push('/login')
                                      : () => _openEditSheet(user),
                                ),
                              )
                              .toList(),
                        ),
                ),
                _ProfileSectionCard(
                  title: 'ACCOUNT & QUICK LINKS',
                  child: Column(
                    children: [
                      _QuickLinkTile(
                        icon: Icons.bookmark_outline,
                        title: 'My Event Collection',
                        subtitle: saved.savedEvents.isEmpty
                            ? 'No saved events yet'
                            : '${saved.savedEvents.length} saved · '
                                  '${saved.savedEvents.first.title}',
                        onTap: () => context.go('/saved'),
                      ),
                      const Divider(height: 1),
                      _QuickLinkTile(
                        icon: Icons.forum_outlined,
                        title: 'My Inquiries & Replies',
                        subtitle: inquiries.isEmpty
                            ? (user == null
                                  ? 'Sign in to message a Tourism Coordinator'
                                  : 'No inquiries sent yet')
                            : '${inquiries.length} sent · $replied replied',
                        onTap: user == null
                            ? () => context.push('/login')
                            : () => context.go('/coordinators'),
                      ),
                      const Divider(height: 1),
                      _QuickLinkTile(
                        icon: Icons.settings_outlined,
                        title: 'App Settings & Privacy',
                        subtitle: 'Accessibility, notifications, and app info',
                        onTap: () => context.push('/settings'),
                      ),
                      if (user != null) ...[
                        const Divider(height: 1),
                        _QuickLinkTile(
                          icon: Icons.logout,
                          title: 'Sign Out',
                          subtitle: 'Continue browsing as a guest',
                          danger: true,
                          onTap: () => confirmAndSignOut(context, ref),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                if (user == null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/login'),
                      icon: const Icon(Icons.login, size: 18),
                      label: const Text('Sign in to save and sync'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _forest,
                        side: const BorderSide(color: _forest),
                        minimumSize: const Size.fromHeight(48),
                        shape: const StadiumBorder(),
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

  // ---------------------------------------------------------------------------
  // Identity header with overlapping gold-ringed avatar
  // ---------------------------------------------------------------------------
  Widget _buildIdentityHeader(UserProfile? user) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF022600), Color(0xFF075A12)],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 64),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      tooltip: 'Back',
                      onPressed: () =>
                          context.canPop() ? context.pop() : context.go('/'),
                    ),
                    const Spacer(),
                    const Text(
                      'My Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: Colors.white,
                      ),
                      tooltip: 'App Settings',
                      onPressed: () => context.push('/settings'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user?.fullName ?? 'Guest Explorer',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user?.email ?? 'Browsing as a guest',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: Colors.white70),
                ),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user?.roleTitle ?? 'Guest',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: _forest,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (user != null) ...[
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => _openEditSheet(user),
                    icon: const Icon(Icons.edit, size: 17),
                    label: const Text('Edit Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _forest,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 11,
                      ),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // The avatar straddles the header's bottom edge.
        Positioned(bottom: -46, child: _buildAvatar(user)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Avatar
  // ---------------------------------------------------------------------------
  Widget _buildAvatar(UserProfile? user) {
    final url = _avatarOverride ?? user?.avatarUrl;
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _gold,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 46,
              backgroundColor: const Color(0xFFE8F0E5),
              backgroundImage: (url != null && url.isNotEmpty)
                  ? NetworkImage(url)
                  : null,
              child: (url == null || url.isEmpty)
                  ? const Icon(Icons.person, size: 46, color: _forest)
                  : null,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: _uploadingAvatar ? null : () => _pickAvatar(user),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _forest,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: _uploadingAvatar
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAvatar(UserProfile? user) async {
    if (user == null) {
      context.push('/login');
      return;
    }
    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the photo gallery.')),
      );
      return;
    }
    if (!mounted || picked == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await ref
          .read(storageServiceProvider)
          .uploadTourismImage(
            bytes: bytes,
            fileName: picked.name,
            folder: 'avatars',
          );
      if (!mounted) return;
      await ref
          .read(authServiceProvider)
          .updateProfile(
            UserProfile(
              id: user.id,
              email: user.email,
              fullName: user.fullName,
              avatarUrl: url,
              roleTier: user.roleTier,
              roleTitle: user.roleTitle,
              municipalityId: user.municipalityId,
              barangayId: user.barangayId,
              isApproved: user.isApproved,
            ),
          );
      if (!mounted) return;
      setState(() {
        _avatarOverride = url;
        _uploadingAvatar = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated'),
          backgroundColor: _forest,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo upload failed. ${friendlyAuthError(e)}')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Edit sheet
  // ---------------------------------------------------------------------------
  Future<void> _openEditSheet(UserProfile user) async {
    final nameCtrl = TextEditingController(text: user.fullName);
    final bioCtrl = TextEditingController(text: _bio ?? '');
    final onboarding = ref.read(onboardingControllerProvider);
    final selectedInterests = <String>{...onboarding.interests};
    var selectedMunicipality = _homeMunicipalityOverride ?? user.municipalityId;
    var selectedStyle = _travelStyle;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9D9D9),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(sheetContext).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _FieldLabel('DISPLAY NAME'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 50,
                      decoration: const InputDecoration(
                        hintText: 'Your full name',
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _FieldLabel('BIO'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: bioCtrl,
                      maxLines: 3,
                      maxLength: 160,
                      decoration: const InputDecoration(
                        hintText: 'Tell the community about yourself',
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _FieldLabel('HOME MUNICIPALITY'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in RizalMunicipalities.all)
                          ChoiceChip(
                            label: Text(m.name),
                            selected: selectedMunicipality == m.id,
                            selectedColor: _forest,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: selectedMunicipality == m.id
                                  ? Colors.white
                                  : Theme.of(
                                      sheetContext,
                                    ).colorScheme.onSurface,
                            ),
                            side: BorderSide(
                              color: selectedMunicipality == m.id
                                  ? _forest
                                  : Theme.of(
                                      sheetContext,
                                    ).colorScheme.outline.withValues(
                                      alpha: 0.5,
                                    ),
                            ),
                            onSelected: (_) => setSheetState(() {
                              selectedMunicipality =
                                  selectedMunicipality == m.id ? null : m.id;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _FieldLabel('TRAVEL STYLE'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final style in _travelStyles)
                          ChoiceChip(
                            label: Text(style),
                            selected: selectedStyle == style,
                            selectedColor: _gold,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: selectedStyle == style
                                  ? _forest
                                  : Theme.of(
                                      sheetContext,
                                    ).colorScheme.onSurface,
                              fontWeight: selectedStyle == style
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                            side: BorderSide(
                              color: selectedStyle == style
                                  ? _forest
                                  : Theme.of(
                                      sheetContext,
                                    ).colorScheme.outline.withValues(
                                      alpha: 0.5,
                                    ),
                            ),
                            onSelected: (_) => setSheetState(() {
                              selectedStyle = selectedStyle == style
                                  ? null
                                  : style;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _FieldLabel('INTERESTS'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: TourismCategories.all.map((category) {
                        final isOn =
                            selectedInterests.contains(category.slug) ||
                            selectedInterests.contains(category.id);
                        return FilterChip(
                          label: Text(category.name),
                          selected: isOn,
                          selectedColor: _forest,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: isOn
                                ? Colors.white
                                : Theme.of(
                                    sheetContext,
                                  ).colorScheme.onSurface,
                          ),
                          side: BorderSide(
                            color: isOn
                                ? _forest
                                : Theme.of(
                                    sheetContext,
                                  ).colorScheme.outline.withValues(alpha: 0.5),
                          ),
                          onSelected: (_) => setSheetState(() {
                            if (isOn) {
                              selectedInterests.remove(category.slug);
                              selectedInterests.remove(category.id);
                            } else {
                              selectedInterests.add(category.slug);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (saving) return;
                                final newName = nameCtrl.text.trim();
                                if (newName.isEmpty) {
                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Full name cannot be empty.',
                                          ),
                                        ),
                                      );
                                  return;
                                }
                                final auth = ref.read(authServiceProvider);
                                final onboarding = ref.read(
                                  onboardingControllerProvider,
                                );
                                final interests = selectedInterests.toList();
                                final previousBio = _bio;
                                final previousStyle = _travelStyle;
                                final previousTown = _homeMunicipalityOverride;
                                final previousInterests = List<String>.from(
                                  onboarding.interests,
                                );
                                setSheetState(() => saving = true);
                                try {
                                  // Remote writes first; local state is only
                                  // committed once every write succeeded.
                                  await auth.updateProfile(
                                    UserProfile(
                                      id: user.id,
                                      email: user.email,
                                      fullName: newName,
                                      avatarUrl:
                                          _avatarOverride ?? user.avatarUrl,
                                      roleTier: user.roleTier,
                                      roleTitle: user.roleTitle,
                                      // Home town is a local preference; the
                                      // live `municipality_id` column is a UUID
                                      // FK, so keep its existing value rather
                                      // than writing a seed slug into it.
                                      municipalityId: user.municipalityId,
                                      barangayId: user.barangayId,
                                      isApproved: user.isApproved,
                                    ),
                                  );
                                  if (!sheetContext.mounted) return;
                                  await auth.updateBio(bioCtrl.text.trim());
                                  if (!sheetContext.mounted) return;
                                  await auth.setUserInterests(
                                    user.id,
                                    interests,
                                  );
                                  if (!sheetContext.mounted) return;
                                  await onboarding.setInterests(interests);
                                  if (!sheetContext.mounted) return;

                                  _bio = bioCtrl.text.trim();
                                  _travelStyle = selectedStyle;
                                  _homeMunicipalityOverride =
                                      selectedMunicipality;
                                  await _persistLocalPrefs();
                                  if (!sheetContext.mounted) return;
                                  Navigator.of(sheetContext).pop();
                                  if (!mounted) return;
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Profile updated'),
                                      backgroundColor: _forest,
                                    ),
                                  );
                                } catch (e) {
                                  // Best-effort rollback of local state.
                                  try {
                                    await onboarding.setInterests(
                                      previousInterests,
                                    );
                                  } catch (_) {
                                    // Keep the original failure as the message.
                                  }
                                  _bio = previousBio;
                                  _travelStyle = previousStyle;
                                  _homeMunicipalityOverride = previousTown;
                                  if (!sheetContext.mounted) return;
                                  setSheetState(() => saving = false);
                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Could not save profile: '
                                            '${friendlyAuthError(e)}',
                                          ),
                                        ),
                                      );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _forest,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(50),
                          shape: const StadiumBorder(),
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _interestLabel(String id) {
    for (final category in TourismCategories.all) {
      if (category.id == id || category.slug == id) return category.name;
    }
    if (id.isEmpty) return id;
    return id[0].toUpperCase() + id.substring(1).replaceAll('_', ' ');
  }
}

// ---------------------------------------------------------------------------
// Activity stats
// ---------------------------------------------------------------------------
class _ActivityStatsRow extends StatelessWidget {
  final int savedEvents;
  final int placesFollowed;
  final int inquiriesSent;
  final VoidCallback onSaved;
  final VoidCallback onPlaces;
  final VoidCallback onInquiries;

  const _ActivityStatsRow({
    required this.savedEvents,
    required this.placesFollowed,
    required this.inquiriesSent,
    required this.onSaved,
    required this.onPlaces,
    required this.onInquiries,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatButton(
              value: savedEvents,
              label: 'Saved Events',
              icon: Icons.bookmark,
              onTap: onSaved,
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _StatButton(
              value: placesFollowed,
              label: 'Places Followed',
              icon: Icons.place,
              onTap: onPlaces,
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _StatButton(
              value: inquiriesSent,
              label: 'Inquiries Sent',
              icon: Icons.forum,
              onTap: onInquiries,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      color: Theme.of(context).dividerColor,
    );
  }
}

class _StatButton extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _StatButton({
    required this.value,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: scheme.primary),
                const SizedBox(width: 5),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section card & helpers
// ---------------------------------------------------------------------------
class _SectionAction {
  final String label;
  final VoidCallback onTap;
  const _SectionAction({required this.label, required this.onTap});
}

class _ProfileSectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final _SectionAction? action;

  const _ProfileSectionCard({
    required this.title,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? Border.all(color: scheme.outline.withValues(alpha: 0.45))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: scheme.primary,
                  ),
                ),
              ),
              if (action != null)
                TextButton(
                  onPressed: action!.onTap,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    action!.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _QuickLinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  const _QuickLinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errorColor = isDark
        ? const Color(0xFFFFB4AB)
        : const Color(0xFFB3261E);
    final color = danger ? errorColor : scheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: danger
                    ? (isDark
                          ? const Color(0xFF3A2320)
                          : const Color(0xFFFBEAE8))
                    : (isDark
                          ? const Color(0xFF24352C)
                          : const Color(0xFFE8F0E5)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: danger ? color : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: danger ? color : scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10.5,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _InterestPill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _InterestPill({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF24352C) : const Color(0xFF033300),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF9FE7B5) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
