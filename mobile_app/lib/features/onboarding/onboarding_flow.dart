import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/utils/tourism_images.dart';

/// One-time, four-step animated onboarding flow (Welcome UI 1â€“4).
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
  const _OnboardingInterest(this.label, this.categorySlug);
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow>
    with TickerProviderStateMixin {
  static const Duration _pageDuration = Duration(milliseconds: 700);

  late final PageController _pageController;
  late final AnimationController _checkController;
  late final Animation<double> _checkScale;

  int _currentPage = 0;
  bool _autoAdvanceScheduled = false;
  final List<bool> _selected = List.filled(8, false);

  static const List<_OnboardingInterest> _interests = <_OnboardingInterest>[
    _OnboardingInterest('Festivals', 'festival'),
    _OnboardingInterest('Food & Drink', 'food-heritage'),
    _OnboardingInterest('Arts & Culture', 'cultural-arts'),
    _OnboardingInterest('Music', 'cultural-arts'),
    _OnboardingInterest('Workshops', 'civic'),
    _OnboardingInterest('Sports', 'sports'),
    _OnboardingInterest('Parades', 'festival'),
    _OnboardingInterest('Heritage Sites', 'cultural-arts'),
  ];

  static const Color _darkGreen = Color(0xFF033300);
  static const Color _gold = Color(0xFFFFC800);
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
    final onboard = ref.read(onboardingControllerProvider);
    final chosen = <String>[];
    for (var i = 0; i < _interests.length; i++) {
      if (_selected[i]) chosen.add(_interests[i].categorySlug);
    }
    await onboard.setInterests(chosen);
    if (!mounted) return;
    _pageController.nextPage(
        duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
  }

  Future<void> _finish() async {
    final onboard = ref.read(onboardingControllerProvider);
    // Persist the one-time flag before leaving so the welcome flow never shows
    // again on this device.
    await onboard.complete();

    // Signed-in users also get the same interests in `public.user_interests` so
    // recommendations follow them across devices.
    final user = ref.read(authServiceProvider).currentUser;
    if (user != null && onboard.hasInterests) {
      try {
        await ref
            .read(authServiceProvider)
            .setUserInterests(user.id, onboard.interests);
      } catch (_) {
        // Local persistence already succeeded; never block the exit on sync.
      }
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
  // Page 1 — Festival hero photo + "Let's get started" pill.
  // -----------------------------------------------------------------------
  Widget _buildWelcomePage() {
    return _heroPage(
      image: TourismImages.higantes,
      headline: 'Welcome',
      subhead: 'EXPLORE EVENTS IN YOUR AREA',
      buttonLabel: "Let's get started",
      onButton: () => _pageController.nextPage(
          duration: _pageDuration, curve: Curves.easeInOut),
    );
  }

  // -----------------------------------------------------------------------
  // Page 2 — Rizal rock formation + interest chips + Continue.
  // -----------------------------------------------------------------------
  Widget _buildInterestsPage() {
    return _heroPage(
      image: TourismImages.masungi,
      headline: 'What are you interested in?',
      subhead: null,
      buttonLabel: 'Continue',
      buttonEnabled: _hasSelection,
      onButton: _continue,
      middle: _buildInterestChips(),
    );
  }

  // -----------------------------------------------------------------------
  // Page 3 — "You're all set up!" + animated checkmark + Explore Events.
  // -----------------------------------------------------------------------
  Widget _buildCompletePage() {
    return Container(
      color: _cream,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: _checkScale,
              builder: (context, child) {
                return Transform.scale(
                  scale: _checkScale.value,
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: const BoxDecoration(
                      color: _darkGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle,
                        color: Colors.white, size: 56),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text("You're all set up!",
                style: TextStyle(
                    color: _darkGreen,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Your preferences have been saved. '
              'You''re now ready to explore Rizal.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF6B6B6B), fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 32),
            _PillButton(
              label: 'Explore Events',
              background: _darkGreen,
              foreground: Colors.white,
              onPressed: _finish,
            ),
          ],
        ),
      ),
    );
  }

  /// Full-bleed hero page with a readable overlay and an action pill.
  Widget _heroPage({
    required String image,
    required String headline,
    String? subhead,
    required String buttonLabel,
    bool buttonEnabled = true,
    required VoidCallback onButton,
    Widget? middle,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        TourismImage(
          imageUrl: image,
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
                _darkGreen.withValues(alpha: 0.55),
                _darkGreen.withValues(alpha: 0.85),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              if (_currentPage > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: InkWell(
                      onTap: () => _pageController.previousPage(
                          duration: _pageDuration,
                          curve: Curves.easeInOut),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.chevron_left,
                            color: Colors.white, size: 32),
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(headline,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800)),
                    if (subhead != null) ...[
                      const SizedBox(height: 8),
                      Text(subhead,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2)),
                    ],
                    if (middle != null) ...[
                      const SizedBox(height: 26),
                      middle,
                    ],
                    const SizedBox(height: 34),
                    _PillButton(
                      label: buttonLabel,
                      background: _gold,
                      foreground: _darkGreen,
                      enabled: buttonEnabled,
                      onPressed: onButton,
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ],
    );
  }

  /// Selectable pill chips for the onboarding interests.
  Widget _buildInterestChips() {
    return SizedBox(
      height: 340,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _interests.length,
        itemBuilder: (context, i) {
          final interest = _interests[i];
          final selected = _selected[i];
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() => _selected[i] = !selected);
            },
            child: Container(
              decoration: BoxDecoration(
                color: selected
                    ? _darkGreen
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: selected
                        ? _gold
                        : Colors.white.withValues(alpha: 0.35),
                    width: selected ? 2 : 1),
              ),
              alignment: Alignment.center,
              child: Text(
                interest.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: selected
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Page indicator dots shown below the carousel pages.
  Widget _buildIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) {
          final active = i == _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: active ? 26 : 10,
            height: 8,
            decoration: BoxDecoration(
              color: active ? _gold : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkGreen,
      body: Stack(
        children: [
          PageView(
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
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: _currentPage == 0 ? 0.0 : 1.0,
              child: _buildIndicator(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded pill action button used by the onboarding steps.
class _PillButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final bool enabled;
  final VoidCallback onPressed;
  const _PillButton({
    required this.label,
    required this.background,
    required this.foreground,
    this.enabled = true,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          shape: const StadiumBorder(),
          disabledBackgroundColor: background.withValues(alpha: 0.45),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
