import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shayak/l10n/app_localizations.dart';
import '../../domain/entities/rescue_request.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/auth_repository.dart';
import '../providers/app_providers.dart';
import '../../data/services/directions_service.dart';
import 'package:geocoding/geocoding.dart';

class RequestDetailScreen extends ConsumerStatefulWidget {
  final RescueRequest request;

  const RequestDetailScreen({super.key, required this.request});

  @override
  ConsumerState<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  late AudioPlayer _audioPlayer;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String _address = 'Loading address...';

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _getAddress();
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _getAddress() async {
    if (kIsWeb) {
      setState(() => _address = '${widget.request.location.latitude.toStringAsFixed(4)}, ${widget.request.location.longitude.toStringAsFixed(4)}');
      return;
    }
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.request.location.latitude,
        widget.request.location.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        setState(() => _address = '${p.name}, ${p.subLocality}, ${p.locality}, ${p.postalCode}');
      }
    } catch (e) {
      if (mounted) setState(() => _address = 'Address unavailable');
    }
  }

  Future<void> _toggleAudio() async {
    if (widget.request.voiceUrl == null) return;

    if (_playerState == PlayerState.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(widget.request.voiceUrl!));
    }
  }

  Color get _priorityColor {
    if (widget.request.priorityScore >= 0.7) return AppColors.priorityRed;
    if (widget.request.priorityScore >= 0.4) return AppColors.priorityYellow;
    return AppColors.priorityGreen;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.requestDetails, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Priority Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _priorityColor),
                  ),
                  child: Text(
                    widget.request.type.name.toUpperCase(),
                    style: TextStyle(color: _priorityColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const Spacer(),
                Text(
                  widget.request.status.name.toUpperCase(),
                  style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Description
            const Text('DESCRIPTION', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            Text(
              widget.request.description,
              style: const TextStyle(fontSize: 18, color: AppColors.textPrimary, height: 1.5),
            ),
            const SizedBox(height: 32),

            // Photo Section
            if (widget.request.photoUrl != null) ...[
              const Text('ATTACHED PHOTO', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: widget.request.photoUrl!,
                  placeholder: (context, url) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Icon(Icons.error),
                  ),
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Audio Section
            if (widget.request.voiceUrl != null) ...[
              const Text('VOICE ALERT', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _playerState == PlayerState.playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: AppColors.primaryBlue,
                        size: 48,
                      ),
                      onPressed: _toggleAudio,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Slider(
                            value: _position.inSeconds.toDouble(),
                            max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                            onChanged: (v) => _audioPlayer.seek(Duration(seconds: v.toInt())),
                            activeColor: AppColors.primaryBlue,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(_position), style: const TextStyle(fontSize: 10)),
                                Text(_formatDuration(_duration), style: const TextStyle(fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            const Text('LOCATION', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 12),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: widget.request.location,
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('request'),
                      position: widget.request.location,
                      infoWindow: InfoWindow(title: widget.request.type.name),
                    ),
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  scrollGesturesEnabled: false, // Static look
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.primaryBlue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _address,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            if (widget.request.responderId != null) ...[
              const Text('ASSIGNED VOLUNTEER', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              ref.watch(responderProvider(widget.request.responderId!)).when(
                data: (volunteer) {
                  if (volunteer == null) return const Text('Volunteer info unavailable');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.volunteer_activism, color: AppColors.priorityGreen, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${volunteer.name} is on the way',
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (volunteer.latitude != null && volunteer.longitude != null)
                        SizedBox(
                          height: 200,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: LatLng(volunteer.latitude!, volunteer.longitude!),
                                zoom: 14,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('volunteer'),
                                  position: LatLng(volunteer.latitude!, volunteer.longitude!),
                                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                                  infoWindow: const InfoWindow(title: 'Volunteer Location'),
                                ),
                                Marker(
                                  markerId: const MarkerId('request'),
                                  position: widget.request.location,
                                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                                  infoWindow: const InfoWindow(title: 'Request Location'),
                                ),
                              },
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: false,
                            ),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error tracking volunteer: $e'),
              ),
              const SizedBox(height: 24),
            ],

            const SizedBox(height: 100), // Bottom padding for FAB
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: widget.request.status == RequestStatus.pending
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                onPressed: () => _respondToRequest(context, ref),
                child: const Text(
                  'RESPOND TO THIS REQUEST',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            )
          : null,
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  void _respondToRequest(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Response'),
        content: const Text('Are you sure you want to handle this request? The requester will be notified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            onPressed: () {
              final user = ref.read(currentShayakUserProvider).value;
              ref.read(requestRepoProvider).updateStatus(
                widget.request.id, 
                RequestStatus.inProgress,
                responderId: user?.uid,
              );
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to home
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Response sent! You are now handling this request.')),
              );
            },
            child: const Text('CONFIRM', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
