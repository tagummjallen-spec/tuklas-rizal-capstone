import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/utils/tourism_images.dart';

/// One-time, four-step animated onboarding flow (Welcome UI 1–4).
///
/// Shown only on the very first launch of the app on a device, gated by
/// `has_completed_onboarding` in SharedPreferences. Runs even before the user
/// logs in. Selected interests are persisted locally immediately so the Home
/// feed can recommend matching events/POIs for guests.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

/// A single selectable onboarding interest with the category slug it maps to
/// (used both for local persistence and for Supabase `user_interests` sync).
class _OnboardingInterest {
  final String label;
  final String categorySlug;
  final IconData icon;
  const _OnboardingInterest(this.label, this.categorySlug, this.icon);
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow>
    with TickerProviderStateMixin {
  static const Duration _pageDuration = Duration(milliseconds: 700);

  late final PageController _pageController;
  late final AnimationController _checkController;
  late final Animation<double> _checkScale;

  int _currentPage = 0;
  bool _autoAdvanceScheduled = false;
  bool _busy = false;
  final List<bool> _selected = List.filled(6, false);

  static const List<_OnboardingInterest> _interests = <_OnboardingInterest>[
    _OnboardingInterest('Festivals', 'festival', Icons.celebration_rounded),
    _OnboardingInterest('Food & Drink', 'food-heritage', Icons.restaurant_rounded),
    _OnboardingInterest('Arts & Culture', 'cultural-arts', Icons.palette_rounded),
    _OnboardingInterest('Faith & Heritage', 'cultural', Icons.church_rounded),
    _OnboardingInterest('Nature & Falls', 'eco-tourism', Icons.water_rounded),
    _OnboardingInterest('Sports & Adventure', 'sports', Icons.hiking_rounded),
  ];

  static const Color _darkGreen = Color(0xFF033300);
  static const Color _gold = Color(0xFFF4C430);
  static const Color _cream = Color(0xFFF7F6F2);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _checkController = AnimationController(vsync: this, duration: _pageDuration);
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
    );
    _scheduleSplashAdvance();
  }

  void _scheduleSplashAdvance() {
    if (_autoAdvanceScheduled) return;
    _autoAdvanceScheduled = true;
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || _currentPage != 0) return;
      _pageController.nextPage(
          duration: const Duration(milliseconds: 800), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    if (page == 3) _checkController.forward();
  }

  bool get _hasSelection => _selected.contains(true);

  Future<void> _continue() async {
    if (_busy) return;
    setState(() => _busy = true);
    final onboard = ref.read(onboardingControllerProvider);
    final chosen = <String>[];
    for (var i = 0; i < _interests.length; i++) {
      if (_selected[i]) chosen.add(_interests[i].categorySlug);
    }
    try {
      await onboard.setInterests(chosen);
      if (!mounted) return;
      _pageController.nextPage(
          duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your interests. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    final onboard = ref.read(onboardingControllerProvider);
    try {
      // Persist the one-time flag before leaving so the welcome flow never shows
      // again on this device.
      await onboard.complete();
      if (!mounted) return;

      // Signed-in users also get the same interests in `public.user_interests`
      // so recommendations follow them across devices.
      final user = ref.read(authServiceProvider).currentUser;
      if (user != null && onboard.hasInterests) {
        try {
          await ref
              .read(authServiceProvider)
              .setUserInterests(user.id, onboard.interests);
        } catch (_) {
          if (!mounted) return;
          // Local persistence already succeeded; never block the exit on sync.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Interests were saved on this device but could not be synced '
                'to your account.',
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not finish setup. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // -----------------------------------------------------------------------
  // Page 0 — Dark green splash with the yellow location-pin logo.
  // -----------------------------------------------------------------------
  Widget _buildSplashPage() {
    return Container(
      color: _darkGreen,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 116,
              height: 116,
              decoration: const BoxDecoration(
                color: _gold,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on,
                  color: _darkGreen, size: 56),
            ),
            const SizedBox(height: 28),
            const Text('RIZAL',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2)),
            const Text('EVENTS',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2)),
            const Text('HUB',
                style: TextStyle(
                    color: _gold,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3)),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Page 1 — Welcome: emblem, eyebrow, headline, subtitle, gold CTA.
  // -----------------------------------------------------------------------
  Widget _buildWelcomePage() {
    return Stack(
      fit: StackFit.expand,
      children: [
        TourismImage(
          imageUrl: TourismImages.higantes,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _darkGreen.withValues(alpha: 0.62),
                _darkGreen.withValues(alpha: 0.94),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 3),
                Center(child: _emblemBadge()),
                const SizedBox(height: 28),
                const Text(
                  'TUKLASRIZAL',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Welcome to Rizal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Discover festivals, heritage landmarks, local flavors, and '
                  'hidden gems across all 14 municipalities.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
                const Spacer(flex: 4),
                _PillButton(
                  label: "Let's Get Started",
                  background: _gold,
                  foreground: const Color(0xFF0B3B17),
                  onPressed: () => _pageController.nextPage(
                      duration: _pageDuration, curve: Curves.easeInOut),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.82),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('Skip for now'),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Circular gold brand badge sitting above the welcome copy.
  Widget _emblemBadge() {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFDD73), _gold],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.travel_explore_rounded,
          color: _darkGreen, size: 42),
    );
  }

  // -----------------------------------------------------------------------
  // Page 2 — Interests: compact icon cards + pinned Continue bar.
  // -----------------------------------------------------------------------
  Widget _buildInterestsPage() {
    return Stack(
      fit: StackFit.expand,
      children: [
        TourismImage(
          imageUrl: TourismImages.masungi,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _darkGreen.withValues(alpha: 0.78),
                _darkGreen.withValues(alpha: 0.96),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 24, 0),
                child: _backButton(),
              ),
              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'What are you interested in?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Pick one or more topics to personalize your Rizal feed',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.05,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _interests.length,
                    itemBuilder: _buildInterestCard,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _darkGreen.withValues(alpha: 0.0),
                      _darkGreen.withValues(alpha: 0.85),
                    ],
                  ),
                ),
                child: _PillButton(
                  label: 'Continue',
                  background: _gold,
                  foreground: const Color(0xFF0B3B17),
                  enabled: _hasSelection && !_busy,
                  loading: _busy,
                  onPressed: _continue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _backButton() {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _pageController.previousPage(
            duration: _pageDuration, curve: Curves.easeInOut),
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Icon(Icons.arrow_back_rounded,
              color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildInterestCard(BuildContext context, int i) {
    final interest = _interests[i];
    final selected = _selected[i];
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _selected[i] = !selected),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: selected
                ? _gold.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? _gold
                  : Colors.white.withValues(alpha: 0.24),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      interest.icon,
                      size: 20,
                      color: selected ? _gold : Colors.white,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      interest.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        height: 1.1,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: _gold,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 12, color: _darkGreen),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Page 3 — "You're all set up!" + animated checkmark + Explore Events.
  // -----------------------------------------------------------------------
  Widget _buildCompletePage() {
    return Container(
      color: _cream,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Center(
                child: AnimatedBuilder(
                  animation: _checkScale,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _checkScale.value,
                      child: Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: _darkGreen,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _darkGreen.withValues(alpha: 0.22),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 54),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "You're all set up!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _darkGreen,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  "Your preferences have been saved. You're now ready to "
                  'explore Rizal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF6B6B6B),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              _PillButton(
                label: 'Explore Events',
                background: _darkGreen,
                foreground: Colors.white,
                enabled: !_busy,
                loading: _busy,
                onPressed: _finish,
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkGreen,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildSplashPage(),
          _buildWelcomePage(),
          _buildInterestsPage(),
          _buildCompletePage(),
        ],
      ),
    );
  }
}

/// Full-width stadium action button used by the onboarding screens.
///
/// Generous `32px` horizontal padding keeps labels off the pill edges, and the
/// `54px` minimum height gives every step the same comfortable tap target.
class _PillButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;
  const _PillButton({
    required this.label,
    required this.background,
    required this.foreground,
    this.enabled = true,
    this.loading = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: 0,
        minimumSize: const Size(double.infinity, 54),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: const StadiumBorder(),
        disabledBackgroundColor: background.withValues(alpha: 0.42),
        disabledForegroundColor: foreground.withValues(alpha: 0.75),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      child: loading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(foreground),
              ),
            )
          : Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
    );
  }
}
