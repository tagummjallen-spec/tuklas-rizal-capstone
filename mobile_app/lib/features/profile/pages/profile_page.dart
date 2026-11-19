import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/categories.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/logout_confirmation.dart';
import '../../../models/user_profile.dart';

/// Rizal Events Hub — My Profile.
///
/// White header, avatar with camera overlay (image_picker → Supabase
/// `tourism-media`), display name, email, Edit Profile sheet (name, bio,
/// interest chips), BIO, MY INTEREST and MY EVENT COLLECTION.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  static const Color _forest = Color(0xFF033300);
  static const Color _gold = Color(0xFFFFC800);

  String? _bio;
  String? _avatarOverride;
  bool _uploadingAvatar = false;
  final _picker = ImagePicker();
  final _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _bio = ref.read(authServiceProvider).currentBio;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull ??
        ref.read(authServiceProvider).currentUser;
    final saved = ref.watch(savedPlacesProvider);
    final interests = ref.watch(onboardingControllerProvider).interests;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F2),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // White header ----------------------------------------------------
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF1B1B1B)),
                    tooltip: 'Back',
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/'),
                  ),
                  const Expanded(
                    child: Text(
                      'My Profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1B1B),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: Color(0xFF1B1B1B)),
                    tooltip: 'App Settings',
                    onPressed: () => context.push('/settings'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                children: [
                  // Avatar + identity ---------------------------------------
                  Center(
                    child: Column(
                      children: [
                        _buildAvatar(user),
                        const SizedBox(height: 12),
                        Text(
                          user?.fullName ?? 'Guest Explorer',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B1B1B),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user?.email ?? 'Browsing as a guest',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B6B6B),
                          ),
                        ),
                        if (user != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F0E5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              user.roleTitle,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _forest,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () => user == null
                              ? context.push('/login')
                              : _openEditSheet(user),
                          icon: Icon(
                            user == null ? Icons.login : Icons.edit,
                            size: 18,
                          ),
                          label: Text(
                            user == null ? 'Sign In to Edit' : 'Edit Profile',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _forest,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 12),
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // BIO -------------------------------------------------------
                  _SectionCard(
                    title: 'BIO',
                    child: Text(
                      (_bio == null || _bio!.isEmpty)
                          ? (user == null
                              ? 'Sign in and share a short introduction about yourself.'
                              : 'No bio yet. Tap Edit Profile to add one.')
                          : _bio!,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: Color(0xFF3A3A3A),
                      ),
                    ),
                  ),

                  // MY INTEREST ----------------------------------------------
                  _SectionCard(
                    title: 'MY INTEREST',
                    child: interests.isEmpty
                        ? Text(
                            user == null
                                ? 'Sign in or finish onboarding to pick your interests.'
                                : 'No interests selected yet. Use Edit Profile to choose.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B6B6B),
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: interests
                                .map((id) => _InterestPill(
                                      label: _interestLabel(id),
                                    ))
                                .toList(),
                          ),
                  ),

                  // MY EVENT COLLECTION --------------------------------------
                  _SectionCard(
                    title: 'MY EVENT COLLECTION',
                    trailing: '${saved.savedEvents.length} saved',
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: saved.savedEvents.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                'No saved events yet. Tap the bookmark on any '
                                'event to build your collection.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B6B6B),
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                for (final event in saved.savedEvents)
                                  TweenAnimationBuilder<double>(
                                    key: ValueKey(event.id),
                                    tween: Tween(begin: 0, end: 1),
                                    duration: const Duration(milliseconds: 220),
                                    builder: (context, value, child) => Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(0, (1 - value) * 12),
                                        child: child,
                                      ),
                                    ),
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8),
                                      child: Material(
                                        color: const Color(0xFFF7F6F2),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        child: ListTile(
                                          dense: true,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          leading: const Icon(Icons.event,
                                              color: _forest, size: 20),
                                          title: Text(
                                            event.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          subtitle: Text(
                                            _dateFormat.format(event.startDate),
                                            style: const TextStyle(
                                                fontSize: 12),
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(
                                              Icons.bookmark_remove,
                                              color: _forest,
                                              size: 19,
                                            ),
                                            tooltip: 'Remove from collection',
                                            onPressed: () => ref
                                                .read(savedPlacesProvider)
                                                .toggleEvent(event),
                                          ),
                                          onTap: () =>
                                              context.push('/event/${event.id}'),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (saved.savedPois.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      '+ ${saved.savedPois.length} saved place'
                                      '${saved.savedPois.length == 1 ? '' : 's'} in Explore',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B6B6B),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 6),
                  if (user != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => confirmAndSignOut(context, ref),
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Log Out'),
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
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Avatar
  // ---------------------------------------------------------------------------
  Widget _buildAvatar(UserProfile? user) {
    final url = _avatarOverride ?? user?.avatarUrl;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            color: _gold,
            shape: BoxShape.circle,
          ),
          child: CircleAvatar(
            radius: 46,
            backgroundColor: const Color(0xFFE8F0E5),
            backgroundImage:
                (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
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
              width: 34,
              height: 34,
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
                  : const Icon(Icons.camera_alt,
                      size: 17, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAvatar(UserProfile? user) async {
    if (user == null) {
      context.push('/login');
      return;
    }
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await ref.read(storageServiceProvider).uploadTourismImage(
            bytes: bytes,
            fileName: picked.name,
            folder: 'avatars',
          );
      await ref.read(authServiceProvider).updateProfile(
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
        SnackBar(content: Text('Photo upload failed: $e')),
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
    final selected = <String>{...onboarding.interests};
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                    const Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _forest,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'DISPLAY NAME',
                      style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration:
                          const InputDecoration(hintText: 'Your full name'),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'BIO',
                      style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: bioCtrl,
                      maxLines: 3,
                      maxLength: 160,
                      decoration: const InputDecoration(
                        hintText: 'Tell the community about yourself',
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'MY INTERESTS',
                      style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: TourismCategories.all.map((category) {
                        final isOn = selected.contains(category.slug) ||
                            selected.contains(category.id);
                        return FilterChip(
                          label: Text(category.name),
                          selected: isOn,
                          selectedColor: _forest,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: isOn ? Colors.white : const Color(0xFF4A4A4A),
                          ),
                          side: BorderSide(
                            color: isOn
                                ? _forest
                                : const Color(0xFFE0E0E0),
                          ),
                          onSelected: (_) => setSheetState(() {
                            if (isOn) {
                              selected.remove(category.slug);
                              selected.remove(category.id);
                            } else {
                              selected.add(category.slug);
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
                                setSheetState(() => saving = true);
                                try {
                                  final auth =
                                      ref.read(authServiceProvider);
                                  final newName = nameCtrl.text.trim();
                                  await auth.updateProfile(
                                    UserProfile(
                                      id: user.id,
                                      email: user.email,
                                      fullName: newName.isEmpty
                                          ? user.fullName
                                          : newName,
                                      avatarUrl: _avatarOverride ??
                                          user.avatarUrl,
                                      roleTier: user.roleTier,
                                      roleTitle: user.roleTitle,
                                      municipalityId: user.municipalityId,
                                      barangayId: user.barangayId,
                                      isApproved: user.isApproved,
                                    ),
                                  );
                                  await auth.updateBio(bioCtrl.text);
                                  final interests = selected.toList();
                                  await ref
                                      .read(onboardingControllerProvider)
                                      .setInterests(interests);
                                  await auth.setUserInterests(
                                      user.id, interests);
                                  if (!sheetContext.mounted) return;
                                  Navigator.of(sheetContext).pop();
                                  if (!mounted) return;
                                  setState(() => _bio = bioCtrl.text.trim());
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Profile updated'),
                                      backgroundColor: _forest,
                                    ),
                                  );
                                } catch (e) {
                                  if (!sheetContext.mounted) return;
                                  setSheetState(() => saving = false);
                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Could not save: $e')),
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

class _SectionCard extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget child;
  const _SectionCard({required this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Color(0xFF033300),
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                Text(
                  trailing!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InterestPill extends StatelessWidget {
  final String label;
  const _InterestPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF033300),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
