import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../models/municipality.dart';
import '../../../models/coordinator_inquiry.dart';

/// Municipal Tourism Coordinator Directory & Direct Inquiry.
///
/// Signed-in tourists also get "My Inquiries & Replies", showing every message
/// they sent and the response posted by the Tourism Coordinator in web_admin.
class CoordinatorsPage extends ConsumerStatefulWidget {
  const CoordinatorsPage({super.key});

  @override
  ConsumerState<CoordinatorsPage> createState() => _CoordinatorsPageState();
}

class _CoordinatorsPageState extends ConsumerState<CoordinatorsPage> {
  static const Color forest = Color(0xFF033300);
  static const Color cream = Color(0xFFF7F6F2);

  static const String _allDistricts = 'All';
  static const String _lakeshore = 'Lakeshore';
  static const String _highlands = 'Highlands / Sierra Madre';
  static const String _metroEast = 'Metro East';

  final _searchCtrl = TextEditingController();
  String _query = '';
  String _district = _allDistricts;

  // Cache the realtime directory stream so search/filter rebuilds don't
  // resubscribe (which would flash an empty list on every keystroke).
  late Stream<List<Municipality>> _directoryStream;

  @override
  void initState() {
    super.initState();
    _directoryStream = ref
        .read(coordinatorServiceProvider)
        .coordinatorDirectory;
  }

  /// Pull-to-refresh: re-subscribe to the live directory and reload labels.
  Future<void> _refresh() async {
    final stream = ref.read(coordinatorServiceProvider).coordinatorDirectory;
    setState(() => _directoryStream = stream);
    ref.invalidate(lookupsProvider);
    try {
      await ref
          .read(municipalitiesProvider.future)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Keep the current directory visible; the stream keeps retrying.
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Groups the 14 Rizal towns into the three tourism areas used by the
  /// Provincial Tourism Office. Keyed by town name so it works with both the
  /// UUID ids in `public.municipalities` and the local seed ids.
  static String _districtFor(String name) {
    switch (name) {
      case 'Angono':
      case 'Binangonan':
      case 'Cardona':
      case 'Jala-Jala':
      case 'Morong':
      case 'Pililla':
        return _lakeshore;
      case 'Antipolo':
      case 'Cainta':
      case 'Taytay':
        return _metroEast;
      default:
        return _highlands; // Baras, Rodriguez, San Mateo, Tanay, Teresa
    }
  }

  List<Municipality> _applyFilters(List<Municipality> municipalities) {
    final query = _query.toLowerCase();
    return municipalities.where((m) {
      if (_district != _allDistricts && _districtFor(m.name) != _district) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack = [
        m.name,
        m.officeName,
        m.coordinatorContactEmail ?? '',
        m.coordinatorContactPhone ?? '',
        m.description ?? '',
        m.tourismOfficeAddress ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(verifiedAuthUserProvider);

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: forest,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          AppConstants.tourismCoordinatorDirectory,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: StreamBuilder<List<Municipality>>(
          stream: _directoryStream,
          builder: (context, snap) {
            final all = snap.data ?? const <Municipality>[];
            final filtered = _applyFilters(all);
            final districts = _districtCounts(all);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _DirectoryHero(total: all.length),
              const SizedBox(height: 14),
              _DirectorySearchBar(
                controller: _searchCtrl,
                query: _query,
                onChanged: (value) => setState(() => _query = value.trim()),
                onClear: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _DistrictChip(
                      label: 'All (${all.length})',
                      selected: _district == _allDistricts,
                      onTap: () => setState(() => _district = _allDistricts),
                    ),
                    _DistrictChip(
                      label: 'Lakeshore (${districts[_lakeshore] ?? 0})',
                      selected: _district == _lakeshore,
                      onTap: () => setState(() => _district = _lakeshore),
                    ),
                    _DistrictChip(
                      label:
                          'Highlands / Sierra Madre (${districts[_highlands] ?? 0})',
                      selected: _district == _highlands,
                      onTap: () => setState(() => _district = _highlands),
                    ),
                    _DistrictChip(
                      label: 'Metro East (${districts[_metroEast] ?? 0})',
                      selected: _district == _metroEast,
                      onTap: () => setState(() => _district = _metroEast),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (user != null) const _MyInquiriesCard(),
              if (user != null) const _SubmitContentCard(),
              if (user == null) const _GuestSignInCard(),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Municipal Tourism Offices',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: forest,
                      ),
                    ),
                  ),
                  _MiniBadge(
                    label: '${filtered.length} of ${all.length}',
                    background: const Color(0xFFE8F0E5),
                    foreground: forest,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (filtered.isEmpty)
                _EmptyDirectory(
                  onClear: () {
                    _searchCtrl.clear();
                    setState(() {
                      _query = '';
                      _district = _allDistricts;
                    });
                  },
                )
              else
                for (final municipality in filtered)
                  _MunicipalityOfficeCard(
                    municipality: municipality,
                    district: _districtFor(municipality.name),
                    onSendInquiry: () => _sendInquiry(municipality),
                    onCopyEmail: () => _copyEmail(municipality),
                    onViewProfile: () => _viewTownProfile(municipality),
                  ),
            ],
          );
          },
        ),
      ),
    );
  }

  Map<String, int> _districtCounts(List<Municipality> municipalities) {
    final counts = <String, int>{};
    for (final municipality in municipalities) {
      final district = _districtFor(municipality.name);
      counts[district] = (counts[district] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _sendInquiry(Municipality municipality) async {
    final signedIn = await requireSignIn(
      context,
      ref,
      action: 'message the ${municipality.name} Tourism Coordinator',
    );
    if (!signedIn || !mounted) return;
    context.push('/inquiry/${municipality.id}');
  }

  Future<void> _copyEmail(Municipality municipality) async {
    final email = municipality.coordinatorContactEmail?.trim() ?? '';
    if (email.isEmpty) {
      _toast('No coordinator email is on file for ${municipality.name}.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: email));
    if (!mounted) return;
    _toast('Copied $email');
  }

  void _viewTownProfile(Municipality municipality) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _TownProfileSheet(
        municipality: municipality,
        district: _districtFor(municipality.name),
        onBrowseEvents: () {
          Navigator.of(sheetContext).pop();
          if (mounted) context.go('/events');
        },
        onSendInquiry: () {
          Navigator.of(sheetContext).pop();
          _sendInquiry(municipality);
        },
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: forest,
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

// ---------------------------------------------------------------------------
// Directory hero + search + filters
// ---------------------------------------------------------------------------
class _DirectoryHero extends StatelessWidget {
  final int total;

  const _DirectoryHero({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF022600), Color(0xFF075A12)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFC800).withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFFFC800),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance,
              color: Color(0xFF033300),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total Municipal Tourism Offices',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Reach the Tourism Coordinator of any Rizal town and read '
                  'their replies.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    height: 1.35,
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

class _DirectorySearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _DirectorySearchBar({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search by town, office, or coordinator email…',
          hintStyle: const TextStyle(fontSize: 12.5),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF033300),
            size: 20,
          ),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 18),
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
        ),
      ),
    );
  }
}

class _DistrictChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DistrictChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFF033300),
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? Colors.white : const Color(0xFF4A4A4A),
        ),
        side: BorderSide(
          color: selected ? const Color(0xFF033300) : const Color(0xFFE5E5E5),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Highlight cards (My Inquiries / Submit Content / Guest)
// ---------------------------------------------------------------------------
class _MyInquiriesCard extends ConsumerWidget {
  const _MyInquiriesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = DateFormat('MMM d, yyyy · h:mm a');
    // Reuse the shared provider so the card doesn't create a new realtime
    // subscription every rebuild.
    final inquiries =
        ref.watch(myInquiriesProvider).valueOrNull ??
        const <CoordinatorInquiry>[];
    final replied = inquiries
        .where((i) => (i.coordinatorReply ?? '').isNotEmpty)
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF033300), Color(0xFF0A5A16)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          iconColor: const Color(0xFFFFC800),
          collapsedIconColor: const Color(0xFFFFC800),
          leading: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFFFC800),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.forum, color: Color(0xFF033300), size: 20),
          ),
          title: const Text(
            'My Inquiries & Replies',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MiniBadge(
                  label: '${inquiries.length} sent',
                  background: Colors.white.withValues(alpha: 0.16),
                  foreground: Colors.white,
                ),
                _MiniBadge(
                  label: '$replied replied',
                  background: const Color(0xFFFFC800),
                  foreground: const Color(0xFF033300),
                ),
              ],
            ),
          ),
          children: [
            if (inquiries.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 4, 4, 4),
                child: Text(
                  'Open a municipality below to ask its Tourism Coordinator '
                  'about schedules, directions or local delicacies.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: Colors.white70,
                  ),
                ),
              )
            else
              for (final inquiry in inquiries)
                _InquiryReplyCard(inquiry: inquiry, formatter: formatter),
          ],
        ),
      ),
    );
  }
}

class _InquiryReplyCard extends StatelessWidget {
  final CoordinatorInquiry inquiry;
  final DateFormat formatter;

  const _InquiryReplyCard({required this.inquiry, required this.formatter});

  @override
  Widget build(BuildContext context) {
    final hasReply = (inquiry.coordinatorReply ?? '').isNotEmpty;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  inquiry.subject,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
              ),
              _StatusChip(status: inquiry.status),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            formatter.format(inquiry.createdAt),
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B6B)),
          ),
          const SizedBox(height: 6),
          Text(inquiry.message, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          if (hasReply)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F6F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFC800)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tourism Coordinator reply',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: Color(0xFF7A5A00),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    inquiry.coordinatorReply!,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            )
          else
            const Text(
              'Awaiting a reply from the Tourism Coordinator.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Color(0xFF6B6B6B),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubmitContentCard extends StatelessWidget {
  const _SubmitContentCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(
          left: BorderSide(color: const Color(0xFFFFC800), width: 5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4CC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.upload_file,
                  color: Color(0xFF033300),
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Submit Content for Review',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF033300),
                  ),
                ),
              ),
              const _MiniBadge(
                label: 'Open',
                background: Color(0xFFDCEFD9),
                foreground: Color(0xFF1B5E20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Send a photo and details; the Tourism Coordinator approves them in '
            'the LGU portal before they appear in TuklasRizal.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PillAction(
                icon: Icons.event,
                label: 'Submit an event',
                filled: true,
                onTap: () => context.push('/submit/event'),
              ),
              _PillAction(
                icon: Icons.place,
                label: 'Submit a place',
                filled: false,
                onTap: () => context.push('/submit/poi'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuestSignInCard extends StatelessWidget {
  const _GuestSignInCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4CC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFC800).withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF033300), size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sign in to message a Tourism Coordinator',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF033300),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'The directory is public; sending inquiries and reading '
                  'replies needs an account.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: Color(0xFF4A3B00),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.push('/login'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF033300),
              backgroundColor: const Color(0xFFFFC800),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: const Text(
              'Sign in',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Municipal office cards
// ---------------------------------------------------------------------------
class _MunicipalityOfficeCard extends StatelessWidget {
  final Municipality municipality;
  final String district;
  final VoidCallback onSendInquiry;
  final VoidCallback onCopyEmail;
  final VoidCallback onViewProfile;

  const _MunicipalityOfficeCard({
    required this.municipality,
    required this.district,
    required this.onSendInquiry,
    required this.onCopyEmail,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    final email = municipality.coordinatorContactEmail?.trim() ?? '';
    final phone = municipality.coordinatorContactPhone?.trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF033300).withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF033300),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _initials(municipality.name),
                  style: const TextStyle(
                    color: Color(0xFFFFC800),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      municipality.officeName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1B1B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: Color(0xFF6B6B6B),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '${municipality.name}, Rizal · $district',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF6B6B6B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ContactLine(icon: Icons.mail_outline, text: email),
          ],
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            _ContactLine(icon: Icons.call_outlined, text: phone),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PillAction(
                icon: Icons.send,
                label: 'Send Inquiry',
                filled: true,
                onTap: onSendInquiry,
              ),
              _PillAction(
                icon: Icons.copy,
                label: 'Copy Email',
                filled: false,
                onTap: onCopyEmail,
              ),
              _PillAction(
                icon: Icons.travel_explore,
                label: 'View Town Profile',
                filled: false,
                onTap: onViewProfile,
              ),
            ],
          ),
        ],
      ),
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

class _ContactLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ContactLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF033300)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF4A4A4A)),
          ),
        ),
      ],
    );
  }
}

class _PillAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _PillAction({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? const Color(0xFF033300) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: filled ? const Color(0xFF033300) : const Color(0xFFDDE3D8),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: filled
                    ? const Color(0xFFFFC800)
                    : const Color(0xFF033300),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: filled ? Colors.white : const Color(0xFF033300),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Town profile sheet
// ---------------------------------------------------------------------------
class _TownProfileSheet extends StatelessWidget {
  final Municipality municipality;
  final String district;
  final VoidCallback onBrowseEvents;
  final VoidCallback onSendInquiry;

  const _TownProfileSheet({
    required this.municipality,
    required this.district,
    required this.onBrowseEvents,
    required this.onSendInquiry,
  });

  @override
  Widget build(BuildContext context) {
    final email = municipality.coordinatorContactEmail?.trim() ?? '';
    final phone = municipality.coordinatorContactPhone?.trim() ?? '';
    final address = municipality.tourismOfficeAddress?.trim() ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF033300),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _initials(municipality.name),
                      style: const TextStyle(
                        color: Color(0xFFFFC800),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          municipality.name,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF033300),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _MiniBadge(
                          label: '$district · Rizal',
                          background: const Color(0xFFE8F0E5),
                          foreground: const Color(0xFF033300),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (municipality.description != null &&
                  municipality.description!.trim().isNotEmpty)
                Text(
                  municipality.description!.trim(),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF3A3A3A),
                  ),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F6F2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MUNICIPAL TOURISM OFFICE',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.7,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF033300),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      municipality.officeName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1B1B),
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _ContactLine(icon: Icons.mail_outline, text: email),
                    ],
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _ContactLine(icon: Icons.call_outlined, text: phone),
                    ],
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _ContactLine(icon: Icons.place_outlined, text: address),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onSendInquiry,
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Send Inquiry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF033300),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onBrowseEvents,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: const Text('Browse events in this town'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF033300),
                    side: const BorderSide(color: Color(0xFF033300)),
                    minimumSize: const Size.fromHeight(46),
                    shape: const StadiumBorder(),
                  ),
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

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------
class _MiniBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _MiniBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}

class _EmptyDirectory extends StatelessWidget {
  final VoidCallback onClear;

  const _EmptyDirectory({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFE7F0E4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off,
              size: 32,
              color: Color(0xFF033300),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No tourism offices match your search',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF033300),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try a different town, office name, or coordinator email.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onClear,
            child: const Text(
              'Clear search & filters',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = status.replaceAll('_', ' ');
    final Color background;
    final Color foreground;
    switch (status) {
      case 'resolved':
        background = const Color(0xFFDCEFD9);
        foreground = const Color(0xFF1B5E20);
      case 'in_progress':
        background = const Color(0xFFE3F0FA);
        foreground = const Color(0xFF0D47A1);
      case 'closed':
        background = const Color(0xFFEDEDED);
        foreground = const Color(0xFF5F5F5F);
      default:
        background = const Color(0xFFFFF4CC);
        foreground = const Color(0xFF7A5A00);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

/// Inquiry form — a signed-in user sends an inquiry to a municipality's
/// Tourism Coordinator (`public.coordinator_inquiries`).
class InquiryPage extends ConsumerStatefulWidget {
  final String municipalityId;
  const InquiryPage({super.key, required this.municipalityId});

  @override
  ConsumerState<InquiryPage> createState() => _InquiryPageState();
}

class _InquiryPageState extends ConsumerState<InquiryPage> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final directory =
        ref.watch(municipalitiesProvider).valueOrNull ?? const <Municipality>[];
    final match = directory
        .where((m) => m.id == widget.municipalityId)
        .toList();
    final municipality = match.isEmpty ? null : match.first;
    final name = municipality?.name ?? widget.municipalityId;
    final office = municipality?.officeName ?? '$name Tourism Office';

    return Scaffold(
      appBar: AppBar(title: Text('Inquiry — $name'), centerTitle: true),
      // Scrollable body so the on-screen keyboard never overflows the form.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Send a direct inquiry to the $office '
              '${AppConstants.tourismCoordinatorTitle}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF6B6B6B)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _subjectCtrl,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageCtrl,
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              maxLength: 1000,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Send Inquiry'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final signedIn = await requireSignIn(
      context,
      ref,
      action: 'send an inquiry to the Tourism Coordinator',
    );
    if (!signedIn || !mounted) return;

    final user = ref.read(verifiedAuthUserProvider);
    if (user == null) return;

    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a subject and a message.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final now = DateTime.now();
    try {
      await ref
          .read(coordinatorServiceProvider)
          .submitInquiry(
            CoordinatorInquiry(
              id: '', // DB-generated UUID; never sent by the app.
              municipalityId: widget.municipalityId,
              userId: user.id,
              subject: subject,
              message: message,
              createdAt: now,
              updatedAt: now,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inquiry sent to Tourism Coordinator.'),
          backgroundColor: Color(0xFF033300),
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not send inquiry. Check your connection and try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
