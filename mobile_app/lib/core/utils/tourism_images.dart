import 'package:flutter/material.dart';

/// Category-aware Rizal tourism photography.
///
/// Live records often have no `image_url` (or still point at the old
/// `placehold.co` / `via.placeholder.com` mock URLs). Instead of rendering a
/// grey 600x400 box, every card falls back to a real, verified photograph of
/// Rizal from Wikimedia Commons, chosen from the record's category.
class TourismImages {
  const TourismImages._();

  static const String _wiki =
      'https://upload.wikimedia.org/wikipedia/commons/thumb';

  /// Higantes of Angono at the municipal hall.
  static const String higantes =
      '$_wiki/f/f0/Higantes_Angono_Municipal_Hall.jpg/960px-Higantes_Angono_Municipal_Hall.jpg';

  /// Angono–Binangonan Petroglyphs.
  static const String petroglyphs =
      '$_wiki/c/c0/Angono_Petroglyphs_centered.jpg/960px-Angono_Petroglyphs_centered.jpg';

  /// Antipolo Cathedral, National Shrine of Our Lady of Peace and Good Voyage.
  static const String antipoloCathedral =
      '$_wiki/f/fb/Antipolo_Cathedral_Sanctuary_1994.jpg/960px-Antipolo_Cathedral_Sanctuary_1994.jpg';

  /// Suman, the Rizal kakanin served at Antipolo's SuMaKaH Festival.
  static const String suman =
      '$_wiki/9/98/Suman_or_Rice_cake.jpg/960px-Suman_or_Rice_cake.jpg';

  /// Tinipak River in Tanay.
  static const String tinipak =
      '$_wiki/8/83/Tinipak_or_Agos_River_in_Tanay%2C_Rizal.jpg/960px-Tinipak_or_Agos_River_in_Tanay%2C_Rizal.jpg';

  /// Masungi Georeserve, Baras.
  static const String masungi =
      '$_wiki/6/6f/Sapot_Masungi_Georserve.jpg/960px-Sapot_Masungi_Georserve.jpg';

  /// Pililla Wind Farm.
  static const String pilillaWindFarm =
      '$_wiki/1/13/Pililla_Windfarm.jpg/960px-Pililla_Windfarm.jpg';

  /// Laguna de Bay shoreline at Cardona.
  static const String lagunaDeBay =
      '$_wiki/8/81/Laguna_Lake%2C_Cardona_%28Rizal%3B_08-14-2021%29.jpg/960px-Laguna_Lake%2C_Cardona_%28Rizal%3B_08-14-2021%29.jpg';

  /// Antipolo City Hall — civic and community programs.
  static const String antipoloCityHall =
      '$_wiki/f/f6/Antipolo_City_Hall%2C_Rizal%2C_Jul_2024.jpg/960px-Antipolo_City_Hall%2C_Rizal%2C_Jul_2024.jpg';

  /// St. Jerome Parish, Morong.
  static const String morongChurch =
      '$_wiki/7/7a/Morong_Church%2C_Rizal%2C_Nov_2025_%282%29.jpg/960px-Morong_Church%2C_Rizal%2C_Nov_2025_%282%29.jpg';

  /// Mountain-bike trail riding.
  static const String trailRiding =
      '$_wiki/5/50/Cyclists_step_on_their_pedals_and_accelerate_at_the_starting_lane_of_the_7-Eleven_Trail_2018_%28711-trail%29.jpg/960px-Cyclists_step_on_their_pedals_and_accelerate_at_the_starting_lane_of_the_7-Eleven_Trail_2018_%28711-trail%29.jpg';

  /// True when [url] is a real, renderable photo rather than a mock placeholder.
  static bool isUsable(String? url) {
    if (url == null) return false;
    final value = url.trim();
    if (value.isEmpty) return false;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      return false;
    }
    final lowered = value.toLowerCase();
    return !lowered.contains('placehold.co') &&
        !lowered.contains('via.placeholder') &&
        !lowered.contains('dummyimage') &&
        !lowered.contains('lorempixel') &&
        !lowered.contains('example.com');
  }

  /// Pick a Rizal photograph for a category slug/name, POI type or event.
  static String forCategory(String? category, {String? municipality}) {
    final token = (category ?? '').toLowerCase();
    if (token.contains('festival') ||
        token.contains('fiesta') ||
        token.contains('higantes')) {
      return higantes;
    }
    if (token.contains('food') ||
        token.contains('kakanin') ||
        token.contains('culinary') ||
        token.contains('restaurant') ||
        token.contains('unique')) {
      return suman;
    }
    if (token.contains('eco') ||
        token.contains('nature') ||
        token.contains('waterfall') ||
        token.contains('river') ||
        token.contains('trek') ||
        token.contains('mountain') ||
        token.contains('destination') ||
        token.contains('georeserve')) {
      return tinipak;
    }
    if (token.contains('civic') || token.contains('community')) {
      return antipoloCityHall;
    }
    if (token.contains('sport') ||
        token.contains('recreat') ||
        token.contains('bike') ||
        token.contains('trail')) {
      return trailRiding;
    }
    if (token.contains('cultural') ||
        token.contains('art') ||
        token.contains('heritage') ||
        token.contains('museum')) {
      return petroglyphs;
    }

    // Municipality-aware last resort for uncategorised records.
    final place = (municipality ?? '').toLowerCase();
    if (place.contains('tanay') || place.contains('baras')) return masungi;
    if (place.contains('pililla')) return pilillaWindFarm;
    if (place.contains('morong')) return morongChurch;
    if (place.contains('antipolo')) return antipoloCathedral;
    return lagunaDeBay;
  }

  /// The best photo for a record: its own image when usable, else the fallback.
  static String resolve(
    String? imageUrl, {
    String? category,
    String? municipality,
  }) {
    return isUsable(imageUrl)
        ? imageUrl!.trim()
        : forCategory(category, municipality: municipality);
  }

  /// Gradient placeholder used only if even the fallback photo cannot load.
  static Widget fallback({double? height, double? width, BoxFit fit = BoxFit.cover}) {
    return Container(
      height: height,
      width: width,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF033300), Color(0xFF2F6B2A)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC800).withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFC800).withValues(alpha: 0.65),
                ),
              ),
              child: const Icon(
                Icons.landscape_outlined,
                color: Color(0xFFFFC800),
                size: 26,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'TuklasRizal',
              style: TextStyle(
                color: Color(0xFFFFC800),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Calm loading placeholder that mirrors the final photo dimensions so cards
  /// never jump when the image arrives.
  static Widget loading({double? height, double? width}) {
    return Container(
      height: height,
      width: width,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE7EFE4), Color(0xFFF3F6F0)],
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2F6B2A)),
          ),
        ),
      ),
    );
  }
}

/// Network photo for a tourism record with the Rizal fallback applied.
class TourismImage extends StatelessWidget {
  final String? imageUrl;
  final String? category;
  final String? municipality;
  final double? height;
  final double? width;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const TourismImage({
    super.key,
    required this.imageUrl,
    this.category,
    this.municipality,
    this.height,
    this.width = double.infinity,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final url = TourismImages.resolve(
      imageUrl,
      category: category,
      municipality: municipality,
    );

    final image = Image.network(
      url,
      key: ValueKey(url),
      height: height,
      width: width,
      fit: fit,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: frame == null
              ? TourismImages.loading(height: height, width: width)
              : child,
        );
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return TourismImages.loading(height: height, width: width);
      },
      errorBuilder: (context, error, stackTrace) => TourismImages.fallback(
        height: height,
        width: width,
        fit: fit,
      ),
    );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
