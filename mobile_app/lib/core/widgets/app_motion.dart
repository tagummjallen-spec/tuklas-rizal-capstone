import 'package:flutter/material.dart';

/// Shared motion + loading primitives so every tab animates the same way.
///
/// The palette constants match [AppTheme] — forest green `#033300`, gold
/// `#FFC800` — and are duplicated here only to keep these small widgets free
/// of a theme lookup.

const Color kMotionForest = Color(0xFF033300);
const Color kMotionGold = Color(0xFFFFC800);

/// Fades + slides a child into place, delayed by its position in a list.
///
/// Used by the event / POI lists so rows cascade in instead of popping.
class StaggeredFadeIn extends StatefulWidget {
  final Widget child;
  final int index;

  /// Cap the cascade so long lists do not wait seconds before appearing.
  final int maxStagger;
  final Duration duration;
  final double offset;

  const StaggeredFadeIn({
    super.key,
    required this.child,
    required this.index,
    this.maxStagger = 8,
    this.duration = const Duration(milliseconds: 320),
    this.offset = 16,
  });

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _fade = curve;
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offset / 100),
      end: Offset.zero,
    ).animate(curve);

    final delayMs = (widget.index.clamp(0, widget.maxStagger)) * 45;
    Future<void>.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// A single pulsing placeholder block.
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 0.6, -1),
              end: Alignment(1 + t * 0.6, 1),
              colors: const [
                Color(0xFFE8EDE6),
                Color(0xFFF4F7F1),
                Color(0xFFE8EDE6),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton card used while Supabase streams events / POIs in.
class EventCardSkeleton extends StatelessWidget {
  final double height;

  const EventCardSkeleton({super.key, this.height = 236});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(height: height * 0.55, borderRadius: BorderRadius.zero),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(height: 14, width: 190),
                SizedBox(height: 8),
                ShimmerBox(height: 11, width: 130),
                SizedBox(height: 6),
                ShimmerBox(height: 11, width: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton rail used by Home's horizontal carousels.
class EventRailSkeleton extends StatelessWidget {
  final int count;

  const EventRailSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.only(right: 12),
        child: SizedBox(width: 216, child: EventCardSkeleton()),
      ),
    );
  }
}

/// Animated bookmarked / not-bookmarked icon, shared by cards and buttons.
class AnimatedBookmarkIcon extends StatelessWidget {
  final bool isSaved;
  final double size;
  final Color color;

  const AnimatedBookmarkIcon({
    super.key,
    required this.isSaved,
    this.size = 20,
    this.color = kMotionForest,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Icon(
        isSaved ? Icons.bookmark : Icons.bookmark_border,
        key: ValueKey<bool>(isSaved),
        size: size,
        color: color,
      ),
    );
  }
}

/// Subtle press feedback shared by tappable cards. Uses `Listener` (not a
/// gesture recognizer) so inner InkWell buttons keep handling taps normally.
class PressScale extends StatefulWidget {
  final Widget child;
  final double scale;

  const PressScale({super.key, required this.child, this.scale = 0.985});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Number that cross-fades whenever it changes (RSVP / heart / review counts).
class AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String suffix;

  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(sizeFactor: animation, child: child),
      ),
      child: Text(
        '$value$suffix',
        key: ValueKey<String>('$value$suffix'),
        style: style,
      ),
    );
  }
}
