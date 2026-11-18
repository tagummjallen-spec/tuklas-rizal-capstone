import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/tourism_images.dart';

/// Auto-playing Rizal tourism hero banner used at the top of Home.
///
/// Rounded card, forest-green gradient, gold page indicators. The images are
/// the same verified Wikimedia photographs the cards fall back to, so the
/// banner never shows a broken placeholder.
class HeroCarousel extends StatefulWidget {
  final int imageCount;
  final double height;

  const HeroCarousel({this.imageCount = 3, this.height = 188, super.key});

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  static const List<({String image, String label, String caption})> _slides = [
    (
      image: TourismImages.higantes,
      label: 'Higantes Festival',
      caption: 'Angono · every November',
    ),
    (
      image: TourismImages.masungi,
      label: 'Masungi Georeserve',
      caption: 'Baras · limestone trails',
    ),
    (
      image: TourismImages.tinipak,
      label: 'Tinipak River',
      caption: 'Tanay · cool mountain water',
    ),
    (
      image: TourismImages.lagunaDeBay,
      label: 'Laguna de Bay',
      caption: 'Cardona · lakeshore sunsets',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentPage + 1) % widget.imageCount;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides.take(widget.imageCount).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: slides.length,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemBuilder: (context, i) {
                final slide = slides[i];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    TourismImage(
                      imageUrl: slide.image,
                      height: widget.height,
                      fit: BoxFit.cover,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0xCC033300)],
                          stops: [0.35, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 26,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slide.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            slide.caption,
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
                  ],
                );
              },
            ),
            Positioned(
              bottom: 9,
              left: 14,
              child: Row(
                children: List.generate(slides.length, (i) {
                  final active = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(right: 5),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFFFFC800)
                          : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
