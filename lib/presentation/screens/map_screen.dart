import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/rescue_request.dart';
import '../providers/app_providers.dart';
import '../../data/services/directions_service.dart';
import '../../data/repositories/auth_repository.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(userLocationProvider);
    final requestsAsync = ref.watch(nearbyRequestsProvider);
    final volunteersAsync = ref.watch(allVolunteersProvider);

    final initialPos = location != null
        ? CameraPosition(
            target: LatLng(location.lat, location.lng),
            zoom: 14,
          )
        : const CameraPosition(
            target: LatLng(20.5937, 78.9629), // India center
            zoom: 5,
          );

    requestsAsync.whenData((requests) {
      volunteersAsync.whenData((volunteers) {
        _buildMarkers(requests, volunteers);
      });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Live Disaster Map'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {},
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'all', child: Text('All Priorities')),
              PopupMenuItem(value: 'high', child: Text('🔴 High Only')),
              PopupMenuItem(value: 'medium', child: Text('🟡 Medium Only')),
              PopupMenuItem(value: 'low', child: Text('🟢 Low Only')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: initialPos,
            onMapCreated: (ctrl) => _mapController = ctrl,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapType: MapType.normal,
            compassEnabled: true,
          ),
          // Legend
          Positioned(
            bottom: 20,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1), blurRadius: 8)
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Priority Legend',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 8),
                  _LegendItem(color: AppColors.priorityRed, label: 'High (≥ 0.7)'),
                  _LegendItem(
                      color: AppColors.priorityYellow, label: 'Medium (≥ 0.4)'),
                  _LegendItem(
                      color: AppColors.priorityGreen, label: 'Low (< 0.4)'),
                ],
              ),
            ),
          ),
          // Request count
          requestsAsync.when(
            data: (reqs) => Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1), blurRadius: 6)
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: AppColors.primaryBlue, size: 20),
                    const SizedBox(width: 8),
                    Text('${reqs.length} Active Requests Nearby',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _buildMarkers(List<RescueRequest> requests, List<ShayakUser> volunteers) {
    final markers = <Marker>{};
    
    // Add Request Markers
    for (var req in requests) {
      final color = _getHue(req.priorityScore);
      markers.add(Marker(
        markerId: MarkerId('req_${req.id}'),
        position: req.location,
        infoWindow: InfoWindow(
          title: req.type.name.toUpperCase(),
          snippet: req.description,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(color),
        onTap: () => _showRequestBottomSheet(req),
      ));
    }

    // Add Volunteer Markers
    for (var vol in volunteers) {
      if (vol.latitude == null || vol.longitude == null || !vol.isAvailable) continue;
      markers.add(Marker(
        markerId: MarkerId('vol_${vol.uid}'),
        position: LatLng(vol.latitude!, vol.longitude!),
        infoWindow: InfoWindow(
          title: 'Volunteer: ${vol.name}',
          snippet: 'Available for help',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    if (mounted) setState(() => _markers = markers);
  }

  double _getHue(double score) {
    if (score >= 0.7) return BitmapDescriptor.hueRed;
    if (score >= 0.4) return BitmapDescriptor.hueYellow;
    return BitmapDescriptor.hueGreen;
  }

  void _showRequestBottomSheet(RescueRequest req) async {
    final location = ref.read(userLocationProvider);
    DirectionsInfo? routeInfo;

    if (location != null) {
      // Fetch directions before showing
      routeInfo = await DirectionsService().getDirections(
        origin: LatLng(location.lat, location.lng),
        destination: req.location,
      );

      if (routeInfo != null && mounted) {
        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              color: AppColors.primaryBlue,
              width: 5,
              points: routeInfo!.polylinePoints,
            )
          };
        });
        
        // Zoom to fit
        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(
            _boundsFromLatLngList([
              LatLng(location.lat, location.lng),
              req.location,
            ]),
            50.0,
          ),
        );
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.emergency,
                      color: AppColors.primaryBlue),
                ),
                const SizedBox(width: 12),
                Text(req.type.name.toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.textPrimary)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(req.priorityScore)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_getPriorityLabel(req.priorityScore),
                      style: TextStyle(
                          color: _getPriorityColor(req.priorityScore),
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(req.description,
                style:
                    const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.speed, color: AppColors.primaryBlue, size: 16),
                const SizedBox(width: 4),
                Text(
                    'Priority Score: ${(req.priorityScore * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            if (routeInfo != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.directions_car, color: AppColors.primaryBlue, size: 16),
                  const SizedBox(width: 4),
                  Text(
                      'Distance: ${routeInfo.distance} • ETA: ${routeInfo.duration}',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryBlue)),
                ],
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                ref.read(requestRepoProvider).updateStatus(req.id, RequestStatus.inProgress);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('You are now responding to this request!')),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Respond to Request',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _polylines.clear());
    });
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(northeast: LatLng(x1!, y1!), southwest: LatLng(x0!, y0!));
  }

  Color _getPriorityColor(double score) {
    if (score >= 0.7) return AppColors.priorityRed;
    if (score >= 0.4) return AppColors.priorityYellow;
    return AppColors.priorityGreen;
  }

  String _getPriorityLabel(double score) {
    if (score >= 0.7) return 'HIGH';
    if (score >= 0.4) return 'MEDIUM';
    return 'LOW';
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
