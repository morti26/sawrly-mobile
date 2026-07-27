import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_service.dart';
import '../../core/design/design_tokens.dart';
import '../../core/services/media_service.dart';
import '../../core/services/status_service.dart';
import '../../models/creator_status.dart';
import '../../models/offer.dart';
import '../../models/user.dart';
import '../home/offer_details_screen.dart';
import '../home/widgets/status_viewer.dart';
import '../profile/creator_profile_screen.dart';
import '../profile/edit_profile_screen.dart';

class FeatureTestScreen extends StatefulWidget {
  const FeatureTestScreen({super.key});

  @override
  State<FeatureTestScreen> createState() => _FeatureTestScreenState();
}

class _FeatureTestScreenState extends State<FeatureTestScreen> {
  late Future<_FeatureTestSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshot();
  }

  Future<_FeatureTestSnapshot> _loadSnapshot() async {
    final authService = context.read<AuthService>();
    final mediaService = context.read<MediaService>();
    final statusService = context.read<StatusService>();
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      return const _FeatureTestSnapshot();
    }

    final fullProfile =
        await authService.fetchUserProfile(currentUser.id) ?? currentUser;
    final ownOffersRaw = await mediaService.fetchOffers(currentUser.id);
    final savedOffersRaw = await mediaService.fetchSavedOffers();
    final ownOffers = ownOffersRaw
        .whereType<Map>()
        .map((item) => Offer.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final savedOffers = savedOffersRaw
        .whereType<Map>()
        .map((item) => Offer.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    await statusService.fetchStatuses();
    final ownStories = statusService.statusList
        .where((story) => story.creatorId.trim() == currentUser.id.trim())
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final allStories = List<CreatorStatus>.from(statusService.statusList)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final ownPhotos = await mediaService.fetchPhotos(currentUser.id);
    final ownVideos = await mediaService.fetchVideos(currentUser.id);

    return _FeatureTestSnapshot(
      currentUser: currentUser,
      fullProfile: fullProfile,
      ownOffers: ownOffers,
      savedOffers: savedOffers,
      ownStories: ownStories,
      allStories: allStories,
      ownPhotoCount: ownPhotos.length,
      ownVideoCount: ownVideos.length,
    );
  }

  Future<void> _refresh() async {
    final future = _loadSnapshot();
    setState(() {
      _snapshotFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Testsida'),
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<_FeatureTestSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Kunde inte läsa testdata.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            );
          }

          final data = snapshot.data ?? const _FeatureTestSnapshot();
          final checks = _buildChecks(data);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildOpinionCard(checks),
                const SizedBox(height: 12),
                _buildDataCard(data),
                const SizedBox(height: 12),
                _buildActionCard(data),
                const SizedBox(height: 16),
                const Text(
                  'Status per punkt',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                ...checks.map((check) => _FeatureCheckTile(check: check)),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_FeatureCheck> _buildChecks(_FeatureTestSnapshot data) {
    return [
      const _FeatureCheck(
        number: 1,
        title: 'Knapp för att rapportera erbjudande',
        status: _FeatureCheckStatus.done,
        note: 'Finns i offertdetaljer och i kreatörsprofilens offertgrid.',
      ),
      const _FeatureCheck(
        number: 2,
        title: 'Spara erbjudande som favorit',
        status: _FeatureCheckStatus.done,
        note: 'Finns i offertkort och offertdetaljer och läses via Mina sparade.',
      ),
      const _FeatureCheck(
        number: 3,
        title: 'Öppna erbjudande från kreatörsprofil',
        status: _FeatureCheckStatus.done,
        note: 'Tryck på kortet i profilgriden öppnar offertdetaljen.',
      ),
      const _FeatureCheck(
        number: 4,
        title: 'Mer ordnad redigera profil-sida',
        status: _FeatureCheckStatus.partial,
        note: 'Fälten är komprimerade och mer ordnade, men inte separat godkända mot din exakta design.',
      ),
      const _FeatureCheck(
        number: 5,
        title: 'Ikon för man eller kvinna allmänt i profilen',
          status: _FeatureCheckStatus.partial,
          note: 'Adminsidans uppladdning för man/kvinna finns, men mobilprofilen visar ännu inte den uppladdade könsikonen allmänt i profilhuvudet.',
      ),
      _FeatureCheck(
        number: 6,
        title: 'Land och stad i kreatörens personliga info',
        status: _FeatureCheckStatus.done,
        note: data.hasServiceArea
            ? 'Serviceområde finns sparat och visas i profilen.'
            : 'Funktionen finns, men det finns inget sparat land/stad på kontot just nu.',
      ),
      const _FeatureCheck(
        number: 7,
        title: 'Laddningslista vid uppladdning',
        status: _FeatureCheckStatus.partial,
        note: 'Det finns ladd-dialog med spinner, men inte en riktig progresslista i procent.',
      ),
      const _FeatureCheck(
        number: 8,
        title: 'Max 1 minut och max 4 videor',
        status: _FeatureCheckStatus.done,
        note: 'Fri nivå stoppas vid 4 videor och 1 minut. Därefter används prenumerationslogik.',
      ),
      const _FeatureCheck(
        number: 9,
        title: 'Max 8 bilder',
        status: _FeatureCheckStatus.missing,
        note: 'Nu är gränsen inte 8 i koden. Nu ligger den på 12 gratis och 16 för monthly.',
      ),
      const _FeatureCheck(
        number: 10,
        title: 'Max 2 erbjudanden',
        status: _FeatureCheckStatus.done,
        note: 'Backend stoppar skapande när kreatören redan har 2 aktiva erbjudanden.',
      ),
      const _FeatureCheck(
        number: 11,
        title: 'Kreatören ska kunna radera eget erbjudande',
        status: _FeatureCheckStatus.partial,
        note: 'Raderingsflödet och backend-fallback finns, men jag räknar det som delvis tills du live-testat det.',
      ),
      const _FeatureCheck(
        number: 12,
        title: 'Story ska visa publiceringstid och försvinna efter 24 timmar',
        status: _FeatureCheckStatus.done,
        note: 'Publiceringstid visas i story-viewer och backend filtrerar bort utgångna stories efter 24 timmar.',
      ),
      const _FeatureCheck(
        number: 13,
        title: 'Rapportera story',
        status: _FeatureCheckStatus.done,
        note: 'Finns i story-viewer för andra användares stories.',
      ),
      const _FeatureCheck(
        number: 14,
        title: 'Visa kontonamn inne i erbjudandet',
        status: _FeatureCheckStatus.done,
        note: 'Kreatörens namn visas både i offertkort och i offertdetaljen.',
      ),
      const _FeatureCheck(
        number: 15,
        title: 'Rapportera profil',
        status: _FeatureCheckStatus.done,
        note: 'Flaggknapp finns i profilhuvudet när man tittar på någon annans profil.',
      ),
    ];
  }

  Widget _buildOpinionCard(List<_FeatureCheck> checks) {
    final doneCount =
        checks.where((check) => check.status == _FeatureCheckStatus.done).length;
    final partialCount = checks
        .where((check) => check.status == _FeatureCheckStatus.partial)
        .length;
    final missingCount = checks
        .where((check) => check.status == _FeatureCheckStatus.missing)
        .length;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Min bedömning',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Det här är bättre nu än tidigare, men jag skulle inte kalla hela listan 100% klar ännu. Det som inte matchar din kravtext exakt är främst könsikon i profilen och bildgränsen på 8.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSummaryChip('$doneCount klara', const Color(0xFF1F8B4C)),
              _buildSummaryChip(
                '$partialCount delvis',
                const Color(0xFFB78103),
              ),
              _buildSummaryChip('$missingCount saknas', const Color(0xFFB63A3A)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataCard(_FeatureTestSnapshot data) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Testdata',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip('Egna erbjudanden: ${data.ownOffers.length}'),
              _buildInfoChip('Sparade: ${data.savedOffers.length}'),
              _buildInfoChip('Egna stories: ${data.ownStories.length}'),
              _buildInfoChip('Bilder: ${data.ownPhotoCount}'),
              _buildInfoChip('Videor: ${data.ownVideoCount}'),
              _buildInfoChip(
                'Kön: ${data.fullProfile?.gender?.trim().isNotEmpty == true ? data.fullProfile!.gender! : "saknas"}',
              ),
              _buildInfoChip(
                'Serviceområde: ${data.hasServiceArea ? "finns" : "saknas"}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(_FeatureTestSnapshot data) {
    final currentUser = data.currentUser;
    final fullProfile = data.fullProfile;
    final firstOwnOffer = data.ownOffers.isNotEmpty ? data.ownOffers.first : null;
    final firstSavedOffer =
        data.savedOffers.isNotEmpty ? data.savedOffers.first : null;
    final firstStory = data.allStories.isNotEmpty ? data.allStories.first : null;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Snabbtest',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionButton(
                label: 'Ladda om',
                onPressed: _refresh,
              ),
              _buildActionButton(
                label: 'Min profil',
                onPressed: currentUser == null || fullProfile == null
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreatorProfileScreen(user: fullProfile),
                          ),
                        );
                      },
              ),
              _buildActionButton(
                label: 'Redigera profil',
                onPressed: currentUser == null || fullProfile == null
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProfileScreen(user: fullProfile),
                          ),
                        );
                      },
              ),
              _buildActionButton(
                label: 'Första egna erbjudandet',
                onPressed: firstOwnOffer == null
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OfferDetailsScreen(offer: firstOwnOffer),
                          ),
                        );
                      },
              ),
              _buildActionButton(
                label: 'Första sparade',
                onPressed: firstSavedOffer == null
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OfferDetailsScreen(offer: firstSavedOffer),
                          ),
                        );
                      },
              ),
              _buildActionButton(
                label: 'Senaste storyn',
                onPressed: firstStory == null
                    ? null
                    : () {
                        showDialog<void>(
                          context: context,
                          builder: (_) => StatusViewer(
                            statuses: data.allStories,
                            initialIndex: 0,
                          ),
                        );
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildSummaryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF7A3EED),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.white10,
        disabledForegroundColor: Colors.white38,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      child: Text(label),
    );
  }
}

class _FeatureCheckTile extends StatelessWidget {
  final _FeatureCheck check;

  const _FeatureCheckTile({required this.check});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (check.status) {
      _FeatureCheckStatus.done => const Color(0xFF3CCB75),
      _FeatureCheckStatus.partial => const Color(0xFFFFB020),
      _FeatureCheckStatus.missing => const Color(0xFFFF5C5C),
    };
    final statusLabel = switch (check.status) {
      _FeatureCheckStatus.done => 'Klar',
      _FeatureCheckStatus.partial => 'Delvis',
      _FeatureCheckStatus.missing => 'Saknas',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${check.number}. ${check.title}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            check.note,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCheck {
  final int number;
  final String title;
  final _FeatureCheckStatus status;
  final String note;

  const _FeatureCheck({
    required this.number,
    required this.title,
    required this.status,
    required this.note,
  });
}

enum _FeatureCheckStatus { done, partial, missing }

class _FeatureTestSnapshot {
  final User? currentUser;
  final User? fullProfile;
  final List<Offer> ownOffers;
  final List<Offer> savedOffers;
  final List<CreatorStatus> ownStories;
  final List<CreatorStatus> allStories;
  final int ownPhotoCount;
  final int ownVideoCount;

  const _FeatureTestSnapshot({
    this.currentUser,
    this.fullProfile,
    this.ownOffers = const [],
    this.savedOffers = const [],
    this.ownStories = const [],
    this.allStories = const [],
    this.ownPhotoCount = 0,
    this.ownVideoCount = 0,
  });

  bool get hasServiceArea {
    final country = fullProfile?.country?.trim() ?? '';
    final city = fullProfile?.city?.trim() ?? '';
    return country.isNotEmpty || city.isNotEmpty;
  }
}
