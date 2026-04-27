import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shayak/l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/rescue_request.dart';
import '../providers/app_providers.dart';
import 'create_request_screen.dart';
import 'map_screen.dart';
import 'request_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _initFCM();
    _startLocationUpdates();
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted) return;
      final isAvailable = ref.read(volunteerToggleProvider);
      if (isAvailable) {
        await _initLocation();
      }
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _initFCM() async {
    final user = await ref.read(authRepoProvider).getCurrentUserDoc();
    if (user == null) return;
    
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ref.read(authRepoProvider).updateFCMToken(user.uid, token);
      }
      
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        ref.read(authRepoProvider).updateFCMToken(user.uid, newToken);
      });
    } catch (e) {
      print('FCM Token error: $e');
    }
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    final pos = await Geolocator.getCurrentPosition();
    if (!mounted) return;

    ref.read(userLocationProvider.notifier).state =
        (lat: pos.latitude, lng: pos.longitude);

    // Update user location in Firestore
    final user = await ref.read(authRepoProvider).getCurrentUserDoc();
    if (user != null && mounted) {
      await ref
          .read(authRepoProvider)
          .updateLocation(user.uid, pos.latitude, pos.longitude);
    }
  }

  void _showSOSDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.priorityRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.sos, color: AppColors.priorityRed, size: 28),
          ),
          const SizedBox(width: 12),
          const Text('SOS Alert'),
        ]),
        content: const Text(
            'This will send a high-priority rescue alert to all nearby volunteers. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.priorityRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateRequestScreen(
                    isSOS: true,
                    initialType: RequestType.rescue,
                  ),
                ),
              );
            },
            child: const Text('SEND SOS',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(nearbyRequestsProvider);
    final userAsync = ref.watch(currentShayakUserProvider);
    final isAvailable = ref.watch(volunteerToggleProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.appTitle,
            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 4)),
        actions: [
          // Volunteer Toggle Chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => ref.read(volunteerToggleProvider.notifier).toggle(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? AppColors.priorityGreen
                      : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        isAvailable
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: Colors.white,
                        size: 14),
                    const SizedBox(width: 4),
                    Text(isAvailable ? l10n.available : l10n.offline,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _initLocation,
        child: ListView(
          padding: const EdgeInsets.all(0),
          children: [
            // Map Preview Banner
            _MapPreviewBanner(l10n: l10n),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting
                  userAsync.when(
                    data: (u) => Text(
                      l10n.hello(u?.name.split(' ').first ?? 'Volunteer'),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(color: AppColors.textPrimary),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  Text(l10n.whatDoYouNeedHelpWith,
                      style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 24),

                  // Category Grid
                  _CategoryGrid(l10n: l10n, onSelect: (type) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CreateRequestScreen(initialType: type),
                      ),
                    );
                  }),
                  const SizedBox(height: 28),

                  // ── New Request Banner ──────────────────────────────────
                  _NewRequestBanner(l10n: l10n, onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateRequestScreen()),
                    );
                  }),
                  const SizedBox(height: 28),

                  // Nearby Requests
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.nearbyRequests,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {},
                        child: Text(l10n.seeAll,
                            style: const TextStyle(color: AppColors.primaryBlue)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  requestsAsync.when(
                    data: (requests) => requests.isEmpty
                        ? _EmptyRequests(l10n: l10n)
                        : Column(
                            children: requests
                                .take(5)
                                .map((r) => _RequestCard(request: r, l10n: l10n))
                                .toList()),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) =>
                        Text('Error: $e', style: const TextStyle(color: AppColors.priorityRed)),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _SOSButton(onPressed: () => _showSOSDialog(context)),
    );
  }
}

class _SOSButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _SOSButton({required this.onPressed});

  @override
  State<_SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<_SOSButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _scale;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _glow = Tween<double>(begin: 4.0, end: 20.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _pulseCtrl.repeat(),
      onLongPressEnd: (_) => _pulseCtrl.stop(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedBuilder(
          animation: _glow,
          builder: (context, child) => Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.priorityRed.withOpacity(0.4),
                  blurRadius: _glow.value,
                  spreadRadius: _glow.value / 2,
                ),
                BoxShadow(
                  color: AppColors.priorityRed.withOpacity(0.2),
                  blurRadius: _glow.value * 2,
                  spreadRadius: _glow.value,
                ),
              ],
            ),
            child: Material(
              color: AppColors.priorityRed,
              shape: const CircleBorder(),
              elevation: 8,
              child: InkWell(
                onLongPress: widget.onPressed,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 80,
                  height: 80,
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sos, color: Colors.white, size: 32),
                      Text('HOLD', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Supporting Widgets ────────────────────────────────────────────────────

class _MapPreviewBanner extends ConsumerWidget {
  const _MapPreviewBanner({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MapScreen()),
      ),
      child: Container(
        height: 180,
        margin: const EdgeInsets.all(0),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryBlue, AppColors.lightBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.map, color: Colors.white, size: 48),
                  const SizedBox(height: 8),
                  Text(l10n.tapToOpenMap,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(l10n.markersDescription,
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.l10n, required this.onSelect});
  final AppLocalizations l10n;
  final void Function(RequestType) onSelect;

  List<(IconData, String, RequestType)> get _cats => [
    (Icons.restaurant, l10n.food, RequestType.food),
    (Icons.bloodtype, l10n.blood, RequestType.blood),
    (Icons.medical_services, l10n.medicine, RequestType.medicine),
    (Icons.waves, l10n.rescue, RequestType.rescue),
    (Icons.psychology, l10n.mentalHealth, RequestType.mentalHealth),
    (Icons.directions_car, l10n.transport, RequestType.transport),
    (Icons.construction, l10n.labour, RequestType.labour),
    (Icons.more_horiz, l10n.other, RequestType.rescue),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.9,
          children: _cats.map((cat) {
            return GestureDetector(
              onTap: () => onSelect(cat.$3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: AppColors.primaryBlue.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                      border: Border.all(
                          color: AppColors.primaryBlue.withOpacity(0.15), width: 1.5),
                    ),
                    child: Icon(cat.$1, color: AppColors.primaryBlue, size: 30),
                  ),
                  const SizedBox(height: 8),
                  Text(cat.$2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NewRequestBanner extends StatefulWidget {
  const _NewRequestBanner({required this.l10n, required this.onTap});
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  State<_NewRequestBanner> createState() => _NewRequestBannerState();
}

class _NewRequestBannerState extends State<_NewRequestBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.02).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_circle_outline, color: Colors.white, size: 32),
              const SizedBox(width: 14),
              Text(widget.l10n.newRequest.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request, required this.l10n});
  final RescueRequest request;
  final AppLocalizations l10n;

  Color get _priorityColor {
    if (request.priorityScore >= 0.7) return AppColors.priorityRed;
    if (request.priorityScore >= 0.4) return AppColors.priorityYellow;
    return AppColors.priorityGreen;
  }

  String get _priorityLabel {
    if (request.priorityScore >= 0.7) return 'HIGH';
    if (request.priorityScore >= 0.4) return 'MEDIUM';
    return 'LOW';
  }

  IconData get _typeIcon {
    switch (request.type) {
      case RequestType.food: return Icons.restaurant;
      case RequestType.blood: return Icons.bloodtype;
      case RequestType.medicine: return Icons.medical_services;
      case RequestType.rescue: return Icons.waves;
      case RequestType.mentalHealth: return Icons.psychology;
      case RequestType.transport: return Icons.directions_car;
      case RequestType.labour: return Icons.construction;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RequestDetailScreen(request: request),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_typeIcon, color: _priorityColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.description,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _priorityColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(_priorityLabel,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Text(request.type.name.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              if (request.status == RequestStatus.pending)
                const Icon(Icons.reply, color: AppColors.primaryBlue)
              else if (request.status == RequestStatus.inProgress)
                const Icon(Icons.handshake, color: AppColors.priorityGreen)
              else
                const Icon(Icons.check_circle, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.priorityGreen, size: 48),
          const SizedBox(height: 12),
          Text(l10n.noActiveRequests,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(l10n.areaSafe,
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}
