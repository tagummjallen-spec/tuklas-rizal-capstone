import '../../models/event_item.dart';
import '../../models/user_profile.dart';

/// Anti-abuse guardrails shared by the mobile review editor and the event
/// detail page.
///
/// The same rules are enforced server-side by
/// `supabase/review_guardrails.sql` (unique review per user/event, an
/// `'going'` RSVP and `start_date <= now()`), so a modified client cannot
/// bypass them.
const int reviewMinChars = 10;
const int reviewMaxChars = 500;

/// Result of checking whether the current user may rate an event.
class ReviewGate {
  /// True when the user may open the review editor.
  final bool allowed;

  /// Human-readable explanation shown in the review banner.
  final String message;

  /// True when the user already has a review and is editing it.
  final bool isEdit;

  const ReviewGate({
    required this.allowed,
    required this.message,
    this.isEdit = false,
  });
}

/// Evaluates every review requirement, in the order a user would hit them.
///
/// [rsvpStatus] is the locally persisted RSVP (`'going'` / `'interested'` /
/// null). [hasExistingReview] switches the form to "Edit Your Review".
ReviewGate evaluateReviewGate({
  required EventItem event,
  required UserProfile? user,
  required String? rsvpStatus,
  required bool hasExistingReview,
}) {
  if (user == null) {
    return const ReviewGate(
      allowed: false,
      message: 'Sign in to review this event and share your experience.',
    );
  }

  if (event.createdBy != null && event.createdBy == user.id) {
    return const ReviewGate(
      allowed: false,
      message: "Organizers can't review their own event. Thanks for hosting!",
    );
  }

  if (event.status == 'cancelled') {
    return const ReviewGate(
      allowed: false,
      message: 'This event was cancelled, so reviews are closed.',
    );
  }

  if (event.startDate.isAfter(DateTime.now())) {
    return const ReviewGate(
      allowed: false,
      message:
          'Reviews unlock once the event starts for attendees who marked '
          "'I'm Going'.",
    );
  }

  if (rsvpStatus != 'going') {
    return const ReviewGate(
      allowed: false,
      message:
          "Only attendees who marked \"I'm Going\" can review this event. "
          'Update your RSVP on this page first.',
    );
  }

  if (hasExistingReview) {
    return const ReviewGate(
      allowed: true,
      isEdit: true,
      message:
          'You already reviewed this event — saving will update your existing '
          'review instead of posting a duplicate.',
    );
  }

  return const ReviewGate(
    allowed: true,
    message:
        'Verified attendee — one review per event. Your feedback helps other '
        'travellers.',
  );
}

/// Removes angle brackets and script-ish characters before storing a review.
String sanitizeReviewText(String raw) {
  return raw
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'[<>{}\\$`]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Returns an error message, or null when [raw] is acceptable.
String? validateReviewText(String raw) {
  final text = sanitizeReviewText(raw);
  if (text.isEmpty) return 'Please write a short review before posting.';
  if (text.length < reviewMinChars) {
    return 'Reviews need at least $reviewMinChars characters.';
  }
  if (text.length > reviewMaxChars) {
    return 'Keep your review under $reviewMaxChars characters.';
  }
  // Repeated-character spam: "aaaaaaa", "!!!!!!!!".
  if (RegExp(r'(.)\1{4,}').hasMatch(text.replaceAll(' ', ''))) {
    return 'That looks like repeated characters. Please write a real review.';
  }
  final letters = RegExp(r'[A-Za-z]').allMatches(text).length;
  if (letters < 3) {
    return 'Please use words rather than symbols only.';
  }
  // Repeated-word spam: the same word more than four times.
  final words = text
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isNotEmpty) {
    final counts = <String, int>{};
    for (final word in words) {
      counts[word] = (counts[word] ?? 0) + 1;
      if (counts[word]! > 4) {
        return 'Please avoid repeating the same word over and over.';
      }
    }
  }
  return null;
}

/// Ratings must be a whole star between 1 and 5.
bool isValidRating(int rating) => rating >= 1 && rating <= 5;
