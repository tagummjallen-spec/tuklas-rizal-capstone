import '../../models/event_item.dart';
import '../../models/poi_logistics.dart';

/// Explainable "why am I seeing this?" labels for the Rule-Based
/// "Promote Towns and Events" feed.
///
/// The promotion score itself stays in the service layer; these helpers turn
/// the winning rule into short, honest text so residents can see exactly why a
/// card was boosted. Only two reasons are shown to keep the pill compact.
const _busierTowns = <String>{'antipolo', 'taytay', 'cainta'};

/// [visitCount] is the number of recorded visits to the event's municipality
/// (0 means an under-visited / "hidden gem" town).
String? eventPromotionReason({
  required EventItem event,
  required bool isInterestMatch,
  required int visitCount,
}) {
  final reasons = <String>[];
  if (isInterestMatch) reasons.add('Matches Your Interest');
  if (event.isFeatured) {
    final hiddenGem =
        visitCount <= 1 && !_busierTowns.contains(event.municipalityId);
    reasons.add(
      hiddenGem
          ? 'Featured · Hidden Gem Municipality'
          : 'Featured by Tourism Office',
    );
  }
  if (event.promotionWeight > 1.0 && reasons.length < 2) {
    reasons.add('LGU Priority Boost');
  }
  if (reasons.isEmpty) return null;
  return reasons.take(2).join(' · ');
}

String? poiPromotionReason({
  required PoiLogistics poi,
  required bool isInterestMatch,
}) {
  final reasons = <String>[];
  if (isInterestMatch) reasons.add('Matches Your Interest');
  if (poi.isPromoted) {
    reasons.add(
      _busierTowns.contains(poi.municipalityId)
          ? 'Featured by Tourism Office'
          : 'Featured · Hidden Gem Municipality',
    );
  }
  if (reasons.isEmpty) return null;
  return reasons.take(2).join(' · ');
}
